using UnivespProject.Application.Abstractions;

namespace UnivespProject.Tests.Application.Products;

/// <summary>Image storage in memory, with the same public paths as the real one.</summary>
internal sealed class FakeProductImageStorage : IProductImageStorage
{
    public const string Prefix = "/uploads/products/";

    public Dictionary<string, byte[]> Files { get; } = [];

    public Task<string> SaveAsync(ReadOnlyMemory<byte> content, string extension, CancellationToken cancellationToken = default)
    {
        var path = $"{Prefix}{Guid.NewGuid():N}{extension}";
        Files[path] = content.ToArray();
        return Task.FromResult(path);
    }

    public bool IsStored(string? imageUrl) => imageUrl?.StartsWith(Prefix, StringComparison.Ordinal) == true;

    public bool Exists(string imageUrl) => Files.ContainsKey(imageUrl);

    public Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken = default)
    {
        if (imageUrl is not null)
            Files.Remove(imageUrl);
        return Task.CompletedTask;
    }

    /// <summary>Puts an "uploaded" file in place and returns its path.</summary>
    public string Add(string name = "foto.png")
    {
        var path = Prefix + name;
        Files[path] = [1, 2, 3];
        return path;
    }
}
