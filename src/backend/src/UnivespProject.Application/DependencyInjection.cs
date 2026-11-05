using UnivespProject.Application.ProductImages;
using Microsoft.Extensions.DependencyInjection;
using UnivespProject.Application.Analytics;
using UnivespProject.Application.Auth;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Products;
using UnivespProject.Application.Sales;
using UnivespProject.Application.Settings;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Application.Stores;

namespace UnivespProject.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<INotifier, Notifier>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IAccessRequestNotices, AccessRequestNotices>();
        services.AddScoped<IUserNotificationService, UserNotificationService>();
        services.AddScoped<IStoreEnrollment, StoreEnrollment>();
        services.AddScoped<IStoreService, StoreService>();
        services.AddScoped<IStoreAccessService, StoreAccessService>();
        services.AddScoped<ICurrentUserSettings, CurrentUserSettings>();
        services.AddScoped<ISettingsService, SettingsService>();
        services.AddScoped<ISalesImportService, SalesImportService>();
        services.AddScoped<ISaleService, SaleService>();
        services.AddScoped<ICheckoutService, CheckoutService>();
        services.AddScoped<IProductService, ProductService>();
        services.AddScoped<IProductImageService, ProductImageService>();
        services.AddScoped<ISalesComparisonService, SalesComparisonService>();
        services.AddScoped<ISalesExportService, SalesExportService>();
        services.AddScoped<ISalesForecastService, SalesForecastService>();
        services.AddScoped<IProductGroupsService, ProductGroupsService>();
        services.AddSingleton(TimeProvider.System);

        return services;
    }
}
