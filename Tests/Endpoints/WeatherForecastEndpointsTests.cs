using System.Net;
using System.Net.Http.Json;
using MyApi.Models;
using MyApi.Tests.Helpers;
using Xunit;

namespace MyApi.Tests.Endpoints;

public class WeatherForecastEndpointsTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public WeatherForecastEndpointsTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetWeatherForecast_Returns200OK()
    {
        var response = await _client.GetAsync("/weatherforecast");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetWeatherForecast_ReturnsFiveItems()
    {
        var forecasts = await _client.GetFromJsonAsync<List<WeatherForecast>>("/weatherforecast");
        Assert.NotNull(forecasts);
        Assert.Equal(5, forecasts!.Count);
    }

    [Fact]
    public async Task GetWeatherForecast_EachItem_HasValidTemperatureF()
    {
        var forecasts = await _client.GetFromJsonAsync<List<WeatherForecast>>("/weatherforecast");
        Assert.NotNull(forecasts);
        foreach (var f in forecasts!)
        {
            var expected = 32 + (int)(f.TemperatureC / 0.5556);
            Assert.Equal(expected, f.TemperatureF);
        }
    }
}
