## Context

The repository is empty except for its newly initialized OpenSpec workflow.
Future work spans four runtimes and includes latency-sensitive native code, so
the initial structure must make ownership and validation boundaries explicit.

## Goals / Non-Goals

**Goals:**

- Keep the Flutter UI, Rust flight core, native adapters, Go backend, and data
  tooling independently testable.
- Provide a small runnable or testable skeleton at each implemented boundary.
- Make local and CI commands equivalent and secret-free.
- Produce a secure ARM64 backend container baseline.

**Non-Goals:**

- Choose final sensor, map, or network dependencies.
- Generate FFI bindings before the native-pipeline spike defines the contract.
- Add empty abstractions for planned features.

## Decisions

### Use a single monorepo

The app, native bridge, shared core, backend, contracts, and map pipeline live in
one repository. This keeps OpenSpec changes and cross-boundary contracts atomic.
Separate repositories were rejected because they add release coordination before
the interfaces are stable.

### Generate platform projects with their native ecosystem tools

Flutter creates the app and plugin projects, Cargo creates the Rust crate, and Go
owns its module. Development machines may use installed SDKs; CI and bootstrap
may use pinned containers where host SDKs are absent. Handwritten platform
scaffolding was rejected because generated build metadata is easy to omit.

### Keep the first Rust boundary pure

The initial Rust crate contains domain-neutral version and health functions only.
FFI generation is deferred until the native flight-pipeline change specifies
ownership, threading, and error semantics. Premature bridge dependencies would
increase build time and obscure the performance spike.

### Use a standard-library Go health service

The backend skeleton uses Go's standard HTTP library and explicit timeouts. A web
framework is unnecessary before API contracts exist and would add supply-chain
surface without product behavior.

### Use a hardened multi-stage backend image

The builder compiles a static Linux binary. The runtime uses a minimal non-root
image, read-only-compatible paths, explicit health checking, and no shell
dependency. A full distribution image was rejected due to its larger attack
surface on the Raspberry Pi.

### Split CI by runtime

OpenSpec, Rust, Flutter, Go, and container checks are separate jobs. This keeps
failures attributable and allows later path filtering. CI uses public synthetic
inputs and never requires production secrets.

## Risks / Trade-offs

- **Containerized SDK commands can differ from developer hosts** -> pin tool
  versions in CI and document supported local versions.
- **Multi-runtime CI is initially slower** -> keep jobs parallel and dependencies
  minimal; introduce caching only after measured need.
- **Generated Flutter files are verbose** -> retain them because Android/iOS
  projects must be reproducible and store-ready.
- **Minimal backend image complicates diagnostics** -> expose structured logs and
  health endpoints rather than adding runtime shells.

## Migration Plan

This is a greenfield bootstrap. If a generator fails, remove only that generator's
new target directory and rerun it; OpenSpec artifacts and other modules remain
independent. No deployed data or API migration exists.
