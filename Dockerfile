FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/ITL.Bicep.Extensions.AzureDevOps/ITL.Bicep.Extensions.AzureDevOps.csproj", "src/ITL.Bicep.Extensions.AzureDevOps/"]
RUN dotnet restore "src/ITL.Bicep.Extensions.AzureDevOps/ITL.Bicep.Extensions.AzureDevOps.csproj"
COPY . .
RUN dotnet publish "src/ITL.Bicep.Extensions.AzureDevOps/ITL.Bicep.Extensions.AzureDevOps.csproj" \
    -c Release -o /app/publish --no-restore

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .

# ADO_PAT must be injected at runtime via environment variable or secret store
# Never bake credentials into the image
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "ITL.Bicep.Extensions.AzureDevOps.dll"]
