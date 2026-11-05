using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Products;
using UnivespProject.Application.Notifications;

namespace UnivespProject.Application.ProductImages;

internal sealed class ProductImageService(INotifier notifier, IProductImageStorage storage)
    : BaseService(notifier), IProductImageService
{
    public const string FileKey = "file";
    public const long MaxFileSizeBytes = 5 * 1024 * 1024;

    public async Task<ProductImageResponse?> UploadAsync(ProductImageFile file, CancellationToken cancellationToken = default)
    {
        if (file.Length <= 0)
        {
            Notify(FileKey, "Selecione uma imagem.");
            return null;
        }

        if (file.Length > MaxFileSizeBytes)
        {
            Notify(FileKey, $"A imagem deve ter no máximo {MaxFileSizeBytes / (1024 * 1024)} MB.");
            return null;
        }

        // At most 5 MB: read it whole, then check the real format by its first bytes.
        using var buffer = new MemoryStream((int)file.Length);
        await file.Content.CopyToAsync(buffer, cancellationToken);
        var content = buffer.GetBuffer().AsMemory(0, (int)buffer.Length);

        if (ImageFormat.DetectExtension(content.Span[..Math.Min(content.Length, ImageFormat.HeaderLength)]) is not { } extension)
        {
            Notify(FileKey, "Formato não suportado. Envie uma imagem PNG, JPEG, WebP ou GIF.");
            return null;
        }

        return new ProductImageResponse(await storage.SaveAsync(content, extension, cancellationToken));
    }
}
