# Handlers/Invoke-CreateOrUpdateResource.ps1
# Mirrors ServiceConnectionCreateOrUpdateHandler.cs and the /createOrUpdate route in app.py.
# Idempotent: GetByName → update if found, create otherwise.

function Invoke-CreateOrUpdateResource {
    $body  = $WebEvent.Data
    $props = $body.properties | ConvertPSObject-ToHashtable

    $org  = $props['organization']
    $proj = $props['project']
    $name = $props['name']

    if (-not ($org -and $proj -and $name)) {
        Write-ErrorResponse -Code 'MissingIdentifiers' `
            -Message "properties must include 'organization', 'project', and 'name'."
        return
    }
    if (-not $props['type']) {
        Write-ErrorResponse -Code 'MissingProperty' `
            -Message "Property 'type' is required." `
            -Target '/properties/type'
        return
    }

    try {
        $existing = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
        if ($existing) {
            $result = Update-AdoConnection -Organization $org -Project $proj -EndpointId $existing.id -Props $props
        } else {
            $result = New-AdoConnection -Organization $org -Project $proj -Props $props
        }
    } catch {
        Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
        return
    }

    $identifiers = @{ organization = $org; project = $proj; name = $name }
    $resource    = ConvertTo-ResourceBody -Type $body.type -ApiVersion $body.apiVersion `
                       -Identifiers $identifiers -AdoEndpoint $result
    Write-OkResponse -Body $resource
}
