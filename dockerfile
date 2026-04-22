# ── Stage 1: Restore & Build ───────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj first for layer caching
COPY ["MyApi/MyApi.csproj", "MyApi/"]
RUN dotnet restore "MyApi/MyApi.csproj"

# Copy everything else and publish
COPY . .
WORKDIR /src/MyApi
RUN dotnet publish "MyApi.csproj" \
    -c Release \
    -o /app/publish \
    --no-restore

# ── Stage 2: Runtime image ─────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Non-root user (required for ACA / best practice)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

# ACA base image sets ASPNETCORE_HTTP_PORTS=8080
# so this is redundant but explicit is better
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "MyApi.dll"]