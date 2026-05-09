using System.Text.Json.Serialization;

namespace ITL.Bicep.Extensions.AzureDevOps.Models;

/// <summary>
/// Properties for an Azure DevOps Service Connection resource.
/// Maps to the ADO ServiceEndpoint REST model.
/// </summary>
public class ServiceConnectionProperties
{
    /// <summary>Display name of the service connection.</summary>
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    /// <summary>
    /// Service connection type.
    /// Common values: AzureRM, github, AWSServiceEndpoint, dockerregistry, kubernetes
    /// </summary>
    [JsonPropertyName("type")]
    public string? Type { get; set; }

    /// <summary>
    /// Service URL. For AzureRM use https://management.azure.com/
    /// </summary>
    [JsonPropertyName("url")]
    public string? Url { get; set; }

    /// <summary>Authorization configuration for the service connection.</summary>
    [JsonPropertyName("authorization")]
    public ServiceConnectionAuthorization? Authorization { get; set; }

    /// <summary>Type-specific additional data (subscriptionId, tenantId, etc.).</summary>
    [JsonPropertyName("data")]
    public Dictionary<string, string>? Data { get; set; }

    /// <summary>
    /// Whether all pipelines can use this connection.
    /// Defaults to false (explicit pipeline access only).
    /// </summary>
    [JsonPropertyName("isShared")]
    public bool IsShared { get; set; } = false;

    /// <summary>Read-only: endpoint ID assigned by Azure DevOps after creation.</summary>
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    /// <summary>Read-only: connection state reported by ADO.</summary>
    [JsonPropertyName("operationStatus")]
    public string? OperationStatus { get; set; }
}

public class ServiceConnectionAuthorization
{
    /// <summary>
    /// Auth scheme.
    /// Common values: WorkloadIdentityFederation, ServicePrincipal,
    ///                ManagedServiceIdentity, PersonalAccessToken, Token, UsernamePassword
    /// </summary>
    [JsonPropertyName("scheme")]
    public string? Scheme { get; set; }

    /// <summary>Scheme-specific parameters (tenantid, serviceprincipalid, accesstoken, etc.).</summary>
    [JsonPropertyName("parameters")]
    public Dictionary<string, string>? Parameters { get; set; }
}

/// <summary>Identifiers used to look up an existing service connection.</summary>
public class ServiceConnectionIdentifiers
{
    /// <summary>Azure DevOps organization name (e.g. "itlusions").</summary>
    [JsonPropertyName("organization")]
    public string? Organization { get; set; }

    /// <summary>Azure DevOps project name or ID.</summary>
    [JsonPropertyName("project")]
    public string? Project { get; set; }

    /// <summary>Service connection name (unique within the project).</summary>
    [JsonPropertyName("name")]
    public string? Name { get; set; }
}
