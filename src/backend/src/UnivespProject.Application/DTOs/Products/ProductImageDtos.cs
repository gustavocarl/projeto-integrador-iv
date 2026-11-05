namespace UnivespProject.Application.DTOs.Products;

/// <summary>An uploaded image file (multipart field <c>file</c>).</summary>
public sealed record ProductImageFile(string FileName, long Length, Stream Content);

/// <param name="Url">Public path of the saved image, to send as the product's <c>imageUrl</c>.</param>
public sealed record ProductImageResponse(string Url);
