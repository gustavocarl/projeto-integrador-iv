namespace UnivespProject.Application.Abstractions;

/// <summary>
/// Where uploaded product photos are kept. Each stored image has a public path (e.g.
/// "/uploads/products/3f2a….png") that the API serves and that goes into <c>Product.ImageUrl</c>.
/// </summary>
public interface IProductImageStorage
{
    /// <summary>Saves the image under a new unique name and returns its public path.</summary>
    /// <param name="extension">File extension with the dot, chosen from the detected format (".png").</param>
    Task<string> SaveAsync(ReadOnlyMemory<byte> content, string extension, CancellationToken cancellationToken = default);

    /// <summary>True when <paramref name="imageUrl"/> is a public path of this storage (not an external link).</summary>
    bool IsStored(string? imageUrl);

    /// <summary>True when the stored image exists.</summary>
    bool Exists(string imageUrl);

    /// <summary>Removes a stored image. Does nothing for external links or missing files.</summary>
    Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken = default);
}
