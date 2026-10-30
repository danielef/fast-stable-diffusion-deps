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

## Updating the CI environment when Colab upgrades

The `ci.yml` runner and Python version must always mirror Colab's environment. Renovate is disabled for both (`enabled: false` in `renovate.json`) because any upgrade requires a manual fix cycle. The current targets are **Ubuntu 24.04** and **Python 3.13**.

### Python version upgrade

Colab occasionally upgrades its Python version (e.g. 3.13 → 3.15). When that happens:

1. **Verify the new version** — open a Colab notebook and run `import sys; print(sys.version)` to confirm what Colab is now running.

2. **Update `ci.yml`** — change the `python-version` in both the `smoke-test` and `release` jobs:
   ```yaml
   python-version: "3.XX"   # ← new version
   ```

3. **Run CI on a branch** — push the change on a PR. The smoke test will reveal any packages that no longer have pre-built wheels for the new Python version (common culprits: C extensions like `pillow-avif-plugin`, and packages that use removed stdlib modules).

4. **Fix broken packages** — for each failure:
   - If the package has a newer version with wheels for the new Python: bump the pin.
   - If no wheel exists: remove from the blob and rely on Colab's system version, or install the required system library with `apt-get`.
   - If a stdlib module was removed (e.g. `audioop` in 3.13): add the backport package (`audioop-lts`).

5. **Update all hard-coded Python version references** — search the repo for the old version string and update every occurrence:
   - The `CI smoke test` line in the `How it works` diagram in `README.md`
   - The `Requirements: Python X.Y` line in the `Local development` section of `README.md`
   - The `# --- Python X.Y compatibility shims ---` heading in `requirements/forge.txt`
   - The Colab version column comments at the top of `requirements/forge.txt`

6. **Merge** — semantic-release publishes a new blob; Renovate opens a PR in `fast-stable-diffusion`; test in Colab before merging.

> Renovate is intentionally disabled for the Python version because a Python upgrade always requires the manual fix cycle above.

### Ubuntu version upgrade

When Colab moves to a new Ubuntu LTS (e.g. 24.04 → 26.04):

1. **Verify the new version** — run `import platform; print(platform.freedesktop_os_release()["VERSION_ID"])` in Colab to confirm the Ubuntu version (e.g. `24.04`).

2. **Update `ci.yml`** — change `runs-on` in both jobs:
   ```yaml
   runs-on: ubuntu-26.04
   ```

3. **Update all hard-coded Ubuntu version references** — search the repo for the old version string and update every occurrence:
   - The introductory line in this section ("The current targets are…")
   - The `CI smoke test` line in the `How it works` diagram in `README.md`
   - The `Requirements: … Ubuntu X.XX` line in the `Local development` section of `README.md`
   - The `Must run on … Ubuntu X.XX` comment in `scripts/build_blob.sh`

4. **Run CI on a branch** — the smoke test will surface any system-library or package incompatibilities introduced by the new OS.

5. **Fix broken packages** — same process as the Python upgrade: bump pins, add `apt-get` deps, or remove packages that Colab now provides.

> Renovate is intentionally disabled for the Ubuntu runner version because an OS upgrade always requires the manual fix cycle above.

## Cutting a release manually

Push a conventional commit to `main` and semantic-release handles the rest:

```bash
git commit -m "fix(deps): update gradio 4.40.0 to 4.41.0"
git push
```

Commit types that trigger a release: `fix` → patch, `feat` → minor, breaking change → major.
