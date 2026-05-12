using System.Net;
using System.Net.Http.Json;
using MyApi.Models;
using MyApi.Tests.Helpers;
using Xunit;

namespace MyApi.Tests.Endpoints;

public class CityEndpointsTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public CityEndpointsTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task PostCity_ValidName_Returns201Created()
    {
        var response = await _client.PostAsJsonAsync("/cities", new CreateCityRequest("London"));
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task PostCity_EmptyName_Returns400BadRequest()
    {
        var response = await _client.PostAsJsonAsync("/cities", new CreateCityRequest(""));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostCity_WhitespaceName_Returns400BadRequest()
    {
        var response = await _client.PostAsJsonAsync("/cities", new CreateCityRequest("   "));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostCity_TrimsCityName_BeforeSaving()
    {
        var response = await _client.PostAsJsonAsync("/cities", new CreateCityRequest("  Berlin  "));
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var city = await response.Content.ReadFromJsonAsync<City>();
        Assert.Equal("Berlin", city!.Name);
    }

    [Fact]
    public async Task GetCities_ReturnsOk()
    {
        var response = await _client.GetAsync("/cities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetCities_MultipleEntries_ReturnsSortedByName()
    {
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Zurich"));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Amsterdam"));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Madrid"));

        var cities = await _client.GetFromJsonAsync<List<City>>("/cities");

        Assert.NotNull(cities);
        var names = cities!.Select(c => c.Name).ToList();
        var sortedNames = names.OrderBy(n => n).ToList();
        Assert.Equal(sortedNames, names);
    }
}
