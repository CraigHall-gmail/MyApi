using MyApi.Models;
using Xunit;

namespace MyApi.Tests.Models;

public class WeatherForecastTests
{
    [Fact]
    public void TemperatureF_ForZeroCelsius_Returns32()
    {
        var forecast = new WeatherForecast(DateOnly.MinValue, 0, null);
        Assert.Equal(32, forecast.TemperatureF);
    }

    [Fact]
    public void TemperatureF_For100Celsius_Returns211()
    {
        // Formula uses integer truncation: 32 + (int)(100 / 0.5556) = 32 + 179 = 211
        var forecast = new WeatherForecast(DateOnly.MinValue, 100, null);
        Assert.Equal(211, forecast.TemperatureF);
    }

    [Theory]
    [InlineData(-20, -3)]  // 32 + (int)(-35.997) = 32 + -35 = -3
    [InlineData(37, 98)]   // 32 + (int)(66.59) = 32 + 66 = 98
    [InlineData(20, 67)]   // 32 + (int)(35.997) = 32 + 35 = 67
    public void TemperatureF_MatchesFormula(int celsius, int expectedFahrenheit)
    {
        var forecast = new WeatherForecast(DateOnly.MinValue, celsius, null);
        Assert.Equal(expectedFahrenheit, forecast.TemperatureF);
    }
}
