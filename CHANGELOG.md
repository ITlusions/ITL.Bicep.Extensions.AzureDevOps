# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation suite (ARCHITECTURE, API-REFERENCE, DEPLOYMENT, TROUBLESHOOTING, CONTRIBUTING)

## [1.0.0] - 2026-05-09

### Added
- Initial release of Bicep extensibility provider for Azure DevOps
- .NET 8 implementation (ASP.NET Core)
- Python 3.12 implementation (FastAPI)
- PowerShell 7 implementation (Pode)
- Support for `ServiceConnection@2024-01-01` resource type
- **Connection types**:
  - AzureRM (WorkloadIdentityFederation and ServicePrincipal schemes)
  - GitHub (Token scheme)
  - Docker Registry (UsernamePassword scheme)
- Authentication via Azure DefaultAzureCredential (managed identity, Azure CLI, etc.)
- Full CRUD operations: preview, save, get, delete
- Idempotent resource management (create if not exists, update otherwise)
- Error handling with standard HTTP status codes
- Health check endpoint (`/health`)
- Prometheus metrics endpoint (`/metrics`, .NET only)
- Structured JSON logging to stdout
- Docker container support for all runtimes
- Deployment examples for:
  - Local Docker
  - Azure Container Instances (ACI)
  - Azure Kubernetes Service (AKS)
  - Azure App Service
  - CI/CD service containers (Azure Pipelines, GitHub Actions)
- Example Bicep templates in `examples/`
- Comprehensive README with quickstart guide

### Security
- No secrets stored in provider (uses Azure managed identities)
- Secure parameter handling via Bicep `@secure()` decorator
- Token acquisition via Azure AD with minimal scope (Azure DevOps API)

---

## Release Strategy

### Version Numbering

- **Major (X.0.0)**: Breaking changes to resource schema or API
- **Minor (1.X.0)**: New features, new connection types, backwards-compatible
- **Patch (1.0.X)**: Bug fixes, documentation updates, no feature changes

### Breaking Changes

When introducing breaking changes, we will:

1. Announce deprecation in a minor release (e.g., 1.5.0)
2. Maintain backwards compatibility for at least one minor release cycle
3. Release breaking change in next major version (e.g., 2.0.0)
4. Document migration path in `MIGRATION.md`

### Supported Versions

| Version | Supported          | Notes                          |
|---------|--------------------|--------------------------------|
| 1.x     | Yes                | Current stable release         |
| 0.x     | No                 | Pre-release (not published)    |

---

## Upgrade Guide

### From Pre-Release to 1.0.0

This is the first stable release. No migration needed.

---

[Unreleased]: https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/releases/tag/v1.0.0
