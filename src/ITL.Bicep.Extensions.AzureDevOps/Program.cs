using Azure.Deployments.Extensibility.AspNetCore;
using Microsoft.AspNetCore.Mvc;
using ITL.Bicep.Extensions.AzureDevOps.Handlers;
using ITL.Bicep.Extensions.AzureDevOps.Models;
using ITL.Bicep.Extensions.AzureDevOps.Services;

// ------------------------------------------------------------------
// Authentication uses Azure Workload Identity / Managed Identity via
// DefaultAzureCredential — no PAT required. The following credential
// chain is tried in order:
//   1. Workload Identity Federation (AKS pod identity / Azure Pipelines)
//   2. Managed Identity (ACI, App Service, VM, AKS with MI)
//   3. Azure CLI  (az login  — for local development)
//   4. Visual Studio / VS Code credential  (local development)
//
// Required: the managed identity or service principal must be a member
// of the Azure DevOps organisation with "Service Connections: Read & manage".
// ------------------------------------------------------------------

var app = ExtensionApplication.Create(args);

// Register services
app.ConfigureServices(services =>
{
    services.AddAdoServiceConnectionClient();  // DefaultAzureCredential — no PAT needed

    services.Configure<JsonOptions>(options =>
    {
        options.SerializerOptions.TypeInfoResolverChain.Insert(
            0, ServiceConnectionSerializerContext.Default);
    });
});

// Register the ServiceConnection resource type under extension version 1.*
app.AddExtensionVersion("1.*.*", version => version
    .ForResourceType("ServiceConnection", type => type
        .AddHandler<ServiceConnectionPreviewHandler>()
        .AddHandler<ServiceConnectionCreateOrUpdateHandler>()
        .AddHandler<ServiceConnectionGetHandler>()
        .AddHandler<ServiceConnectionDeleteHandler>()));

// Optional: Scalar API explorer at /scalar/v1 in Development
if (app.Environment.IsDevelopment())
{
    app.EnableDevelopmentScalarApiExplorer(explorer => explorer
        .WithTitle("ITL Bicep Extension — Azure DevOps Service Connections")
        .WithExtensionVersions("1.0.0"));
}

await app.RunAsync();
