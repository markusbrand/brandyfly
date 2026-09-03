# Contributing

Contributions are welcome through GitHub pull requests.

## Workflow

1. Discuss material product or architecture changes in an issue.
2. Create or update an OpenSpec change for non-trivial work (`openspec/changes/<change-name>/`).
   Durable capability specs stay under `openspec/specs/`.
3. Keep changes focused and add targeted tests.
4. Run the validation commands in `docs/development.md`.
5. Use Conventional Commit messages (`feat:`, `fix:`, `chore:`, etc.) with appropriate component scopes (e.g., `feat(mobile): ...`, `fix(flight_core): ...`). Releases and changelogs are automated via [Release Please](https://github.com/googleapis/release-please).

Do not commit credentials, signing material, private flight logs, proprietary
protocol documentation, or datasets that cannot be redistributed. The same rule
applies to OpenSpec issue content: never publish secrets or private flight data
to an issue.

Hardware support must not be advertised until the corresponding OpenSpec
release gate has passed on a real device.
