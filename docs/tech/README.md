# BrandyFly Technical Documentation

Welcome to the technical documentation for BrandyFly. This section is intended for developers, contributors, and those interested in the internal workings of the project.

## Overview

BrandyFly is structured into several core components, separating latency-sensitive flight processing from presentation and online services. We utilize a combination of Rust for deterministic logic, Flutter for cross-platform UI, native adapters (Kotlin/Swift) for platform integration, and Go for backend synchronization.

## Architecture

To understand how the different pieces of BrandyFly communicate and the overall system design, please read the [Architecture Guide](./architecture.md). It details the flow from sensor acquisition to the MapLibre UI and outlines our module separation strategy.

## Development

If you are looking to build BrandyFly locally, run tests, or understand our validation processes, consult the [Development Guide](./development.md). It covers prerequisites, build commands, and our OpenSpec-based workflow for proposing and making changes.

## Contributing

Before submitting changes, ensure you follow our [OpenSpec workflow](../../README.md#openspec-workflow). We use a specification-driven approach to manage changes, requiring clear proposals and verified implementations via GitHub issues.
