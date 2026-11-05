using UnivespProject.Application.DTOs.Products;

namespace UnivespProject.Application.ProductImages;

/// <summary>
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface IProductImageService
{
    /// <summary>
    /// Checks and saves an uploaded photo. The returned path is sent later as the product's
    /// <c>imageUrl</c>. Error key: <c>file</c>.
    /// </summary>
    Task<ProductImageResponse?> UploadAsync(ProductImageFile file, CancellationToken cancellationToken = default);
}
