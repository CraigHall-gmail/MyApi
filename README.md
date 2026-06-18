# MyApi

A .NET 10 REST API built with ASP.NET Core Minimal APIs, Entity Framework Core, and PostgreSQL. Deployed to Azure Container Apps with zero-downtime blue/green deployments across development, staging, and production environments.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | .NET 10, ASP.NET Core Minimal APIs |
| Database | PostgreSQL via EF Core 10 + Npgsql |
| Containers | Docker (multi-stage), Azure Container Registry |
| Hosting | Azure Container Apps |
| Secrets | Azure Key Vault |
| API Docs | OpenAPI 3.0 + Swagger UI |
| Testing | xUnit, ASP.NET Core TestServer, EF InMemory |
| Code Quality | SonarCloud, CodeQL |
| Versioning | GitVersion (semantic versioning from git history) |

---

## Getting Started

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [PostgreSQL](https://www.postgresql.org/download/) running locally on port 5432

### Local setup

1. Clone the repository and restore dependencies:

   ```bash
   dotnet restore
   ```

2. Create the local database (default credentials: `postgres` / `admin`):

   ```bash
   dotnet ef database update
   ```

3. Run the API:

   ```bash
   dotnet run --launch-profile local
   ```

4. Open Swagger UI at `http://localhost:5200` — it redirects from `/` automatically.

### Connection string

The default local connection string is set in `appsettings.json`:

```
Host=localhost;Port=5432;Database=myapi;Username=postgres;Password=admin
```

Override it in `appsettings.Local.json` (gitignored) for personal environments.

---

## API Endpoints

| Method | Path | Description | Response |
|---|---|---|---|
| `GET` | `/` | Redirect to Swagger UI | 302 |
| `GET` | `/swagger` | Interactive Swagger UI | 200 |
| `GET` | `/openapi/v1.json` | OpenAPI 3.0 schema | 200 |
| `GET` | `/health/live` | Liveness probe | 200 |
| `GET` | `/health/ready` | Readiness probe (includes DB check) | 200 |
| `GET` | `/version` | API version and revision info | 200 |
| `POST` | `/cities` | Create a city | 201 / 400 |
| `GET` | `/cities` | List all cities (sorted by name) | 200 |
| `DELETE` | `/cities/{id}` | Delete a city | 204 / 404 |
| `GET` | `/cities/search?q=` | Case-insensitive city search | 200 |
| `GET` | `/weatherforecast` | Sample 5-day weather forecast | 200 |

### Example requests

```bash
# Create a city
curl -X POST http://localhost:5200/cities \
  -H "Content-Type: application/json" \
  -d '{"name": "Auckland"}'

# List cities
curl http://localhost:5200/cities

# Search cities
curl "http://localhost:5200/cities/search?q=auck"

# Check version
curl http://localhost:5200/version
```

### Version endpoint response

```json
{
  "version": "1.2.0",
  "revision": "v1-2-0-abc1234",
  "timestamp": "2026-06-18T16:12:34.567Z"
}
```

---

## Project Structure

```
MyApi/
├── Program.cs                        # All endpoints and DI configuration
├── MyApi.csproj
├── MyApi.sln
├── Dockerfile
├── GitVersion.yml                    # Semantic versioning configuration
├── appsettings*.json                 # Environment-specific configuration
├── Data/
│   ├── AppDbContext.cs
│   └── Migrations/
├── Models/
│   ├── City.cs                       # Entity: Id, Name, CreatedAt
│   ├── CreateCityRequest.cs          # POST body DTO
│   └── WeatherForecast.cs
├── Tests/
│   ├── MyApi.Tests.csproj
│   ├── Endpoints/                    # Integration tests per endpoint group
│   ├── Models/                       # Unit tests for model classes
│   └── Helpers/
│       └── CustomWebApplicationFactory.cs
└── .github/
    └── workflows/                    # CI/CD pipelines (see below)
```

---

## Testing

Run all tests:

```bash
dotnet test
```

Run with code coverage:

```bash
dotnet test --collect:"XPlat Code Coverage"
```

Tests use an in-memory EF Core database via `CustomWebApplicationFactory` — no running PostgreSQL instance required.

**Test coverage:**
- `CityEndpointsTests` — 14 tests covering CRUD and search validation
- `VersionEndpointTests` — version response shape and fields
- `WeatherForecastEndpointsTests` — forecast endpoint behaviour
- `CityTests`, `WeatherForecastTests` — model unit tests

---

## Docker

Build the image locally:

```bash
docker build -t myapi:local .
```

Run with a local PostgreSQL connection:

```bash
docker run -p 8080:8080 \
  -e ConnectionStrings__DefaultConnection="Host=host.docker.internal;Port=5432;Database=myapi;Username=postgres;Password=admin" \
  myapi:local
```

The image runs as a non-root user and exposes port `8080`.

---

## Database Migrations

Create a new migration after changing models:

```bash
dotnet ef migrations add <MigrationName>
```

Apply pending migrations:

```bash
dotnet ef database update
```

In CI/CD, migrations run automatically via `App-EF-Migrate.yml` before each deployment.

---

## CI/CD & Workflows

See [`.github/workflows/README.md`](.github/workflows/README.md) for the full pipeline documentation, including:

- Branching strategy (`feature/*` → `development` → `main`)
- Blue/green deployment detail
- Hotfix flow with automatic back-merge
- Manual rollback instructions
- GitHub Environments and OIDC federation setup
- Semantic versioning

### Quick reference

| Workflow | Trigger | Purpose |
|---|---|---|
| `App-CI.yml` | Push / PR | Build, test, scan, push image, deploy |
| `_shared-cd.yml` | Called by CI | Zero-downtime blue/green deployment |
| `App-EF-Migrate.yml` | Called by CD | Run EF Core migrations |
| `App-Hotfix-Backmerge.yml` | Hotfix merged to main | Open back-merge PR to development |
| `App-Rollback.yml` | Manual | Restore previous ACA revision |
| `codeql.yml` | PR / scheduled | CodeQL security analysis |

### Environments

| Environment | Branch | Approval |
|---|---|---|
| Development | `development` | Automatic |
| Staging | `main`, `hotfix/*` | Automatic |
| Production | `main`, `hotfix/*` | Manual approval required |

---

## Configuration

| File | Used in |
|---|---|
| `appsettings.json` | All environments (base config) |
| `appsettings.Development.json` | Azure Container Apps dev environment |
| `appsettings.Staging.json` | Azure Container Apps staging |
| `appsettings.Production.json` | Azure Container Apps production |
| `appsettings.Local.json` | Local overrides (gitignored) |

In deployed environments, `ConnectionStrings__DefaultConnection` is injected at deploy time from Azure Key Vault — it is never stored in source control.

---

## Infrastructure

Infrastructure provisioning (Terraform, drift detection) lives in the [**MyApi-Infra**](https://github.com/HallCraig/MyApi-Infra) repository.
