using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;
using ITL.Bicep.Extensions.AzureDevOps.Models;

namespace ITL.Bicep.Extensions.AzureDevOps.Services;

/// <summary>
/// Thin client wrapping the Azure DevOps Service Endpoints REST API.
/// Docs: https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints
/// </summary>
public sealed class AdoServiceConnectionClient
{
    private const string ApiVersion = "7.1";
    private readonly HttpClient _http;

    public AdoServiceConnectionClient(HttpClient http)
    {
        _http = http;
    }

    // ------------------------------------------------------------------
    // Create
    // ------------------------------------------------------------------

    public async Task<AdoEndpointResponse> CreateAsync(
        string organization,
        string project,
        ServiceConnectionProperties props,
        CancellationToken ct = default)
    {
        var body = BuildAdoPayload(props, organization, project);
        var url = $"https://dev.azure.com/{Uri.EscapeDataString(organization)}/{Uri.EscapeDataString(project)}/_apis/serviceendpoint/endpoints?api-version={ApiVersion}";

        using var request = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(JsonSerializer.Serialize(body, AdoSerializerOptions.Default), Encoding.UTF8, "application/json")
        };

        var response = await _http.SendAsync(request, ct);
        await EnsureSuccessAsync(response, ct);

        return (await response.Content.ReadFromJsonAsync<AdoEndpointResponse>(AdoSerializerOptions.Default, ct))!;
    }

    // ------------------------------------------------------------------
    // Get by name (ADO supports filter by endpointNames)
    // ------------------------------------------------------------------

    public async Task<AdoEndpointResponse?> GetByNameAsync(
        string organization,
        string project,
        string name,
        CancellationToken ct = default)
    {
        var url = $"https://dev.azure.com/{Uri.EscapeDataString(organization)}/{Uri.EscapeDataString(project)}/_apis/serviceendpoint/endpoints?endpointNames={Uri.EscapeDataString(name)}&api-version={ApiVersion}";

        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        var response = await _http.SendAsync(request, ct);

        if (response.StatusCode == HttpStatusCode.NotFound)
            return null;

        await EnsureSuccessAsync(response, ct);

        var list = await response.Content.ReadFromJsonAsync<AdoEndpointListResponse>(AdoSerializerOptions.Default, ct);
        return list?.Value?.FirstOrDefault(e => string.Equals(e.Name, name, StringComparison.OrdinalIgnoreCase));
    }

    // ------------------------------------------------------------------
    // Update (requires endpoint ID)
    // ------------------------------------------------------------------

    public async Task<AdoEndpointResponse> UpdateAsync(
        string organization,
        string project,
        string endpointId,
        ServiceConnectionProperties props,
        CancellationToken ct = default)
    {
        var body = BuildAdoPayload(props, organization, project);
        body["id"] = endpointId;

        var url = $"https://dev.azure.com/{Uri.EscapeDataString(organization)}/{Uri.EscapeDataString(project)}/_apis/serviceendpoint/endpoints/{endpointId}?api-version={ApiVersion}";

        using var request = new HttpRequestMessage(HttpMethod.Put, url)
        {
            Content = new StringContent(JsonSerializer.Serialize(body, AdoSerializerOptions.Default), Encoding.UTF8, "application/json")
        };

        var response = await _http.SendAsync(request, ct);
        await EnsureSuccessAsync(response, ct);

        return (await response.Content.ReadFromJsonAsync<AdoEndpointResponse>(AdoSerializerOptions.Default, ct))!;
    }

    // ------------------------------------------------------------------
    // Delete
    // ------------------------------------------------------------------

    public async Task<bool> DeleteAsync(
        string organization,
        string project,
        string endpointId,
        CancellationToken ct = default)
    {
        var url = $"https://dev.azure.com/{Uri.EscapeDataString(organization)}/{Uri.EscapeDataString(project)}/_apis/serviceendpoint/endpoints/{endpointId}?api-version={ApiVersion}";

        using var request = new HttpRequestMessage(HttpMethod.Delete, url);
        var response = await _http.SendAsync(request, ct);

        if (response.StatusCode == HttpStatusCode.NotFound)
            return false;

        await EnsureSuccessAsync(response, ct);
        return true;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static Dictionary<string, object?> BuildAdoPayload(
        ServiceConnectionProperties props,
        string organization,
        string project)
    {
        return new Dictionary<string, object?>
        {
            ["name"] = props.Name,
            ["type"] = props.Type,
            ["url"] = props.Url ?? GetDefaultUrl(props.Type),
            ["authorization"] = props.Authorization is null ? null : new Dictionary<string, object?>
            {
                ["scheme"] = props.Authorization.Scheme,
                ["parameters"] = props.Authorization.Parameters
            },
            ["data"] = props.Data,
            ["isShared"] = props.IsShared,
            ["serviceEndpointProjectReferences"] = new[]
            {
                new Dictionary<string, object?>
                {
                    ["projectReference"] = new Dictionary<string, string>
                    {
                        ["name"] = project
                    },
                    ["name"] = props.Name
                }
            }
        };
    }

    private static string GetDefaultUrl(string? type) => type?.ToLowerInvariant() switch
    {
        "azurerm" => "https://management.azure.com/",
        "github" => "https://github.com/",
        _ => "https://dev.azure.com/"
    };

    private static async Task EnsureSuccessAsync(HttpResponseMessage response, CancellationToken ct)
    {
        if (response.IsSuccessStatusCode)
            return;

        var body = await response.Content.ReadAsStringAsync(ct);
        throw new AdoApiException((int)response.StatusCode, response.ReasonPhrase ?? "Unknown error", body);
    }
}

