using Microsoft.EntityFrameworkCore;
using MyApi.Data;
using MyApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>();
builder.Services.AddSwaggerGen();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

// Health endpoints — ACA uses these for probes
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

// Version endpoint — useful for verifying which revision is live
app.MapGet("/version", () => new {
    version = "1.0.0",
    revision = Environment.GetEnvironmentVariable("REVISION_LABEL") ?? "unknown",
    timestamp = DateTime.UtcNow
});

app.MapOpenApi();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast =  Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast");

app.MapPost("/cities", async (CreateCityRequest request, AppDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.Name))
        return Results.BadRequest("City name is required.");

    var city = new City { Name = request.Name.Trim() };
    db.Cities.Add(city);
    await db.SaveChangesAsync();
    return Results.Created($"/cities/{city.Id}", city);
})
.WithName("CreateCity")
.WithTags("Cities");

app.MapGet("/cities", async (AppDbContext db) =>
    await db.Cities.OrderBy(c => c.Name).ToListAsync())
.WithName("GetCities")
.WithTags("Cities");

app.UseSwagger();
app.UseSwaggerUI();

await app.RunAsync();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}

record CreateCityRequest(string Name);
