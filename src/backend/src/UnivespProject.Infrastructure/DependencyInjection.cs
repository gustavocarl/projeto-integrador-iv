using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UnivespProject.Application.Abstractions;
using UnivespProject.Infrastructure.ExternalApi;
using UnivespProject.Infrastructure.MachineLearning;
using UnivespProject.Infrastructure.Persistence;
using UnivespProject.Infrastructure.Persistence.Interceptors;
using UnivespProject.Infrastructure.Persistence.Repositories;
using UnivespProject.Infrastructure.Security;
using UnivespProject.Infrastructure.Spreadsheets;
using UnivespProject.Infrastructure.Storage;

namespace UnivespProject.Infrastructure;

public static class DependencyInjection
{
    /// <param name="contentRootPath">The API's content root: relative image folders are resolved against it.</param>
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration configuration, string contentRootPath)
    {
        services.AddPersistence(configuration);
        services.AddSecurity(configuration);
        services.AddSingleton<ISalesSpreadsheet, ClosedXmlSalesSpreadsheet>();
        services.AddSingleton<ISalesForecaster, MlNetSalesForecaster>();
        services.AddSingleton<IProductClusterer, MlNetProductClusterer>();
        services.AddExternalApi(configuration);
        services.AddProductImageStorage(configuration, contentRootPath);

        return services;
    }

    private static void AddPersistence(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("Connection string 'DefaultConnection' não configurada.");

        services.AddScoped<AuditInterceptor>();
        services.AddScoped<StoreOwnershipInterceptor>();
        services.AddScoped<ICurrentStore, CurrentStore>();
        services.AddDbContext<AppDbContext>((sp, options) =>
            options.UseNpgsql(connectionString)
                .AddInterceptors(
                    sp.GetRequiredService<AuditInterceptor>(),
                    sp.GetRequiredService<StoreOwnershipInterceptor>()));

        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IStoreRepository, StoreRepository>();
        services.AddScoped<IUserNotificationRepository, UserNotificationRepository>();
        services.AddScoped<IUserSettingsRepository, UserSettingsRepository>();
        services.AddScoped<IMarketplaceRepository, MarketplaceRepository>();
        services.AddScoped<ISalesImportRepository, SalesImportRepository>();
        services.AddScoped<ISalesReportRepository, SalesReportRepository>();
        services.AddScoped<ISalesExportRepository, SalesExportRepository>();
        services.AddScoped<IProductRepository, ProductRepository>();
    }

    private static void AddProductImageStorage(
        this IServiceCollection services, IConfiguration configuration, string contentRootPath)
    {
        var options = configuration.GetSection(ProductImageStorageOptions.SectionName).Get<ProductImageStorageOptions>()
                      ?? new ProductImageStorageOptions();
        var storage = new LocalProductImageStorage(
            Path.GetFullPath(options.Directory, contentRootPath), options.RequestPath);

        services.AddSingleton(storage);
        services.AddSingleton<IProductImageStorage>(storage);
    }

    private static void AddSecurity(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<JwtOptions>()
            .Bind(configuration.GetSection(JwtOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();
    }

    private static void AddExternalApi(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<ExternalApiOptions>(configuration.GetSection(ExternalApiOptions.SectionName));

        services.AddHttpClient<IExternalDataClient, ExternalDataClient>((sp, client) =>
        {
            var options = sp.GetRequiredService<IOptions<ExternalApiOptions>>().Value;
            if (!string.IsNullOrWhiteSpace(options.BaseUrl))
                client.BaseAddress = new Uri(options.BaseUrl);
            client.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds);
        });
    }
}
