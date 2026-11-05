using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// The preferences of one user (one row per user, table <c>user_settings</c>).
/// A user without a row has the defaults: every option off, except the restock warnings (on).
/// </summary>
public sealed class UserSettings : BaseEntity
{
    public Guid UserId { get; private set; }

    /// <summary>Products this user saves must have an image.</summary>
    public bool RequireProductImage { get; private set; }

    /// <summary>
    /// Importing a spreadsheet registers its SKUs that aren't in the catalog yet as products.
    /// Off by default: the import only links sales to the products that already exist.
    /// </summary>
    public bool CreateProductsOnImport { get; private set; }

    /// <summary>
    /// The app warns when products reach their minimum stock and must be restocked.
    /// On by default.
    /// </summary>
    public bool NotifyRestock { get; private set; } = true;

    /// <summary>The app's color theme. Dark by default.</summary>
    public AppTheme Theme { get; private set; } = AppTheme.Dark;

    // Required by Entity Framework.
    private UserSettings() { }

    /// <summary>The defaults of <paramref name="userId"/>, not saved yet.</summary>
    public UserSettings(Guid userId)
    {
        UserId = userId;
    }

    /// <summary>
    /// Changes only the options that were given (null keeps the current value).
    /// <paramref name="theme"/> is the theme's name ("Dark" or "Light", any casing); on an
    /// invalid one nothing is changed and the error is a notification.
    /// </summary>
    public void Update(
        bool? requireProductImage, bool? createProductsOnImport, string? theme = null, bool? notifyRestock = null)
    {
        ClearNotifications();

        AppTheme? parsedTheme = null;
        if (theme is not null)
        {
            parsedTheme = ParseTheme(theme);
            if (parsedTheme is null)
            {
                AddNotification(Fields.Theme, "Tema inválido. Use Dark (escuro) ou Light (claro).");
                return;
            }
        }

        RequireProductImage = requireProductImage ?? RequireProductImage;
        CreateProductsOnImport = createProductsOnImport ?? CreateProductsOnImport;
        Theme = parsedTheme ?? Theme;
        NotifyRestock = notifyRestock ?? NotifyRestock;
    }

    /// <summary>Only the names: numbers ("1") are not accepted.</summary>
    private static AppTheme? ParseTheme(string theme) => theme.Trim().ToUpperInvariant() switch
    {
        "DARK" => AppTheme.Dark,
        "LIGHT" => AppTheme.Light,
        _ => null
    };

    /// <summary>Notification keys: the field names of the API's settings JSON.</summary>
    public static class Fields
    {
        public const string RequireProductImage = "requireProductImage";
        public const string CreateProductsOnImport = "createProductsOnImport";
        public const string Theme = "theme";
        public const string NotifyRestock = "notifyRestock";
    }
}
