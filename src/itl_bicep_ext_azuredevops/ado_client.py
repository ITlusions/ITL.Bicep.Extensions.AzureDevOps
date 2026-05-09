"""
Azure DevOps Service Endpoints REST API client.
Docs: https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints
"""
from __future__ import annotations

from typing import Any

import httpx
from azure.identity.aio import DefaultAzureCredential

ADO_API_VERSION = "7.1"

# Well-known Azure AD application ID for Azure DevOps
_ADO_SCOPE = "499b84ac-1321-427f-aa17-267ca6975798/.default"

_SECRET_KEYS = frozenset(
    {"accesstoken", "password", "serviceprincipalkey", "privatekey", "apitoken"}
)

_DEFAULT_URLS: dict[str, str] = {
    "azurerm": "https://management.azure.com/",
    "github": "https://github.com/",
}


class AdoApiError(Exception):
    def __init__(self, status_code: int, body: str) -> None:
        super().__init__(f"ADO API error {status_code}: {body}")
        self.status_code = status_code
        self.body = body


class AdoServiceConnectionClient:
    """Thin async client for the ADO Service Endpoints REST API.

    Authentication uses Azure Workload Identity / Managed Identity via
    DefaultAzureCredential — no PAT required. The credential chain covers
    Workload Identity Federation (AKS / Azure Pipelines), Managed Identity
    (ACI, App Service, VM), Azure CLI, and VS Code for local development.
    """

    def __init__(self) -> None:
        self._credential = DefaultAzureCredential()

    async def _get_auth_headers(self) -> dict[str, str]:
        """Return headers with a fresh Azure AD Bearer token for ADO."""
        token = await self._credential.get_token(_ADO_SCOPE)
        return {
            "Authorization": f"Bearer {token.token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    # ------------------------------------------------------------------
    # Create
    # ------------------------------------------------------------------

    async def create(
        self,
        organization: str,
        project: str,
        props: dict[str, Any],
    ) -> dict[str, Any]:
        payload = self._build_payload(props, project)
        url = self._url(organization, project, "")
        async with httpx.AsyncClient() as client:
            r = await client.post(url, json=payload, headers=await self._get_auth_headers())
        return self._unwrap(r)

    # ------------------------------------------------------------------
    # Get by name
    # ------------------------------------------------------------------

    async def get_by_name(
        self,
        organization: str,
        project: str,
        name: str,
    ) -> dict[str, Any] | None:
        url = self._url(organization, project, f"?endpointNames={name}&api-version={ADO_API_VERSION}")
        async with httpx.AsyncClient() as client:
            r = await client.get(url.replace(f"?api-version={ADO_API_VERSION}", ""), headers=await self._get_auth_headers())
        if r.status_code == 404:
            return None
        self._check(r)
        data = r.json()
        for ep in data.get("value", []):
            if ep.get("name", "").lower() == name.lower():
                return ep
        return None

    async def _get_by_name_internal(
        self,
        organization: str,
        project: str,
        name: str,
    ) -> dict[str, Any] | None:
        base_url = f"https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints"
        params = f"?endpointNames={name}&api-version={ADO_API_VERSION}"
        async with httpx.AsyncClient() as client:
            r = await client.get(base_url + params, headers=await self._get_auth_headers())
        if r.status_code == 404:
            return None
        self._check(r)
        for ep in r.json().get("value", []):
            if ep.get("name", "").lower() == name.lower():
                return ep
        return None

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    async def update(
        self,
        organization: str,
        project: str,
        endpoint_id: str,
        props: dict[str, Any],
    ) -> dict[str, Any]:
        payload = self._build_payload(props, project)
        payload["id"] = endpoint_id
        url = f"https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints/{endpoint_id}?api-version={ADO_API_VERSION}"
        async with httpx.AsyncClient() as client:
            r = await client.put(url, json=payload, headers=await self._get_auth_headers())
        return self._unwrap(r)

    # ------------------------------------------------------------------
    # Delete
    # ------------------------------------------------------------------

    async def delete(
        self,
        organization: str,
        project: str,
        endpoint_id: str,
    ) -> bool:
        url = f"https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints/{endpoint_id}?api-version={ADO_API_VERSION}"
        async with httpx.AsyncClient() as client:
            r = await client.delete(url, headers=await self._get_auth_headers())
        if r.status_code == 404:
            return False
        self._check(r)
        return True

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _url(self, organization: str, project: str, suffix: str) -> str:
        return f"https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints?api-version={ADO_API_VERSION}{suffix}"

    @staticmethod
    def _build_payload(props: dict[str, Any], project: str) -> dict[str, Any]:
        conn_type = props.get("type", "")
        return {
            "name": props.get("name"),
            "type": conn_type,
            "url": props.get("url") or _DEFAULT_URLS.get(conn_type.lower(), "https://dev.azure.com/"),
            "authorization": props.get("authorization"),
            "data": props.get("data", {}),
            "isShared": props.get("isShared", False),
            "serviceEndpointProjectReferences": [
                {
                    "projectReference": {"name": project},
                    "name": props.get("name"),
                }
            ],
        }

    @staticmethod
    def filter_secret_params(params: dict[str, str] | None) -> dict[str, str] | None:
        """Strip credential values before returning state to Bicep."""
        if params is None:
            return None
        return {k: v for k, v in params.items() if k.lower() not in _SECRET_KEYS}

    @staticmethod
    def _unwrap(r: httpx.Response) -> dict[str, Any]:
        AdoServiceConnectionClient._check(r)
        return r.json()

    @staticmethod
    def _check(r: httpx.Response) -> None:
        if not r.is_success:
            raise AdoApiError(r.status_code, r.text)
