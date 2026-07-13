# Changelog

All notable changes to this WinPE deployment lab are documented in this file.

This project uses Semantic Versioning for the project itself. The project version is separate from the synced template guidance version shown in the README badge.

## Unreleased

### Changed

- Aligned the Windows CI workflow, runtime policy, and version-policy validation around the repo's tracked ci.yml contract, actions/checkout@v7, and Pester 6.0.0.

## 0.1.1 - 2026-07-13

### Changed

- Aligned the root operator scripts, public workflow functions, and architecture docs to the current PowerShell 7 (`pwsh`) operator baseline.
- Clarified the maintained wrapper-plus-implementation script model, including the root-scoped role of `Write-WorkspaceLog.ps1`.
- Added `ShouldProcess` support to the state-changing workflow functions and cleanup helper to better match current repository standards.
- Corrected project script and unit-test analyzer issues so the project script surface passes the current repo validation contract.

## 0.1.0 - 2026-06-22

### Added

- Added root-level `AGENTS.md` from the synced template guidance.
- Added AI governance documentation and the ADR scaffold README from `pwsh-dev-template` guidance version `0.11.0`.

### Changed

- Synced AI guidance and guardrail documentation from `pwsh-dev-template` guidance version `0.11.0`.
- Refreshed `.github/copilot-instructions.md` with the current AI coding instructions.
- Updated the README template-version badge to `template-0.11.0`.
