using Microsoft.Extensions.FileProviders;
using Microsoft.Net.Http.Headers;
using UnivespProject.Infrastructure.Storage;

namespace UnivespProject.Api.Extensions;

public static class ProductImageFilesExtensions
{
    /// <summary>
    /// Serves the uploaded product photos (e.g. GET /uploads/products/3f2a….png). Public, like any
    /// product photo on a store page: an &lt;img&gt; can't send the login token.
    /// Call after UseCors, so the web app can load them.
    /// </summary>
    public static WebApplication UseProductImageFiles(this WebApplication app)
    {
        var storage = app.Services.GetRequiredService<LocalProductImageStorage>();
        var options = app.Configuration.GetSection(ProductImageStorageOptions.SectionName).Get<ProductImageStorageOptions>()
                      ?? new ProductImageStorageOptions();

        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = new PhysicalFileProvider(storage.RootPath),
            RequestPath = options.RequestPath.TrimEnd('/'),
            OnPrepareResponse = context =>
            {
                var headers = context.Context.Response.Headers;
                // Names are new GUIDs: a file never changes, so browsers may keep it.
                headers[HeaderNames.CacheControl] = "public,max-age=31536000,immutable";
                headers[HeaderNames.XContentTypeOptions] = "nosniff";
            },
        });
        return app;
    }
}
