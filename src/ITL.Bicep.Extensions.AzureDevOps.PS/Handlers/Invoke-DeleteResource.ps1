# Handlers/Invoke-DeleteResource.ps1
# Mirrors ServiceConnectionDeleteHandler.cs and the /delete route in app.py.
# Idempotent: returns 204 No Content whether the resource existed or not.

function Invoke-DeleteResource {
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
        $existing = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
        if (-not $existing) {
            # Already absent — idempotent 204
            Write-NoContentResponse
            return
        }
        Remove-AdoConnection -Organization $org -Project $proj -EndpointId $existing.id | Out-Null
    } catch {
        Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
        return
    }

    Write-NoContentResponse
}
