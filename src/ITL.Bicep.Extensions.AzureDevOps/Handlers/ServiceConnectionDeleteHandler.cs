using Azure.Deployments.Extensibility.Core.V2.Contracts;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Exceptions;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Handlers;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Models;
using ITL.Bicep.Extensions.AzureDevOps.Models;
using ITL.Bicep.Extensions.AzureDevOps.Services;

namespace ITL.Bicep.Extensions.AzureDevOps.Handlers;

/// <summary>
/// Deletes an Azure DevOps service connection by name.
/// Returns 204 if the connection was already absent (idempotent delete).
/// </summary>
public sealed class ServiceConnectionDeleteHandler(AdoServiceConnectionClient adoClient)
    : IResourceDeleteHandler
{
    public async Task<OneOf<Resource?, ErrorResponse>> HandleAsync(
        ResourceReference request,
        CancellationToken ct)
    {
        var identifiers = request.Identifiers?.Deserialize<ServiceConnectionIdentifiers>();

        if (identifiers?.Organization is null || identifiers.Project is null || identifiers.Name is null)
            throw new ErrorResponseException("MissingIdentifiers",
                "Identifiers 'organization', 'project', and 'name' are required.");

        try
        {
            // Resolve the endpoint ID — delete requires the GUID, not the name
            var existing = await adoClient.GetByNameAsync(
                identifiers.Organization, identifiers.Project, identifiers.Name, ct);

            if (existing is null)
            {
                // Already gone — idempotent, return null (204 No Content)
                return OneOf<Resource?, ErrorResponse>.FromT0(null);
            }

            await adoClient.DeleteAsync(identifiers.Organization, identifiers.Project, existing.Id!, ct);
        }
        catch (AdoApiException ex)
        {
            throw new ErrorResponseException("AdoApiError",
                $"Azure DevOps API returned {ex.StatusCode}: {ex.Message}");
        }

        // Return null to signal successful deletion (204)
        return OneOf<Resource?, ErrorResponse>.FromT0(null);
    }
}
