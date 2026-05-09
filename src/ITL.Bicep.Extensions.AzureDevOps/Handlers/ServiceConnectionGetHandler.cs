using Azure.Deployments.Extensibility.Core.V2.Contracts;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Exceptions;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Handlers;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Models;
using ITL.Bicep.Extensions.AzureDevOps.Models;
using ITL.Bicep.Extensions.AzureDevOps.Services;

namespace ITL.Bicep.Extensions.AzureDevOps.Handlers;

/// <summary>
/// Reads an existing Azure DevOps service connection by name.
/// </summary>
public sealed class ServiceConnectionGetHandler(AdoServiceConnectionClient adoClient)
    : IResourceGetHandler
{
    public async Task<OneOf<Resource, ErrorResponse>> HandleAsync(
        ResourceReference request,
        CancellationToken ct)
    {
        var identifiers = request.Identifiers?.Deserialize<ServiceConnectionIdentifiers>();

        if (identifiers?.Organization is null || identifiers.Project is null || identifiers.Name is null)
            throw new ErrorResponseException("MissingIdentifiers",
                "Identifiers 'organization', 'project', and 'name' are required.");

        AdoEndpointResponse? ado;

        try
        {
            ado = await adoClient.GetByNameAsync(
                identifiers.Organization, identifiers.Project, identifiers.Name, ct);
        }
        catch (AdoApiException ex)
        {
            throw new ErrorResponseException("AdoApiError",
                $"Azure DevOps API returned {ex.StatusCode}: {ex.Message}");
        }

        if (ado is null)
            return OneOf<Resource, ErrorResponse>.FromT1(
                ErrorResponse.NotFound($"Service connection '{identifiers.Name}' not found in project '{identifiers.Project}'."));

        var props = new ServiceConnectionProperties
        {
            Name = ado.Name,
            Type = ado.Type,
            Url = ado.Url,
            Authorization = ado.Authorization is null ? null : new ServiceConnectionAuthorization
            {
                Scheme = ado.Authorization.Scheme,
                Parameters = null // never return credentials
            },
            Data = ado.Data,
            IsShared = ado.IsShared,
            Id = ado.Id,
            OperationStatus = ado.OperationStatus?.State
        };

        return OneOf<Resource, ErrorResponse>.FromT0(new Resource
        {
            Type = request.Type,
            ApiVersion = request.ApiVersion,
            Identifiers = System.Text.Json.JsonSerializer.SerializeToNode(identifiers),
            Properties = System.Text.Json.JsonSerializer.SerializeToNode(props)
        });
    }
}
