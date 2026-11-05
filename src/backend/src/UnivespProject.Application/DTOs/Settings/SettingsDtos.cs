namespace UnivespProject.Application.DTOs.Settings;

/// <param name="RequireProductImage">Products this user saves must have an image.</param>
/// <param name="CreateProductsOnImport">Importing a spreadsheet registers its unknown SKUs as products.</param>
/// <param name="Theme">The app's color theme: "Dark" (default) or "Light".</param>
/// <param name="NotifyRestock">The app warns about products that must be restocked (default on).</param>
public sealed record UserSettingsResponse(
    bool RequireProductImage, bool CreateProductsOnImport, string Theme, bool NotifyRestock = true);

/// <summary>
/// Changes the logged-in user's settings. Only the fields sent are changed (null keeps the value);
/// at least one is required. <c>Theme</c>: "Dark" or "Light" (error key <c>theme</c>).
/// </summary>
public sealed record UpdateSettingsRequest(
    bool? RequireProductImage = null,
    bool? CreateProductsOnImport = null,
    string? Theme = null,
    bool? NotifyRestock = null);
