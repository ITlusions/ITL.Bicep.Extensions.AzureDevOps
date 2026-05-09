# ITL.Bicep.Extensions.AzureDevOps.psd1
# Module manifest.
@{
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'ITLusions'
    Description       = 'ITL Bicep Extensibility Provider — Azure DevOps Service Connections'
    PowerShellVersion = '7.2'
    RootModule        = 'ITL.Bicep.Extensions.AzureDevOps.psm1'

    # All public + internal helpers must be exported so Pode runspaces can call them.
    FunctionsToExport = @(
        # Route handlers (called directly from Pode route ScriptBlocks)
        'Invoke-PreviewResource'
        'Invoke-CreateOrUpdateResource'
        'Invoke-GetResource'
        'Invoke-DeleteResource'

        # ADO client (called by handlers inside Pode runspaces)
        'Get-AdoConnectionByName'
        'New-AdoConnection'
        'Update-AdoConnection'
        'Remove-AdoConnection'
        'Build-AdoPayload'

        # Model helpers (called by handlers inside Pode runspaces)
        'ConvertTo-ResourceBody'
        'ConvertPSObject-ToHashtable'
        'Remove-SecretParams'
        'Write-ErrorResponse'
        'Write-OkResponse'
        'Write-NoContentResponse'
        'Write-NotFoundResponse'
        'New-ResponseHeaders'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags        = @('Bicep', 'AzureDevOps', 'Extension', 'ITL')
            ProjectUri  = 'https://github.com/ITlusions/ITL.Bicep.Extensions.AzureDevOps'
        }
    }
}
