using System.Text.Json.Serialization;

namespace ITL.Bicep.Extensions.AzureDevOps.Models;

// ADO REST API response shapes — kept minimal to what we need

internal class AdoEndpointResponse
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("type")]
    public string? Type { get; set; }

    [JsonPropertyName("url")]
    public string? Url { get; set; }

    [JsonPropertyName("authorization")]
    public AdoAuthorization? Authorization { get; set; }

    [JsonPropertyName("data")]
    public Dictionary<string, string>? Data { get; set; }

    [JsonPropertyName("isShared")]
    public bool IsShared { get; set; }

    [JsonPropertyName("operationStatus")]
    public AdoOperationStatus? OperationStatus { get; set; }
}

internal class AdoAuthorization
{
    [JsonPropertyName("scheme")]
    public string? Scheme { get; set; }

    [JsonPropertyName("parameters")]
    public Dictionary<string, string>? Parameters { get; set; }
}

internal class AdoOperationStatus
{
    [JsonPropertyName("state")]
    public string? State { get; set; }

    [JsonPropertyName("statusMessage")]
    public string? StatusMessage { get; set; }
}

internal class AdoEndpointListResponse
{
    [JsonPropertyName("value")]
    public List<AdoEndpointResponse>? Value { get; set; }

    [JsonPropertyName("count")]
    public int Count { get; set; }
}
