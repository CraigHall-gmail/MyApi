using System.Net;
using System.Net.Http.Json;
using MyApi.Tests.Helpers;
using Xunit;

namespace MyApi.Tests.Endpoints;

public class VersionEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public VersionEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetVersion_Returns200OK()
    {
        var response = await _client.GetAsync("/version");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetVersion_ResponseContainsVersionAndRevisionFields()
    {
        var result = await _client.GetFromJsonAsync<Dictionary<string, object>>("/version");
        Assert.NotNull(result);
        Assert.True(result!.ContainsKey("version"), "Response should contain 'version' field");
        Assert.True(result.ContainsKey("revision"), "Response should contain 'revision' field");
    }

    [Fact]
    public async Task GetVersion_Revision_DefaultsToUnknownWhenEnvVarNotSet()
    {
        var result = await _client.GetFromJsonAsync<Dictionary<string, object>>("/version");
        Assert.NotNull(result);
        Assert.Equal("unknown", result!["revision"].ToString());
    }
}
