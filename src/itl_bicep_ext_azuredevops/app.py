"""
Bicep Extensibility V2 — FastAPI implementation for Azure DevOps Service Connections.

HTTP routes (all POST, as required by the contract):
  POST /{version}/resource/preview
  POST /{version}/resource/createOrUpdate
  POST /{version}/resource/get
  POST /{version}/resource/delete
  POST /{version}/longRunningOperation/get  (stub — ADO ops are synchronous)
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Request, Response
from fastapi.responses import JSONResponse

from .ado_client import AdoApiError, AdoServiceConnectionClient
from .contract import (
    ErrorResponse,
    Resource,
    ResourcePreview,
    ResourcePreviewMetadata,
    ResourcePreviewSpecification,
    ResourceReference,
    ResourceSpecification,
)

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(
    title="ITL Bicep Extension — Azure DevOps Service Connections",
    version="1.0.0",
    docs_url="/scalar/v1",  # mirrors MagicEightBall sample convention
)

# Authentication via DefaultAzureCredential — no PAT required.
# Supports Workload Identity Federation (AKS / Azure Pipelines),
# Managed Identity (ACI, App Service, VM), and Azure CLI for local dev.
_ado = AdoServiceConnectionClient()


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------

def _response_headers() -> dict[str, str]:
    return {
        "x-ms-request-id": str(uuid.uuid4()),
        "Date": datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT"),
    }


def _error(code: str, message: str, target: str | None = None, status: int = 400) -> JSONResponse:
    body = ErrorResponse.make(code, message, target)
    return JSONResponse(body.model_dump(by_alias=True), status_code=status, headers=_response_headers())


def _ok(body: Any) -> JSONResponse:
    data = body.model_dump(by_alias=True) if hasattr(body, "model_dump") else body
    return JSONResponse(data, status_code=200, headers=_response_headers())


def _extract_identifiers(raw: dict[str, Any]) -> tuple[str, str, str] | None:
    """Returns (organization, project, name) or None."""
    org = raw.get("organization")
    proj = raw.get("project")
    name = raw.get("name")
    if org and proj and name:
        return str(org), str(proj), str(name)
    return None


def _map_to_resource(req_type: str, req_api: str | None, identifiers: dict, ado: dict) -> Resource:
    auth = ado.get("authorization") or {}
    props: dict[str, Any] = {
        "name": ado.get("name"),
        "type": ado.get("type"),
        "url": ado.get("url"),
        "authorization": {
            "scheme": auth.get("scheme"),
            "parameters": _ado.filter_secret_params(auth.get("parameters")),
        },
        "data": ado.get("data"),
        "isShared": ado.get("isShared", False),
        "id": ado.get("id"),
        "operationStatus": (ado.get("operationStatus") or {}).get("state"),
    }
    return Resource(
        type=req_type,
        apiVersion=req_api,
        identifiers=identifiers,
        properties=props,
    )


# ---------------------------------------------------------------------------
# Resource endpoints
# ---------------------------------------------------------------------------

@app.post("/{extension_version}/resource/preview")
async def preview_resource(
    extension_version: str,
    body: ResourcePreviewSpecification,
    x_ms_client_request_id: str = Header(...),
    x_ms_correlation_request_id: str = Header(...),
    referer: str = Header(...),
    traceparent: str = Header(...),
    tracestate: str = Header(...),
) -> JSONResponse:
    props = body.properties
    conn_type = props.get("type", "")

    preview = ResourcePreview(
        type=body.type,
        apiVersion=body.api_version,
        identifiers={"name": props.get("name"), **{}},
        properties={
            **props,
            "id": "(assigned by Azure DevOps on create)",
            "operationStatus": "Ready",
            "url": props.get("url") or _get_default_url(conn_type),
        },
        metadata=ResourcePreviewMetadata(
            readOnly=["/properties/id"],
            calculated=["/properties/id", "/properties/operationStatus"],
        ),
    )
    return _ok(preview)


@app.post("/{extension_version}/resource/createOrUpdate")
async def create_or_update_resource(
    extension_version: str,
    body: ResourceSpecification,
    x_ms_client_request_id: str = Header(...),
    x_ms_correlation_request_id: str = Header(...),
    referer: str = Header(...),
    traceparent: str = Header(...),
    tracestate: str = Header(...),
) -> JSONResponse:
    identifiers = body.properties  # identifiers passed inline for simplicity
    # Identifiers must come from the request body's `identifiers` block (injected via config)
    # For this extension the user declares identifiers as: { organization, project, name }
    # They arrive in ResourceSpecification.properties — but the contract puts them in a
    # separate top-level field. We read from config if present, otherwise from properties.
    ids = _extract_identifiers(body.properties)
    if ids is None:
        return _error(
            "MissingIdentifiers",
            "properties must include 'organization', 'project', and 'name'.",
        )
    organization, project, name = ids

    props = body.properties
    if not props.get("type"):
        return _error("MissingProperty", "Property 'type' is required.", "/properties/type")

    try:
        existing = await _ado._get_by_name_internal(organization, project, name)
        if existing:
            ado_result = await _ado.update(organization, project, existing["id"], props)
        else:
            ado_result = await _ado.create(organization, project, props)
    except AdoApiError as exc:
        return _error("AdoApiError", str(exc), status=502)

    resource = _map_to_resource(body.type, body.api_version, {"organization": organization, "project": project, "name": name}, ado_result)
    return _ok(resource)


@app.post("/{extension_version}/resource/get")
async def get_resource(
    extension_version: str,
    body: ResourceReference,
    x_ms_client_request_id: str = Header(...),
    x_ms_correlation_request_id: str = Header(...),
    referer: str = Header(...),
    traceparent: str = Header(...),
    tracestate: str = Header(...),
) -> JSONResponse:
    ids = _extract_identifiers(body.identifiers)
    if ids is None:
        return _error("MissingIdentifiers", "Identifiers must include 'organization', 'project', and 'name'.")
    organization, project, name = ids

    try:
        ado = await _ado._get_by_name_internal(organization, project, name)
    except AdoApiError as exc:
        return _error("AdoApiError", str(exc), status=502)

    if ado is None:
        resp = ErrorResponse.not_found(f"Service connection '{name}' not found in project '{project}'.")
        return JSONResponse(resp.model_dump(by_alias=True), status_code=404, headers=_response_headers())

    resource = _map_to_resource(body.type, body.api_version, body.identifiers, ado)
    return _ok(resource)


@app.post("/{extension_version}/resource/delete")
async def delete_resource(
    extension_version: str,
    body: ResourceReference,
    x_ms_client_request_id: str = Header(...),
    x_ms_correlation_request_id: str = Header(...),
    referer: str = Header(...),
    traceparent: str = Header(...),
    tracestate: str = Header(...),
) -> JSONResponse:
    ids = _extract_identifiers(body.identifiers)
    if ids is None:
        return _error("MissingIdentifiers", "Identifiers must include 'organization', 'project', and 'name'.")
    organization, project, name = ids

    try:
        existing = await _ado._get_by_name_internal(organization, project, name)
        if existing is None:
            # Already gone — 204 No Content (idempotent)
            return Response(status_code=204, headers=_response_headers())
        await _ado.delete(organization, project, existing["id"])
    except AdoApiError as exc:
        return _error("AdoApiError", str(exc), status=502)

    # 204 No Content on successful synchronous delete
    return Response(status_code=204, headers=_response_headers())


@app.post("/{extension_version}/longRunningOperation/get")
async def get_long_running_operation(
    extension_version: str,
    body: dict,
    x_ms_client_request_id: str = Header(...),
    x_ms_correlation_request_id: str = Header(...),
    referer: str = Header(...),
    traceparent: str = Header(...),
    tracestate: str = Header(...),
) -> JSONResponse:
    # ADO service connection operations are synchronous — no LROs expected
    return _error("UnknownOperation", "This extension does not use long-running operations.", status=404)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_default_url(conn_type: str) -> str:
    return {
        "azurerm": "https://management.azure.com/",
        "github": "https://github.com/",
    }.get(conn_type.lower(), "https://dev.azure.com/")
