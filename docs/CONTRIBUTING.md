# Contributing Guide

Thank you for your interest in contributing to the ITL Bicep Azure DevOps extensibility provider!

## Development Setup

### Prerequisites

- **Git**
- **Azure DevOps organization** (free tier works)
- **Azure CLI** (`az` with Bicep extension)
- **Docker** (for containerized testing)
- **Runtime-specific tools**:
  - **.NET**: .NET 8 SDK
  - **Python**: Python 3.12+, pip, virtualenv
  - **PowerShell**: PowerShell 7+

### Clone Repository

```bash
git clone https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps.git
cd ITL.Bicep.Extensions.AzureDevOps
```

### Choose Runtime Implementation

Pick one (or more) to work with:

---

#### .NET Implementation

**Directory**: `src/ITL.Bicep.Extensions.AzureDevOps/`

**Setup**:

```bash
cd src/ITL.Bicep.Extensions.AzureDevOps
dotnet restore
dotnet build
```

**Run**:

```bash
az login  # Authenticate
dotnet run
# Provider starts on http://localhost:8080
```

**Test**:

```bash
dotnet test
```

**Code style**:

- C# 12 with nullable reference types enabled
- Follow [Microsoft C# Coding Conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Use `var` for local variables when type is obvious
- Async methods: suffix with `Async`

---

#### Python Implementation

**Directory**: `src/itl_bicep_ext_azuredevops/`

**Setup**:

```bash
cd src/itl_bicep_ext_azuredevops
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -e ".[dev]"
```

**Run**:

```bash
az login
python -m itl_bicep_ext_azuredevops
# Provider starts on http://localhost:8080
```

**Test**:

```bash
pytest tests/ -v
pytest tests/ --cov=itl_bicep_ext_azuredevops --cov-report=term
```

**Code style**:

- Python 3.12+
- Follow [PEP 8](https://peps.python.org/pep-0008/)
- Type hints required (checked by `mypy`)
- Format with `ruff format`
- Lint with `ruff check`

**Pre-commit hook** (recommended):

```bash
pip install pre-commit
pre-commit install
```

---

#### PowerShell Implementation

**Directory**: `src/ITL.Bicep.Extensions.AzureDevOps.PS/`

**Setup**:

```powershell
cd src/ITL.Bicep.Extensions.AzureDevOps.PS
# Install dependencies
Install-Module -Name Pode -Scope CurrentUser
Install-Module -Name Az.Accounts -Scope CurrentUser
```

**Run**:

```powershell
Connect-AzAccount  # Authenticate
pwsh ./Server.ps1
# Provider starts on http://localhost:8080
```

**Test**:

```powershell
Invoke-Pester tests/
```

**Code style**:

- PowerShell 7+
- Follow [PowerShell Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)
- Use approved verbs (`Get-`, `Set-`, `New-`, etc.)
- CamelCase for functions, lowercase for parameters

---

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

**Branch naming**:

- `feature/` — new features
- `fix/` — bug fixes
- `docs/` — documentation changes
- `refactor/` — code refactoring
- `test/` — test improvements

### 2. Make Changes

Follow the code style for your runtime (see above).

### 3. Test Changes

#### Unit Tests

Run runtime-specific tests (see runtime sections above).

#### Integration Tests

Test against a real Azure DevOps organization:

```bash
# 1. Start provider
dotnet run  # or Python/PowerShell equivalent

# 2. Create test Bicep template
cat > test.bicep <<'EOF'
extension ado

resource testConn 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'your-test-org'
    project: 'test-project'
    name: 'test-conn'
  }
  properties: {
    name: 'test-conn'
    type: 'GitHub'
    url: 'https://github.com'
    authorization: {
      scheme: 'Token'
      parameters: {
        accessToken: 'test-token'
      }
    }
    data: {}
  }
}
EOF

# 3. Create bicepconfig.json
cat > bicepconfig.json <<'EOF'
{
  "experimentalFeaturesEnabled": { "extensibility": true },
  "extensions": { "ado": "http://localhost:8080" }
}
EOF

# 4. Test deployment (dry-run)
az deployment group what-if \
  --resource-group test-rg \
  --template-file test.bicep

# 5. Clean up test connection in ADO UI after testing
```

### 4. Commit Changes

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
git add .
git commit -m "feat: add support for GitLab service connections"
```

**Commit message format**:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:

- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation changes
- `refactor` — code refactoring (no functional change)
- `test` — test improvements
- `chore` — build/tooling changes

**Examples**:

```bash
git commit -m "feat(dotnet): add WorkloadIdentityFederation scheme"
git commit -m "fix(python): handle ADO API 429 rate limit"
git commit -m "docs: add AKS deployment example"
```

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Open a pull request at: https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/pulls

**PR title**: Same format as commit messages

**PR description**: Include:

- **What**: Brief description of changes
- **Why**: Reason for the change
- **Testing**: How you tested the changes
- **Breaking changes**: If any (use `BREAKING CHANGE:` in commit footer)

---

## Code Review Process

1. **Automated checks**:
   - All tests pass
   - Code style checks pass (ruff, dotnet format, PSScriptAnalyzer)
   - No merge conflicts

2. **Manual review**:
   - Code quality and maintainability
   - Test coverage (aim for >80%)
   - Documentation updates (if needed)

3. **Approval**: At least one maintainer approval required

4. **Merge**: Squash and merge (maintainers will handle)

---

## Testing Guidelines

### Unit Tests

**Coverage expectations**:

- New features: >80% line coverage
- Bug fixes: Add regression test

**.NET**:

```csharp
[Fact]
public async Task PreviewAsync_ValidRequest_ReturnsSuccess()
{
    // Arrange
    var handler = new ServiceConnectionHandler(mockAdoClient);
    var request = new PreviewRequest { ... };

    // Act
    var result = await handler.PreviewAsync(request);

    // Assert
    Assert.Equal("valid", result.Status);
}
```

**Python**:

```python
@pytest.mark.asyncio
async def test_preview_valid_request(mock_ado_client):
    """Test preview with valid request returns success."""
    handler = ServiceConnectionHandler(mock_ado_client)
    request = PreviewRequest(...)
    
    result = await handler.preview(request)
    
    assert result.status == "valid"
```

**PowerShell**:

```powershell
Describe "ServiceConnection" {
    It "Preview returns valid for correct request" {
        # Arrange
        $request = @{ type = "ServiceConnection@2024-01-01"; ... }
        
        # Act
        $result = Invoke-Preview -Request $request
        
        # Assert
        $result.status | Should -Be "valid"
    }
}
```

### Integration Tests

Store in `tests/integration/`:

```bash
tests/integration/
├── test_azurerm_wif.bicep       # AzureRM WorkloadIdentityFederation
├── test_azurerm_sp.bicep        # AzureRM ServicePrincipal
├── test_github.bicep            # GitHub Token
└── test_multi_connection.bicep  # Multiple connections
```

Run manually (require real ADO org):

```bash
./tests/integration/run.sh  # or run.ps1
```

---

## Documentation Standards

### Code Comments

**DO**:

- Document complex logic
- Explain "why", not "what"
- Use XML docs (.NET), docstrings (Python), comment-based help (PowerShell)

**.NET**:

```csharp
/// <summary>
/// Creates or updates a service connection using ADO REST API.
/// Implements idempotent upsert: creates if not exists, updates otherwise.
/// </summary>
/// <param name="request">Service connection configuration</param>
/// <returns>Created/updated connection properties</returns>
public async Task<SaveResponse> SaveAsync(SaveRequest request) { ... }
```

**Python**:

```python
async def save(self, request: SaveRequest) -> SaveResponse:
    """Create or update a service connection.
    
    Implements idempotent upsert: creates if connection doesn't exist,
    updates existing connection otherwise.
    
    Args:
        request: Service connection configuration
        
    Returns:
        Created/updated connection properties
        
    Raises:
        AzureDevOpsApiError: If ADO API call fails
    """
```

**PowerShell**:

```powershell
<#
.SYNOPSIS
    Creates or updates a service connection.

.DESCRIPTION
    Implements idempotent upsert: creates if connection doesn't exist,
    updates existing connection otherwise.

.PARAMETER Request
    Service connection configuration (hashtable)

.OUTPUTS
    SaveResponse hashtable with connection properties
#>
function Invoke-Save {
    param([hashtable]$Request)
    ...
}
```

### README / Markdown

- Update [README.md](../README.md) for new features
- Update relevant docs in `docs/`:
  - [ARCHITECTURE.md](ARCHITECTURE.md) — architecture changes
  - [API-REFERENCE.md](API-REFERENCE.md) — new resource types/properties
  - [DEPLOYMENT.md](DEPLOYMENT.md) — new deployment options
  - [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — new issues/solutions
- Use clear headings, code blocks, and examples

---

## Release Process

**Maintainers only**

1. **Version bump**: Update version in:
   - `.csproj` (.NET)
   - `pyproject.toml` (Python)
   - `psd1` manifest (PowerShell)

2. **Changelog**: Update `CHANGELOG.md` (follow [Keep a Changelog](https://keepachangelog.com/))

3. **Tag release**:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

4. **Build images**:
   ```bash
   docker build -f Dockerfile -t ghcr.io/itlusions/itl-ado-provider:1.1.0 .
   docker push ghcr.io/itlusions/itl-ado-provider:1.1.0
   ```

5. **GitHub Release**: Create release at https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/releases

---

## Architecture Decision Records (ADRs)

For significant architectural decisions, create an ADR in `docs/adr/`:

```
docs/adr/
├── 0001-use-fastapi-for-python.md
├── 0002-support-workload-identity-federation.md
└── template.md
```

**Template**:

```markdown
# ADR-XXXX: Title

## Status

[Proposed | Accepted | Deprecated | Superseded]

## Context

[What is the issue we're addressing?]

## Decision

[What is the change that we're proposing and/or doing?]

## Consequences

[What becomes easier or more difficult?]
```

---

## Getting Help

- **Questions**: Open a [GitHub Discussion](https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/discussions)
- **Bugs**: Open an [Issue](https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps/issues)
- **Chat**: Join Discord (link in README)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

Be respectful, collaborative, and inclusive.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](../LICENSE).

---

**Thank you for contributing!**
