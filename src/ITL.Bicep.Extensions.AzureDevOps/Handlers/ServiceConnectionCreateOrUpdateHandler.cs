using Azure.Deployments.Extensibility.Core.V2.Contracts;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Exceptions;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Handlers;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Models;
using ITL.Bicep.Extensions.AzureDevOps.Models;
using ITL.Bicep.Extensions.AzureDevOps.Services;

namespace ITL.Bicep.Extensions.AzureDevOps.Handlers;

/// <summary>
/// Creates or updates an Azure DevOps service connection.
/// Idempotent: if a connection with the same name already exists in the project,
/// it is updated in place.
/// </summary>
public sealed class ServiceConnectionCreateOrUpdateHandler(AdoServiceConnectionClient adoClient)
    : IResourceCreateOrUpdateHandler
{
    public async Task<OneOf<Resource, LongRunningOperation, ErrorResponse>> HandleAsync(
        ResourceSpecification request,
        CancellationToken ct)
    {
        var identifiers = request.Identifiers?.Deserialize<ServiceConnectionIdentifiers>();
        var props = request.Properties?.Deserialize<ServiceConnectionProperties>();

        if (identifiers?.Organization is null || identifiers.Project is null)
            throw new ErrorResponseException("MissingIdentifiers",
                "Identifiers 'organization' and 'project' are required.");

        if (props?.Name is null)
            throw new ErrorResponseException("MissingProperty",
                "Property 'name' is required.", "/properties/name");

        if (props.Type is null)
            throw new ErrorResponseException("MissingProperty",
                "Property 'type' is required.", "/properties/type");

        AdoEndpointResponse adoResult;

        try
        {
            // Check for existing connection to make this idempotent
            var existing = await adoClient.GetByNameAsync(
                identifiers.Organization, identifiers.Project, props.Name, ct);

            adoResult = existing is null
                ? await adoClient.CreateAsync(identifiers.Organization, identifiers.Project, props, ct)
                : await adoClient.UpdateAsync(identifiers.Organization, identifiers.Project, existing.Id!, props, ct);
        }
        catch (AdoApiException ex)
        {
            throw new ErrorResponseException("AdoApiError",
                $"Azure DevOps API returned {ex.StatusCode}: {ex.Message}");
        }

        var result = MapToResource(request, identifiers, adoResult);
        return OneOf<Resource, LongRunningOperation, ErrorResponse>.FromT0(result);
    }

    private static Resource MapToResource(
        ResourceSpecification request,
        ServiceConnectionIdentifiers identifiers,
        AdoEndpointResponse ado)
    {
        var props = new ServiceConnectionProperties
        {
            Name = ado.Name,
            Type = ado.Type,
            Url = ado.Url,
            Authorization = ado.Authorization is null ? null : new ServiceConnectionAuthorization
            {
                Scheme = ado.Authorization.Scheme,
                // Never return secret parameters back to Bicep
                Parameters = FilterSecretParameters(ado.Authorization.Parameters)
            },
            Data = ado.Data,
            IsShared = ado.IsShared,
            Id = ado.Id,
            OperationStatus = ado.OperationStatus?.State
        };

        return new Resource
        {
            Type = request.Type,
            ApiVersion = request.ApiVersion,
            Identifiers = System.Text.Json.JsonSerializer.SerializeToNode(identifiers),
            Properties = System.Text.Json.JsonSerializer.SerializeToNode(props)
        };
    }

    /// <summary>
    /// Strips secret credential values so they are never echoed back in Bicep state.
    /// </summary>
    private static Dictionary<string, string>? FilterSecretParameters(
        Dictionary<string, string>? parameters)
    {
        if (parameters is null) return null;

        var secretKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "accesstoken", "password", "serviceprincipalkey", "privatekey", "apitoken"
        };

        return parameters
            .Where(kv => !secretKeys.Contains(kv.Key))
            .ToDictionary(kv => kv.Key, kv => kv.Value);
    }
}
