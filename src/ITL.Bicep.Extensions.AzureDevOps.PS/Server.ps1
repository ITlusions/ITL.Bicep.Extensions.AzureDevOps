#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ITL Bicep Extension — Azure DevOps Service Connections (PowerShell/Pode)

.DESCRIPTION
    Entry point. Imports the ITL.Bicep.Extensions.AzureDevOps module via Pode so all
    exported functions are available in every Pode runspace/thread.
    Mirrors Program.cs (.NET) and __main__.py (Python).

.REQUIREMENTS
    PowerShell 7+
    Install-Module -Name Pode -Force

.AUTHENTICATION
    Uses Azure Workload Identity / Managed Identity — no PAT required.
    Credential resolution order (see Get-AdoAuthHeader in AdoServiceConnectionClient.ps1):
      1. AZURE_AD_TOKEN env var     — explicit override / local testing
      2. Azure IMDS endpoint        — Managed Identity or Workload Identity (AKS)
         Set AZURE_CLIENT_ID for user-assigned managed identity.
      3. Az.Accounts module         — Connect-AzAccount for local development

    The identity must have "Service Connections: Read & manage" in the ADO organisation.

.USAGE
    pwsh ./src/ITL.Bicep.Extensions.AzureDevOps.PS/Server.ps1
#>

$ErrorActionPreference = 'Stop'

Import-Module Pode

# Resolve absolute path before entering the Pode server scope
$ModulePath = Join-Path $PSScriptRoot 'ITL.Bicep.Extensions.AzureDevOps.psd1'

# ---------------------------------------------------------------------------
# Pode server
# ---------------------------------------------------------------------------
Start-PodeServer -Threads 4 {

    # Import-PodeModule makes all exported functions available in every runspace.
    Import-PodeModule -Path $using:ModulePath

    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Post -Path '/:version/resource/preview' `
        -ScriptBlock { Invoke-PreviewResource }

    Add-PodeRoute -Method Post -Path '/:version/resource/createOrUpdate' `
        -ScriptBlock { Invoke-CreateOrUpdateResource }

    Add-PodeRoute -Method Post -Path '/:version/resource/get' `
        -ScriptBlock { Invoke-GetResource }

    Add-PodeRoute -Method Post -Path '/:version/resource/delete' `
        -ScriptBlock { Invoke-DeleteResource }

    Add-PodeRoute -Method Post -Path '/:version/longRunningOperation/get' -ScriptBlock {
        Write-ErrorResponse -Code 'UnknownOperation' `
            -Message 'This extension does not use long-running operations.' `
            -Status 404
    }
}
