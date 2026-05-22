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

    [Fact]
    public async Task SearchCities_MissingQuery_Returns400BadRequest()
    {
        var response = await _client.GetAsync("/cities/search");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SearchCities_EmptyQuery_Returns400BadRequest()
    {
        var response = await _client.GetAsync("/cities/search?q=");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SearchCities_WhitespaceQuery_Returns400BadRequest()
    {
        var response = await _client.GetAsync("/cities/search?q=   ");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SearchCities_MatchingQuery_ReturnsMatchingCities()
    {
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Barcelona"));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Basel"));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Rome"));

        var cities = await _client.GetFromJsonAsync<List<City>>("/cities/search?q=ba");

        Assert.NotNull(cities);
        Assert.All(cities!, c => Assert.Contains("ba", c.Name, StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(cities!, c => c.Name == "Rome");
    }

    [Fact]
    public async Task SearchCities_CaseInsensitive_ReturnsMatches()
    {
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest("Copenhagen"));

        var cities = await _client.GetFromJsonAsync<List<City>>("/cities/search?q=COPEN");

        Assert.NotNull(cities);
        Assert.Contains(cities!, c => c.Name == "Copenhagen");
    }

    [Fact]
    public async Task SearchCities_NoMatches_ReturnsEmptyList()
    {
        var cities = await _client.GetFromJsonAsync<List<City>>("/cities/search?q=xyznotacityname");

        Assert.NotNull(cities);
        Assert.Empty(cities!);
    }

    [Fact]
    public async Task SearchCities_MultipleMatches_ReturnsSortedByName()
    {
        var suffix = Guid.NewGuid().ToString("N")[..6];
        var city1 = $"Alton_{suffix}";
        var city2 = $"Bolton_{suffix}";
        var city3 = $"Colton_{suffix}";

        await _client.PostAsJsonAsync("/cities", new CreateCityRequest(city1));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest(city2));
        await _client.PostAsJsonAsync("/cities", new CreateCityRequest(city3));

        var cities = await _client.GetFromJsonAsync<List<City>>($"/cities/search?q=lton_{suffix}");

        Assert.NotNull(cities);
        var names = cities!.Select(c => c.Name).ToList();
        Assert.Contains(city1, names);
        Assert.Contains(city2, names);
        Assert.Contains(city3, names);
        Assert.Equal(names.OrderBy(n => n).ToList(), names);
    }
}
