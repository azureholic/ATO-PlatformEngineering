# syntax=docker/dockerfile:1.7

ARG DOTNET_VERSION=10.0

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
WORKDIR /src

COPY CatalogMcpServer.csproj .
RUN dotnet restore CatalogMcpServer.csproj

COPY . .
RUN dotnet publish CatalogMcpServer.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS runtime
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_RUNNING_IN_CONTAINER=true

COPY --from=build /app/publish ./

EXPOSE 8080

ENTRYPOINT ["dotnet", "CatalogMcpServer.dll"]
