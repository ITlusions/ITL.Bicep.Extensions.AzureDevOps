using System.Text.Json.Serialization;

namespace ITL.Bicep.Extensions.AzureDevOps.Models;

[JsonSerializable(typeof(ServiceConnectionProperties))]
[JsonSerializable(typeof(ServiceConnectionIdentifiers))]
[JsonSerializable(typeof(ServiceConnectionAuthorization))]
[JsonSerializable(typeof(Dictionary<string, string>))]
[JsonSerializable(typeof(AdoEndpointResponse))]
[JsonSerializable(typeof(AdoEndpointListResponse))]
internal sealed partial class ServiceConnectionSerializerContext : JsonSerializerContext;
