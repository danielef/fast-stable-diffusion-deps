# fast-stable-diffusion-deps

Dependency build pipeline for [fast-stable-diffusion](https://github.com/danielef/fast-stable-diffusion).

Produces a versioned tarball (`gcolabdeps_forge.tar.zst`) of all Python packages that [Stable Diffusion Forge](https://github.com/lllyasviel/stable-diffusion-webui-forge) needs on top of Google Colab's base environment. The notebook downloads this blob at runtime instead of running `pip install`, which is significantly faster.

## How it works

```
PyPI publishes a new package version
        │
        ▼
Renovate opens a PR updating requirements/forge.txt
        │
        ▼
CI smoke test: pip install + import check on Python 3.13 / Ubuntu 24.04
        │
        ▼  (maintainer merges)
semantic-release tags a new version (e.g. v1.3.0)
        │
        ▼
CI builds gcolabdeps_forge.tar.zst and uploads it to GitHub Releases
        │
        ▼
Renovate (in fast-stable-diffusion) detects the new release,
opens a PR updating DEPS_URL in the notebook
        │
        ▼  (maintainer opens Colab link from PR comment, tests, merges)
Notebook is live with the new deps
```

## Repository layout

```
requirements/
  forge.txt          Pinned deps for Forge — source of truth
scripts/
  build_blob.sh      Builds the tarball locally or in CI
.github/workflows/
  ci.yml             Smoke test (PRs) + blob build + release (main)
renovate.json        Watches PyPI and npm for dep updates
.releaserc.json      semantic-release configuration
package.json         Pinned Node dev-deps (semantic-release toolchain)
```

## Why some packages are pinned below Colab's versions

Colab ships newer versions of several packages that break Forge's internals. The blob force-installs the correct older versions. The comments in `requirements/forge.txt` explain each downgrade.

The most critical ones:

| Package | Colab ships | Blob pins | Reason |
|---|---|---|---|
| numpy | 2.x | 1.26.x | NumPy 2 changed the C extension ABI |
| gradio | 6.x | 4.x | Forge uses the gradio 4 API |
| transformers | 5.x | 4.46.x | Forge relies on 4.x API |
| protobuf | 6.x | 3.20.x | Forge hardcodes 3.x protobuf API |

## Local development

Requirements: Python 3.13, Ubuntu 24.04 (or a matching Docker container).

```bash
# Install deps into a local venv for testing
python -m venv .venv && source .venv/bin/activate
pip install -r requirements/forge.txt

# Build the blob (writes gcolabdeps_forge.tar.zst)
bash scripts/build_blob.sh
```

## First-time setup

1. Create this repo on GitHub under your account
2. Install the [Renovate GitHub App](https://github.com/apps/renovate) on this repo and on `fast-stable-diffusion`
3. Run the CI workflow manually (Actions → CI → Run workflow) to publish the first release
4. Renovate will open a PR in `fast-stable-diffusion` — that PR gets a Colab test link in its comments

## Cutting a release manually

Push a conventional commit to `main` and semantic-release handles the rest:

```bash
git commit -m "fix(deps): update gradio 4.40.0 to 4.41.0"
git push
```

Commit types that trigger a release: `fix` → patch, `feat` → minor, breaking change → major.
