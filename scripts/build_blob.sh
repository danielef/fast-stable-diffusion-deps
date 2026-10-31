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
# tqdm/requests/psutil/lark/httpx/pydantic/scikit-image: already present in
#   Colab at compatible versions (see requirements/forge.txt header comment);
#   bundling them wastes space and risks version conflicts.
COLAB_PROVIDED_NAMES = frozenset({
    'torch', 'torchvision', 'torchaudio', 'triton',
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

# Smoke-test: verify critical imports
$PYTHON -c "
import gradio, transformers, diffusers, accelerate
import numpy, einops, omegaconf, safetensors
import kornia, torchdiffeq, torchsde, spandrel
import pytorch_lightning
print('✓ All imports OK')
print(f'  gradio              {gradio.__version__}')
print(f'  transformers        {transformers.__version__}')
print(f'  numpy               {numpy.__version__}')
print(f'  diffusers           {diffusers.__version__}')
print(f'  pytorch_lightning   {pytorch_lightning.__version__}')
"

# Create the tarball (relative paths inside, extracted with -C /usr/local/lib/$PY_VER/dist-packages)
tar \
  --zstd \
  --create \
  --file "$BLOB_NAME" \
  --directory "$DIST_PACKAGES" \
  .

echo "✓ Built $BLOB_NAME ($(du -sh "$BLOB_NAME" | cut -f1))"
