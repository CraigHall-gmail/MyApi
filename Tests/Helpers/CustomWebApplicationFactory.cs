using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using MyApi.Data;

namespace MyApi.Tests.Helpers;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // Capture the name outside the lambda so all requests within one factory share the same DB.
        // With EF Core 9+, the options config lambda runs per-scope; a Guid inside it would give
        // each request a fresh empty database, breaking cross-request persistence tests.
        var dbName = "TestDb_" + Guid.NewGuid();

        builder.ConfigureTestServices(services =>
        {
            // EF Core 9+ stores the config action as IDbContextOptionsConfiguration<T> separately
            // from DbContextOptions<T>. Both must be removed to prevent "two providers" errors.
            var toRemove = services
                .Where(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>)
                         || d.ServiceType == typeof(AppDbContext)
                         || d.ServiceType == typeof(IDbContextOptionsConfiguration<AppDbContext>))
                .ToList();
            foreach (var d in toRemove) services.Remove(d);

            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase(dbName));
        });
    }
}
