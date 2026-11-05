using UnivespProject.Application.Abstractions;

namespace UnivespProject.Infrastructure.Storage;

/// <summary>
/// Keeps product photos as files in a local folder, each under a new GUID name
/// (no user-supplied name ever reaches the disk).
/// </summary>
public sealed class LocalProductImageStorage : IProductImageStorage
{
    private readonly string _root;
    private readonly string _prefix;

    /// <param name="rootPath">Absolute folder of the images (created if missing).</param>
    /// <param name="requestPath">URL path the folder is served at, e.g. "/uploads/products".</param>
    public LocalProductImageStorage(string rootPath, string requestPath)
    {
        _root = Path.GetFullPath(rootPath);
        _prefix = requestPath.TrimEnd('/') + "/";
        Directory.CreateDirectory(_root);
    }

    public string RootPath => _root;

    public async Task<string> SaveAsync(ReadOnlyMemory<byte> content, string extension, CancellationToken cancellationToken = default)
    {
        var fileName = $"{Guid.NewGuid():N}{extension}";
        await File.WriteAllBytesAsync(Path.Combine(_root, fileName), content, cancellationToken);
        return _prefix + fileName;
    }

    public bool IsStored(string? imageUrl) => imageUrl is not null && FullPathOf(imageUrl) is not null;

    public bool Exists(string imageUrl) => FullPathOf(imageUrl) is { } path && File.Exists(path);

    public Task DeleteAsync(string? imageUrl, CancellationToken cancellationToken = default)
    {
        if (imageUrl is not null && FullPathOf(imageUrl) is { } path && File.Exists(path))
            File.Delete(path);

        return Task.CompletedTask;
    }

    /// <summary>
    /// The file behind a public path, or null for anything that isn't exactly one file of this folder
    /// (external links, sub-folders, "..").
    /// </summary>
    private string? FullPathOf(string imageUrl)
    {
        if (!imageUrl.StartsWith(_prefix, StringComparison.Ordinal))
            return null;

        var name = imageUrl[_prefix.Length..];
        if (name.Length == 0 || name != Path.GetFileName(name) || name.Contains(".."))
            return null;

        return Path.Combine(_root, name);
    }
}
