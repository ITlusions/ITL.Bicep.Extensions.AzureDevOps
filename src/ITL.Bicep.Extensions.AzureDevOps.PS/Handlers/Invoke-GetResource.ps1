# Handlers/Invoke-GetResource.ps1
# Mirrors ServiceConnectionGetHandler.cs and the /get route in app.py.
# Returns 404 if the service connection does not exist.

function Invoke-GetResource {
    $body        = $WebEvent.Data
    $identifiers = $body.identifiers | ConvertPSObject-ToHashtable

    $org  = $identifiers['organization']
    $proj = $identifiers['project']
    $name = $identifiers['name']

    if (-not ($org -and $proj -and $name)) {
        Write-ErrorResponse -Code 'MissingIdentifiers' `
            -Message "identifiers must include 'organization', 'project', and 'name'."
        return
    }

    try {
        $ado = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
    } catch {
        Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
        return
    }

    if (-not $ado) {
        Write-NotFoundResponse -Message "Service connection '$name' not found in project '$proj'."
        return
    }

    $resource = ConvertTo-ResourceBody -Type $body.type -ApiVersion $body.apiVersion `
                    -Identifiers $identifiers -AdoEndpoint $ado
    Write-OkResponse -Body $resource
}
