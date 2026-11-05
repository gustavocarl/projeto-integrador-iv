namespace UnivespProject.Domain.Enums;

/// <summary>
/// Parts of the app an admin can give to a member (flags: a member can have several).
/// Sent as a list of names ("Products", "Checkout", ...). Admins always have all of them.
/// </summary>
[Flags]
public enum StoreArea
{
    None = 0,

    /// <summary>Product registration (stock, prices, images).</summary>
    Products = 1,

    /// <summary>The checkout ("Vender").</summary>
    Checkout = 2,

    /// <summary>Sales batches: spreadsheet imports, typed sales, batch details.</summary>
    Imports = 4,

    /// <summary>Generated sales spreadsheets.</summary>
    Exports = 8,

    /// <summary>Month comparison.</summary>
    Comparison = 16,

    /// <summary>Forecast and product groups (ML.NET).</summary>
    Analytics = 32,

    All = Products | Checkout | Imports | Exports | Comparison | Analytics
}
