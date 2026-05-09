# Handlers/Invoke-PreviewResource.ps1
# Mirrors ServiceConnectionPreviewHandler.cs and the /preview route in app.py.

function Invoke-PreviewResource {
    $body     = $WebEvent.Data
    $props    = $body.properties
    $connType = $props.type ?? ''

    $preview = @{
        type        = $body.type
        apiVersion  = $body.apiVersion
        identifiers = @{ name = $props.name }
        properties  = ($props | ConvertPSObject-ToHashtable) + @{
            id              = '(assigned by Azure DevOps on create)'
            operationStatus = 'Ready'
            url             = $props.url ?? $Script:DefaultUrls[$connType.ToLower()] ?? 'https://dev.azure.com/'
        }
        metadata = @{
            readOnly   = @('/properties/id')
            calculated = @('/properties/id', '/properties/operationStatus')
        }
    }
    Write-OkResponse -Body $preview
}
