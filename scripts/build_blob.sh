#!/usr/bin/env bash
# Builds gcolabdeps_forge.tar.zst
# Must run on Python 3.13 / Ubuntu 24.04 to match Colab's current environment.
# Output: gcolabdeps_forge.tar.zst (extracted to /usr/local/lib/pythonX.Y/dist-packages/)
set -euo pipefail

PYTHON="${PYTHON:-python3}"
PY_VER=$($PYTHON -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")
DIST_PACKAGES="/usr/local/lib/${PY_VER}/dist-packages"
BLOB_NAME="gcolabdeps_forge.tar.zst"

echo "Building blob for $PY_VER → $BLOB_NAME"

# Install into the same dist-packages path Colab uses.
# --ignore-installed forces our pinned versions even if Colab has newer ones.
pip install \
  --target "$DIST_PACKAGES" \
  --ignore-installed \
  --no-deps \
  -r requirements/forge.txt

# Second pass: resolve and install transitive dependencies, but exclude
# packages Colab provides at runtime.
#
# pip sets ignore_installed=True before constructing the resolver whenever
# --target is used, so metadata already present in the target is never
# consulted.  Any post-install cleanup also fails to address disk exhaustion
# during the install itself: pytorch_lightning and open-clip-torch pull in
# torch, torchvision, torchaudio, and a full set of nvidia-* CUDA libraries
# that can be 10+ GB on the runner.
#
# Safe approach: use --dry-run --report to resolve the full dep tree without
# downloading anything, strip Colab-provided packages from the result, then
# install only the remainder with --no-deps.

pip install \
  --dry-run \
  --report /tmp/pip_deps_report.json \
  --target "$DIST_PACKAGES" \
  -r requirements/forge.txt

$PYTHON - <<'PYEOF'
import json, re

with open('/tmp/pip_deps_report.json') as f:
    report = json.load(f)

# Packages provided by Colab at runtime — must not be in the blob.
# Normalise to lowercase with underscores for comparison.
#
# torch family: CUDA-coupled; Colab ships GPU builds; CPU PyPI builds would
#   overwrite them and break GPU inference.
# triton: version-coupled to torch; mismatched triton causes inductor errors.
# nvidia-*: CUDA libraries pulled in as torch sub-deps; huge and GPU-specific.
# numpy: Colab 2.x is correct; the 1.26.4 downgrade breaks Colab's JAX/TF
#   which call numpy.dtypes.StringDType (NumPy 2.x only); none of our blob
#   packages use the NumPy C ABI directly.
# tqdm/requests/psutil/lark/httpx/pydantic/scikit-image: already present in
#   Colab at compatible versions (see requirements/forge.txt header comment);
#   bundling them wastes space and risks version conflicts.
COLAB_PROVIDED_NAMES = frozenset({
    'torch', 'torchvision', 'torchaudio', 'triton',
    'numpy',
    'tqdm', 'requests', 'psutil', 'lark',
    'httpx', 'pydantic', 'pydantic_core',
    'scikit_image',
})
NVIDIA_PREFIX = re.compile(r'^nvidia[_-]', re.IGNORECASE)

def is_colab_provided(name):
    norm = name.lower().replace('-', '_')
    return norm in COLAB_PROVIDED_NAMES or bool(NVIDIA_PREFIX.match(name))

lines = []
for pkg in report.get('install', []):
    name = pkg['metadata']['name']
    if not is_colab_provided(name):
        lines.append(f"{name}=={pkg['metadata']['version']}")

with open('/tmp/transitive_deps.txt', 'w') as f:
    f.write('\n'.join(lines) + '\n')

excluded = len(report['install']) - len(lines)
print(f'Transitive deps: installing {len(lines)}, excluded {excluded} Colab-provided')
PYEOF

pip install \
  --target "$DIST_PACKAGES" \
  --no-deps \
  -r /tmp/transitive_deps.txt

# Write sitecustomize.py into the blob.
# Python runs this file at startup whenever /content/forge_deps is on
# PYTHONPATH (which cell 5 sets for the Forge subprocess).  It runs after
# site-packages are on sys.path, so Colab's numpy is already importable.
#
# It does three things:
#   1. Disables TF/JAX backends in Transformers via USE_TF=0 / USE_FLAX=0.
#      Transformers 4.46.1 checks these env vars at import time before calling
#      find_spec(); setting them to "0" makes is_tf_available() /
#      is_flax_available() return False immediately, so image_transforms.py
#      never tries to import tensorflow or jax.  Using stubs instead would
#      leave the real TF/JAX distributions in place but half-registered: any
#      code path beyond the availability check (e.g. tf.Tensor, jax.numpy.ndarray)
#      would raise AttributeError with no useful error message.
#   2. Restores the NumPy 1.x aliases (np.Inf, np.NaN, np.bool, …) that
#      NumPy 2.0 removed.  pytorch_lightning 1.9.4's ModelCheckpoint uses
#      np.Inf; without this patch any Trainer instantiation raises AttributeError.
#   3. Back-fills accelerate.utils.memory.clear_device_cache if absent.
#      Colab's peft (>= 0.10) imports this function, which was added to
#      accelerate after 0.31.0 (the version the blob pins for Forge compat).
#      Without the shim, peft fails to import entirely, breaking diffusers LoRA.
cat > "$DIST_PACKAGES/sitecustomize.py" << 'SCEOF'
import os

# ── 1. Disable TF / JAX backends in Transformers ──────────────────
# Transformers 4.46.1 reads USE_TF and USE_FLAX at module-import time.
# Setting them to "0" before any import makes is_tf_available() and
# is_flax_available() return False without calling find_spec(), so the
# eager import of image_transforms.py never loads Colab's real TF/JAX.
# setdefault preserves an explicit override if the user sets them.
os.environ.setdefault('USE_TF', '0')
os.environ.setdefault('USE_FLAX', '0')

# ── 2. NumPy 1.x → 2.x compatibility aliases ─────────────────────
try:
    import numpy as _np
    _compat = {
        'Inf': _np.inf,      'Infinity': _np.inf,
        'NaN': _np.nan,      'NAN': _np.nan,
        'PINF': _np.inf,     'NINF': -_np.inf,
        'PZERO': 0.0,        'NZERO': -0.0,
        'bool': bool,        'int': int,
        'float': float,      'complex': complex,
        'object': object,    'str': str,
    }
    for _k, _v in _compat.items():
        if not hasattr(_np, _k):
            setattr(_np, _k, _v)
except ImportError:
    pass

# ── 3. accelerate.utils.memory.clear_device_cache shim ────────────
# Added to accelerate after 0.31.0; Colab's peft imports it at startup.
try:
    import accelerate.utils.memory as _aum
    if not hasattr(_aum, 'clear_device_cache'):
        import gc as _gc
        def _clear_device_cache(garbage_collection=False):
            if garbage_collection:
                _gc.collect()
            try:
                import torch as _torch
                if _torch.cuda.is_available():
                    _torch.cuda.empty_cache()
            except ImportError:
                pass
        _aum.clear_device_cache = _clear_device_cache
        del _clear_device_cache
except (ImportError, AttributeError):
    pass
SCEOF

# Smoke-test: verify critical imports and that TF/JAX are correctly disabled
PYTHONPATH="$DIST_PACKAGES" $PYTHON -c "
import os
os.environ.setdefault('USE_TF', '0')
os.environ.setdefault('USE_FLAX', '0')
import gradio, transformers, diffusers, accelerate
import numpy, einops, omegaconf, safetensors
import kornia, torchdiffeq, torchsde, spandrel
import pytorch_lightning
from transformers.utils import is_tf_available, is_flax_available
assert not is_tf_available(),  'TF should be disabled via USE_TF=0'
assert not is_flax_available(), 'Flax/JAX should be disabled via USE_FLAX=0'
print('✓ All imports OK')
print(f'  gradio              {gradio.__version__}')
print(f'  transformers        {transformers.__version__}')
print(f'  numpy               {numpy.__version__}')
print(f'  diffusers           {diffusers.__version__}')
print(f'  pytorch_lightning   {pytorch_lightning.__version__}')
print('✓ TF/JAX correctly disabled in Transformers')
"

# Create the tarball (relative paths inside, extracted with -C /usr/local/lib/$PY_VER/dist-packages)
tar \
  --zstd \
  --create \
  --file "$BLOB_NAME" \
  --directory "$DIST_PACKAGES" \
  .

echo "✓ Built $BLOB_NAME ($(du -sh "$BLOB_NAME" | cut -f1))"
