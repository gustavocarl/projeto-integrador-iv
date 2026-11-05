namespace UnivespProject.Infrastructure.Storage;

/// <summary>Configuration section "ProductImages".</summary>
public sealed class ProductImageStorageOptions
{
    public const string SectionName = "ProductImages";

    /// <summary>
    /// Folder of the uploaded photos. A relative path is resolved against the API's content root
    /// (the <c>UnivespProject.Api</c> project folder when running with <c>dotnet run</c>).
    /// </summary>
    public string Directory { get; set; } = "uploads/products";

    /// <summary>URL path the API serves the folder at; stored image paths start with it.</summary>
    public string RequestPath { get; set; } = "/uploads/products";
}
