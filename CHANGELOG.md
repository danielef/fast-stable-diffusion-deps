## [1.0.14](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.13...v1.0.14) (2026-11-07)


### Bug Fixes

* **deps:** update dependency blendmodes to v2024.1.1 ([bf1c00b](https://github.com/danielef/fast-stable-diffusion-deps/commit/bf1c00b432f84315eb0371a04dcecad10b648ca0))

## [1.0.13](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.12...v1.0.13) (2026-11-07)


### Bug Fixes

* **deps:** update dependency torchdiffeq to v0.2.5 ([6815fbc](https://github.com/danielef/fast-stable-diffusion-deps/commit/6815fbc6573163a7654fd3ef20d8f72f97a589b0))

## [1.0.12](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.11...v1.0.12) (2026-11-02)


### Bug Fixes

* pin all Colab-floating packages to make blob fully predictable ([58d9898](https://github.com/danielef/fast-stable-diffusion-deps/commit/58d98988614e65c6affcea3a163aa29d08904da4))

## [1.0.11](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.10...v1.0.11) (2026-11-01)


### Bug Fixes

* pin starlette==1.3.1 and fastapi==0.133.0; patch TemplateResponse backward-compat ([ed2c289](https://github.com/danielef/fast-stable-diffusion-deps/commit/ed2c2890c6feb6cd0442e5d7831517d09619d5b1))

## [1.0.10](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.9...v1.0.10) (2026-11-01)


### Bug Fixes

* patch _json_schema_to_python_type() for bool JSON Schema values ([547b3ab](https://github.com/danielef/fast-stable-diffusion-deps/commit/547b3ab202192dd68fe11c5d0f6fd36c14e7ab83))

## [1.0.9](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.8...v1.0.9) (2026-11-01)


### Bug Fixes

* **deps:** patch gradio_client get_type() to handle bool JSON Schema values ([5535fa9](https://github.com/danielef/fast-stable-diffusion-deps/commit/5535fa90fe9f0475e9bda1e169816db120012c1f))

## [1.0.8](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.7...v1.0.8) (2026-11-01)


### Bug Fixes

* **deps:** shim accelerate.utils.memory.clear_device_cache for peft compat ([675e5d0](https://github.com/danielef/fast-stable-diffusion-deps/commit/675e5d03dfc25cbe82b7bd02acd79857eabd2e20))

## [1.0.7](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.6...v1.0.7) (2026-11-01)


### Bug Fixes

* **deps:** remove numpy downgrade from blob ([7e79fac](https://github.com/danielef/fast-stable-diffusion-deps/commit/7e79fac223f8c71962717fc28aaa320064164541))

## [1.0.6](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.5...v1.0.6) (2026-11-01)


### Bug Fixes

* install transitive deps in blob build second pass ([4a4e639](https://github.com/danielef/fast-stable-diffusion-deps/commit/4a4e639f02e210351f1c269127631dbecdb2c1d9))

## [1.0.5](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.4...v1.0.5) (2026-10-30)


### Bug Fixes

* **deps:** pin huggingface-hub to 0.26.0 ([19cdf5c](https://github.com/danielef/fast-stable-diffusion-deps/commit/19cdf5ccc3de99683e481f50d443c6e5cc80575f))

## [1.0.4](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.3...v1.0.4) (2026-10-30)


### Bug Fixes

* **deps:** add pytorch_lightning runtime deps to blob ([baf479c](https://github.com/danielef/fast-stable-diffusion-deps/commit/baf479cf45bac48c0c26ec612bc1309f53dd86bb))

## [1.0.3](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.2...v1.0.3) (2026-10-30)


### Bug Fixes

* **ci:** create dist-packages dir before blob build ([119dd03](https://github.com/danielef/fast-stable-diffusion-deps/commit/119dd0372b60978fcffe7a84e4a4c6022f4b5179))

## [1.0.2](https://github.com/danielef/fast-stable-diffusion-deps/compare/v1.0.1...v1.0.2) (2026-10-30)


### Bug Fixes

* **ci:** capture semantic-release output to gate blob build ([cb56b99](https://github.com/danielef/fast-stable-diffusion-deps/commit/cb56b999151ff0c6388a208a125e860e849f8052))
* **ci:** switch semantic-release preset from conventionalcommits to angular ([7020e64](https://github.com/danielef/fast-stable-diffusion-deps/commit/7020e644df4b03a2127b5278517793507f190ea0))

## <small>1.0.1 (2026-10-30)</small>

* fix(deps): Update dependency semantic-release to v24.2.9 ([f3e9096](https://github.com/danielef/fast-stable-diffusion-deps/commit/f3e9096))
* chore(renovate): use matchDepNames for pytorch_lightning rule ([4379422](https://github.com/danielef/fast-stable-diffusion-deps/commit/4379422))
* docs: lock CI environment versions in Renovate and document upgrade process ([924f151](https://github.com/danielef/fast-stable-diffusion-deps/commit/924f151))

## 1.0.0 (2026-10-30)

* feat: initial commit ([873f4a6](https://github.com/danielef/fast-stable-diffusion-deps/commit/873f4a6))
