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

# Re-run WITH deps to pick up any transitive packages not listed explicitly.
# Second pass respects existing installs (our pinned versions win from first pass).
pip install \
  --target "$DIST_PACKAGES" \
  --no-deps \
  -r requirements/forge.txt

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
