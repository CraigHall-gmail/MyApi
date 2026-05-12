using MyApi.Models;
using Xunit;

namespace MyApi.Tests.Models;

public class CityTests
{
    [Fact]
    public void City_NewInstance_HasCreatedAtSet()
    {
        var before = DateTime.UtcNow;
        var city = new City { Name = "London" };
        var after = DateTime.UtcNow;

        Assert.InRange(city.CreatedAt, before, after);
    }

    [Fact]
    public void City_CreatedAt_IsUtc()
    {
        var city = new City { Name = "Paris" };
        Assert.Equal(DateTimeKind.Utc, city.CreatedAt.Kind);
    }
}
