# Changelog

## [0.2.0](https://github.com/markusbrand/brandyfly/compare/brandyfly-v0.1.0...brandyfly-v0.2.0) (2026-08-26)


### Features

* **apps/mobile:** add Linux desktop platform target ([#9](https://github.com/markusbrand/brandyfly/issues/9)) ([8f0b4c6](https://github.com/markusbrand/brandyfly/commit/8f0b4c65bf663d66a0766cfc880df71a1f850e08))
* implement MVP UI architecture and user-configurable screens ([#31](https://github.com/markusbrand/brandyfly/issues/31)) ([03777c9](https://github.com/markusbrand/brandyfly/commit/03777c9303e1e6ebe50d38369705aec932586cd7))
* integrate worktree changes for OpenSpec and UI enhancements ([#27](https://github.com/markusbrand/brandyfly/issues/27)) ([3b36372](https://github.com/markusbrand/brandyfly/commit/3b3637233d59f6e139e015fd39869bced129217a))
* map engine benchmark suite, telemetry abstraction, stage-0 specs, and native flight pipeline ([#94](https://github.com/markusbrand/brandyfly/issues/94)) ([efe093c](https://github.com/markusbrand/brandyfly/commit/efe093cb027b7ede2e3484904ef0daa41098bd63))
* **ui:** add tooltips to extended floating action buttons for accessibility ([#73](https://github.com/markusbrand/brandyfly/issues/73)) ([5399361](https://github.com/markusbrand/brandyfly/commit/539936197c5334ac1d27ce76e3eb1c56eb36863b))
* **ux:** Add tooltips to IconButtons for better accessibility ([#49](https://github.com/markusbrand/brandyfly/issues/49)) ([4d5d89b](https://github.com/markusbrand/brandyfly/commit/4d5d89bf7c01f0781a8752f0c570f84cf6934d00))


### Bug Fixes

* add error handling for generic exceptions and missing platform channels ([#29](https://github.com/markusbrand/brandyfly/issues/29)) ([73ae97b](https://github.com/markusbrand/brandyfly/commit/73ae97b0cbcbc2f270e7ebeb6793f9d5a27b8d21))
* **mobile:** prevent layout overflows in flight dashboard widgets ([#54](https://github.com/markusbrand/brandyfly/issues/54)) ([9cd9f3c](https://github.com/markusbrand/brandyfly/commit/9cd9f3c70565b7fe19583b18437e2102f0efa5f6))


### Performance Improvements

* Cache CustomPainter Paint objects to reduce GC overhead ([#74](https://github.com/markusbrand/brandyfly/issues/74)) ([02e9de1](https://github.com/markusbrand/brandyfly/commit/02e9de198b3fc631bf990640e1901397b9a35f65))
* **flutter:** hoist Paint objects out of CustomPainter paint methods ([#67](https://github.com/markusbrand/brandyfly/issues/67)) ([c424939](https://github.com/markusbrand/brandyfly/commit/c4249398caca3db956e6dfdd1815935ad6e6aaac))
