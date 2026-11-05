using UnivespProject.Application.DTOs.Products;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.ProductImages;

namespace UnivespProject.Tests.Application.Products;

public class ProductImageServiceTests
{
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 1, 2, 3];

    private readonly FakeProductImageStorage _storage = new();
    private readonly Notifier _notifier = new();
    private readonly ProductImageService _service;

    public ProductImageServiceTests() => _service = new ProductImageService(_notifier, _storage);

    private static ProductImageFile File(byte[] bytes, string name = "foto.png", long? length = null) =>
        new(name, length ?? bytes.Length, new MemoryStream(bytes));

    [Fact]
    public async Task Png_IsSaved_AndThePublicPathIsReturned()
    {
        var response = await _service.UploadAsync(File(Png, name: "minha foto.PNG"));

        Assert.False(_notifier.HasNotifications);
        Assert.StartsWith("/uploads/products/", response!.Url);
        Assert.EndsWith(".png", response.Url);
        Assert.Equal(Png, _storage.Files[response.Url]);
    }

    [Fact]
    public async Task TheExtensionComesFromTheContent_NotFromTheName()
    {
        byte[] jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46, 0x49, 0x46, 0, 1];

        var response = await _service.UploadAsync(File(jpeg, name: "foto.png"));

        Assert.EndsWith(".jpg", response!.Url);
    }

    [Fact]
    public async Task ARenamedFile_IsRefused()
    {
        var response = await _service.UploadAsync(File("isto nao e uma imagem"u8.ToArray(), name: "foto.png"));

        Assert.Null(response);
        var error = Assert.Single(_notifier.Notifications);
        Assert.Equal(("file", "Formato não suportado. Envie uma imagem PNG, JPEG, WebP ou GIF."), (error.Key, error.Message));
        Assert.Empty(_storage.Files);
    }

    [Fact]
    public async Task Empty_And_TooBig_AreRefused()
    {
        Assert.Null(await _service.UploadAsync(File([])));
        Assert.Null(await _service.UploadAsync(File(Png, length: ProductImageService.MaxFileSizeBytes + 1)));

        Assert.Equal(["Selecione uma imagem.", "A imagem deve ter no máximo 5 MB."],
            _notifier.Notifications.Select(n => n.Message));
        Assert.Empty(_storage.Files);
    }

    [Theory]
    [InlineData(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }, ".png")]
    [InlineData(new byte[] { 0xFF, 0xD8, 0xFF, 0xDB }, ".jpg")]
    [InlineData(new byte[] { 0x47, 0x49, 0x46, 0x38, 0x39, 0x61 }, ".gif")]
    [InlineData(new byte[] { 0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50 }, ".webp")]
    [InlineData(new byte[] { 0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x41, 0x56, 0x45 }, null)] // WAV, not WebP
    [InlineData(new byte[] { 0x25, 0x50, 0x44, 0x46 }, null)] // PDF
    public void ImageFormat_IsDetectedByItsFirstBytes(byte[] header, string? extension) =>
        Assert.Equal(extension, ImageFormat.DetectExtension(header));
}
