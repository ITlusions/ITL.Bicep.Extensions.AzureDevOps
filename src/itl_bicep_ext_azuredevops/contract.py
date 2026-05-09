"""
Bicep Extensibility V2 contract models — transport-agnostic.
Matches the TypeSpec models in spec/core.tsp exactly.
"""
from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Error models
# ---------------------------------------------------------------------------

class ErrorDetail(BaseModel):
    code: str
    message: str
    target: str | None = None


class Error(BaseModel):
    code: str
    message: str
    target: str | None = None
    details: list[ErrorDetail] | None = None
    innererror: dict[str, Any] | None = None


class ErrorResponse(BaseModel):
    error: Error

    @classmethod
    def make(cls, code: str, message: str, target: str | None = None) -> "ErrorResponse":
        return cls(error=Error(code=code, message=message, target=target))

    @classmethod
    def not_found(cls, message: str) -> "ErrorResponse":
        return cls.make("NotFound", message)


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class ResourceReference(BaseModel):
    type: str
    api_version: str | None = Field(None, alias="apiVersion")
    identifiers: dict[str, Any]
    config: dict[str, Any] | None = None
    config_id: str | None = Field(None, alias="configId")

    model_config = {"populate_by_name": True}


class ResourceSpecification(BaseModel):
    type: str
    api_version: str | None = Field(None, alias="apiVersion")
    properties: dict[str, Any]
    config: dict[str, Any] | None = None
    config_id: str | None = Field(None, alias="configId")

    model_config = {"populate_by_name": True}


class ResourcePreviewSpecificationMetadata(BaseModel):
    unevaluated: list[str]


class ResourcePreviewSpecification(ResourceSpecification):
    metadata: ResourcePreviewSpecificationMetadata | None = None


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------

class Resource(BaseModel):
    type: str
    api_version: str | None = Field(None, alias="apiVersion")
    identifiers: dict[str, Any]
    properties: dict[str, Any]
    config: dict[str, Any] | None = None
    config_id: str | None = Field(None, alias="configId")
    status: str | None = None
    error: Error | None = None

    model_config = {"populate_by_name": True}


class ResourcePreviewMetadata(BaseModel):
    read_only: list[str] | None = Field(None, alias="readOnly")
    immutable: list[str] | None = None
    unknown: list[str] | None = None
    calculated: list[str] | None = None
    unevaluated: list[str] | None = None

    model_config = {"populate_by_name": True}


class ResourcePreview(BaseModel):
    type: str
    api_version: str | None = Field(None, alias="apiVersion")
    identifiers: dict[str, Any]
    properties: dict[str, Any]
    status: str | None = None
    config: dict[str, Any] | None = None
    config_id: str | None = Field(None, alias="configId")
    metadata: ResourcePreviewMetadata | None = None

    model_config = {"populate_by_name": True}


class LongRunningOperation(BaseModel):
    status: str
    retry_after_seconds: int | None = Field(None, alias="retryAfterSeconds")
    operation_handle: dict[str, Any] | None = Field(None, alias="operationHandle")
    error: Error | None = None

    model_config = {"populate_by_name": True}
