# ITL.Bicep.Extensions.AzureDevOps.psm1
# Root module — dot-sources all component files in dependency order.
# Models → Services → Handlers

$private:Root = $PSScriptRoot

. "$private:Root/Models/ServiceConnectionModels.ps1"
. "$private:Root/Services/AdoServiceConnectionClient.ps1"
. "$private:Root/Handlers/Invoke-PreviewResource.ps1"
. "$private:Root/Handlers/Invoke-CreateOrUpdateResource.ps1"
. "$private:Root/Handlers/Invoke-GetResource.ps1"
. "$private:Root/Handlers/Invoke-DeleteResource.ps1"
