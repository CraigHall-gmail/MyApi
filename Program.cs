var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();
builder.Services.AddSwaggerGen();

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

app.UseHttpsRedirection();

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

app.UseSwagger();
app.UseSwaggerUI();

await app.RunAsync();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
