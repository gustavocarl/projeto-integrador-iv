using UnivespProject.Infrastructure.Storage;

namespace UnivespProject.Tests.Infrastructure;

public sealed class LocalProductImageStorageTests : IDisposable
{
    // <temp>/univesp-images-…/products is the storage; files around it must never be touched.
    private readonly string _base = Path.Combine(Path.GetTempPath(), "univesp-images-" + Guid.NewGuid().ToString("N"));
    private readonly string _root;
    private readonly LocalProductImageStorage _storage;

    public LocalProductImageStorageTests()
    {
        _root = Path.Combine(_base, "products");
        _storage = new LocalProductImageStorage(_root, "/uploads/products");
    }

    public void Dispose() => Directory.Delete(_base, recursive: true);

    [Fact]
    public async Task Save_WritesAFileWithANewName_InTheFolder()
    {
        var path = await _storage.SaveAsync(new byte[] { 1, 2, 3 }, ".png");

        Assert.Matches("^/uploads/products/[0-9a-f]{32}\\.png$", path);
        var file = Assert.Single(Directory.GetFiles(_root));
        Assert.Equal([1, 2, 3], await File.ReadAllBytesAsync(file));
        Assert.True(_storage.IsStored(path));
        Assert.True(_storage.Exists(path));
    }

    [Fact]
    public async Task Delete_RemovesTheFile()
    {
        var path = await _storage.SaveAsync(new byte[] { 1 }, ".png");

        await _storage.DeleteAsync(path);

        Assert.False(_storage.Exists(path));
        Assert.Empty(Directory.GetFiles(_root));
    }

    [Theory]
    [InlineData("https://exemplo.com/uploads/products/a.png")]
    [InlineData("/uploads/products/")]
    [InlineData("/uploads/products/../segredo.txt")]
    [InlineData("/uploads/products/sub/a.png")]
    [InlineData("/outra/pasta/a.png")]
    public async Task OnlyFilesOfTheFolder_AreStored_AndOthersAreNeverDeleted(string imageUrl)
    {
        var secret = Path.Combine(_base, "segredo.txt");
        await File.WriteAllTextAsync(secret, "não apagar");
        Directory.CreateDirectory(Path.Combine(_root, "sub"));
        var nested = Path.Combine(_root, "sub", "a.png");
        await File.WriteAllTextAsync(nested, "não apagar");

        await _storage.DeleteAsync(imageUrl);

        Assert.False(_storage.IsStored(imageUrl));
        Assert.True(File.Exists(secret));
        Assert.True(File.Exists(nested));
    }
}