/// <summary>
/// Delegating handler that injects an Azure AD Bearer token for every ADO API request.
/// Uses <see cref="DefaultAzureCredential"/> by default, which covers Managed Identity,
/// Workload Identity Federation (AKS), Service Principal, and Azure CLI for local dev.
/// Tokens are cached and refreshed automatically by the credential.
/// </summary>
internal sealed class AzureAdBearerTokenHandler : DelegatingHandler
{
    // Well-known Azure AD application ID for Azure DevOps
    private static readonly string[] AdoScopes = ["499b84ac-1321-427f-aa17-267ca6975798/.default"];

    private readonly TokenCredential _credential;

    public AzureAdBearerTokenHandler(TokenCredential credential)
    {
        _credential = credential;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var tokenRequestContext = new TokenRequestContext(AdoScopes);
        var accessToken = await _credential.GetTokenAsync(tokenRequestContext, cancellationToken);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);
        return await base.SendAsync(request, cancellationToken);
    }
}

/// <summary>
/// Configures the <see cref="AdoServiceConnectionClient"/> using Azure Workload Identity /
/// Managed Identity. No PAT required — authentication flows through <see cref="DefaultAzureCredential"/>.
/// </summary>
public static class AdoHttpClientExtensions
{
    public static IHttpClientBuilder AddAdoServiceConnectionClient(
        this IServiceCollection services,
        TokenCredential? credential = null)
    {
        var resolvedCredential = credential ?? new DefaultAzureCredential();
        services.AddSingleton(new AzureAdBearerTokenHandler(resolvedCredential));

        return services.AddHttpClient<AdoServiceConnectionClient>(client =>
        {
            client.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
        })
        .AddHttpMessageHandler<AzureAdBearerTokenHandler>();
    }
}

public sealed class AdoApiException(int statusCode, string reason, string body)
    : Exception($"ADO API error {statusCode} ({reason}): {body}")
{
    public int StatusCode { get; } = statusCode;
    public string Body { get; } = body;
}

internal static class AdoSerializerOptions
{
    internal static readonly JsonSerializerOptions Default = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        TypeInfoResolverChain = { ServiceConnectionSerializerContext.Default }
    };
}
