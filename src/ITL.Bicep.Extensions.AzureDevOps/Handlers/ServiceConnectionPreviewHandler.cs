using Azure.Deployments.Extensibility.Core.V2.Contracts;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Exceptions;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Handlers;
using Azure.Deployments.Extensibility.Core.V2.Contracts.Models;
using ITL.Bicep.Extensions.AzureDevOps.Models;
using ITL.Bicep.Extensions.AzureDevOps.Services;

namespace ITL.Bicep.Extensions.AzureDevOps.Handlers;

/// <summary>
/// Returns a preview of the service connection without persisting anything.
/// Used by Bicep's what-if operation.
/// </summary>
public sealed class ServiceConnectionPreviewHandler
    : IResourcePreviewHandler
{
    public Task<OneOf<ResourcePreview, ErrorResponse>> HandleAsync(
        ResourceSpecification request,
        CancellationToken ct)
    {
        var props = request.Properties?.Deserialize<ServiceConnectionProperties>()
            ?? new ServiceConnectionProperties();

        var preview = new ResourcePreview
        {
            Type = request.Type,
            ApiVersion = request.ApiVersion,
            Properties = System.Text.Json.JsonSerializer.SerializeToNode(new ServiceConnectionProperties
            {
                Name = props.Name,
                Type = props.Type,
                Url = props.Url ?? GetDefaultUrl(props.Type),
                Authorization = props.Authorization,
                Data = props.Data,
                IsShared = props.IsShared,
                Id = "(assigned by Azure DevOps on create)",
                OperationStatus = "Ready"
            }),
            Metadata = new ResourcePreviewMetadata
            {
                Calculated = ["/properties/id", "/properties/operationStatus"],
                ReadOnly = ["/properties/id"]
            }
        };

        return Task.FromResult(OneOf<ResourcePreview, ErrorResponse>.FromT0(preview));
    }

    private static string GetDefaultUrl(string? type) => type?.ToLowerInvariant() switch
    {
        "azurerm" => "https://management.azure.com/",
        "github" => "https://github.com/",
        _ => "https://dev.azure.com/"
    };
}
