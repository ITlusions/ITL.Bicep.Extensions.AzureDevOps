# Documentation

Complete documentation for the ITL Bicep Azure DevOps extensibility provider.

## Getting Started

**New to Bicep extensions?** Start here:

1. **[Quick Start Guide](guides/QUICKSTART.md)** — Get running in 5 minutes with CI/CD service containers
2. **[Architecture Overview](ARCHITECTURE.md)** — Understand how the provider works

## Reference Documentation

- **[API Reference](API-REFERENCE.md)** — Complete resource schema and connection types
- **[Deployment Guide](guides/DEPLOYMENT.md)** — All deployment options (service containers, ACI, AKS, App Service, local)
- **[Troubleshooting](guides/TROUBLESHOOTING.md)** — Common issues and solutions

## Contributing

- **[Contributing Guide](CONTRIBUTING.md)** — Development setup, testing, and contribution workflow

## Learning Paths

### Path 1: Quick Start (Recommended)
For most users who just want to deploy service connections via CI/CD:

1. Read [Quick Start](guides/QUICKSTART.md) (~5 min)
2. Skim [API Reference](API-REFERENCE.md) for your connection type
3. Refer to [Troubleshooting](guides/TROUBLESHOOTING.md) if issues arise

### Path 2: Deep Dive
For those implementing production deployments or contributing:

1. [Architecture](ARCHITECTURE.md) — Understand the provider internals
2. [Deployment Guide](guides/DEPLOYMENT.md) — Choose your deployment pattern
3. [API Reference](API-REFERENCE.md) — Master the resource schema
4. [Contributing](CONTRIBUTING.md) — Set up development environment

### Path 3: Operations
For platform teams managing the provider:

1. [Deployment Guide](guides/DEPLOYMENT.md) — Production deployment patterns
2. [Troubleshooting](guides/TROUBLESHOOTING.md) — Debug authentication, API errors, performance
3. [Architecture](ARCHITECTURE.md) — Understand error flows and token acquisition

## Quick Links

| I want to... | Go to... |
|---|---|
| Deploy service connections in my pipeline | [Quick Start](guides/QUICKSTART.md) |
| Understand WorkloadIdentityFederation vs ServicePrincipal | [API Reference § Connection Types](API-REFERENCE.md#connection-types) |
| Fix 401/403 authentication errors | [Troubleshooting § Authentication](guides/TROUBLESHOOTING.md#authentication-issues) |
| Deploy to AKS with workload identity | [Deployment § AKS](guides/DEPLOYMENT.md#3-azure-kubernetes-service-aks) |
| Contribute a new feature | [Contributing](CONTRIBUTING.md) |
| See all error codes | [API Reference § Error Codes](API-REFERENCE.md#error-codes) |

---

**Need help?** Open an [issue](https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/issues) or start a [discussion](https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/discussions).
