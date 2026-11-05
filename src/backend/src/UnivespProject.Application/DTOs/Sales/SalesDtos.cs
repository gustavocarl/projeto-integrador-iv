namespace UnivespProject.Application.DTOs.Sales;

/// <summary>An uploaded file, independent of ASP.NET's IFormFile.</summary>
public sealed record SpreadsheetFile(string FileName, long Length, Stream Content);

/// <param name="FileName">The spreadsheet's file name, or the name of a manual batch.</param>
/// <param name="Source">"Spreadsheet", "Manual" or "Store" (the month's checkout batch).</param>
/// <param name="CreatedProducts">
/// Only in the response of a spreadsheet import: how many products were registered from the
/// spreadsheet's new SKUs. Null everywhere else.
/// </param>
public sealed record SalesImportResponse(
    Guid Id,
    string FileName,
    string Source,
    DateTime ImportedAt,
    string ImportedBy,
    int SalesCount,
    int TotalQuantity,
    decimal TotalRevenue,
    DateOnly? PeriodStart,
    DateOnly? PeriodEnd,
    int? CreatedProducts = null);

/// <summary>
/// Shown before a batch is removed, so the user knows what goes away: its sales leave the reports
/// and the month comparison; linked products stay in the catalog; checkout units go back to stock.
/// </summary>
/// <param name="LinkedProducts">Registered products the batch's sales are linked to.</param>
/// <param name="StockReturned">Units sold at the checkout that go back to stock.</param>
public sealed record SalesImportDeletionImpactResponse(
    Guid ImportId,
    string FileName,
    int SalesCount,
    decimal TotalRevenue,
    int LinkedProducts,
    int StockReturned);

/// <param name="Key">Stable identifier ("InPerson", "Online", a marketplace id or "none").</param>
/// <param name="Name">Label to display.</param>
public sealed record BreakdownItem(string Key, string Name, int Sales, int Quantity, decimal Revenue);

public sealed record DailyItem(DateOnly Date, int Sales, int Quantity, decimal Revenue);

/// <param name="Key">Normalized SKU (or name, when there is no SKU): the product's identity.</param>
/// <param name="RevenueShare">Fraction of the import's revenue (0.235 = 23,5%).</param>
/// <param name="AbcClass">"A", "B" or "C" (see <see cref="UnivespProject.Application.Sales.AbcCurve"/>).</param>
/// <param name="Recommendation">"Prioritize", "Keep" or "ReviewRemoval" (see <see cref="UnivespProject.Application.Sales.StockRecommendation"/>).</param>
public sealed record ProductItem(
    string Key,
    string Name,
    string? Sku,
    int Sales,
    int Quantity,
    decimal Revenue,
    decimal RevenueShare,
    string AbcClass,
    string Recommendation,
    DateOnly LastSaleDate);

/// <param name="ByDay">Every day of the period, including days without sales (zeros).</param>
/// <param name="Products">Sorted by revenue, highest first.</param>
public sealed record SalesImportDetailResponse(
    SalesImportResponse Import,
    IReadOnlyList<BreakdownItem> ByChannel,
    IReadOnlyList<BreakdownItem> ByMarketplace,
    IReadOnlyList<DailyItem> ByDay,
    IReadOnlyList<ProductItem> Products,
    ProfitSummary Profit);

/// <summary>
/// A sale typed in by the user. Send <see cref="ImportId"/> to add it to an existing batch,
/// or <see cref="ImportName"/> to create a new manual batch with it.
/// </summary>
/// <param name="Channel">"InPerson"/"Online" (also accepts "Presencial", "Loja física", "Loja virtual").</param>
/// <param name="Marketplace">Online only; empty = outside a marketplace. Unknown names are created.</param>
public sealed record ManualSaleRequest(
    Guid? ImportId,
    string? ImportName,
    DateOnly? Date,
    string? ProductName,
    string? Sku,
    int? Quantity,
    decimal? UnitPrice,
    string? Channel,
    string? Marketplace);

/// <param name="RowNumber">Spreadsheet row; null for sales typed in or made at the checkout.</param>
/// <param name="Channel">"InPerson" or "Online".</param>
/// <param name="ProductId">Registered product: sold at the checkout, or with the same SKU.</param>
/// <param name="IsCheckout">Sold at the checkout (took units from stock).</param>
/// <param name="TotalCost">Cost of the sale, when the product had a cost price.</param>
public sealed record SaleResponse(
    Guid Id,
    DateOnly Date,
    string ProductName,
    string? Sku,
    int Quantity,
    decimal UnitPrice,
    decimal TotalPrice,
    string Channel,
    string ChannelName,
    string? Marketplace,
    int? RowNumber,
    DateTime CreatedAt,
    string CreatedBy,
    Guid? ProductId,
    decimal? TotalCost,
    bool IsCheckout);

/// <summary>The sale created and its batch with the updated totals.</summary>
public sealed record ManualSaleResponse(SalesImportResponse Import, SaleResponse Sale);

public sealed record PagedResponse<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount);

/// <param name="UnitPrice">Optional: the product's sale price is used when empty (a discount can be given here).</param>
public sealed record CheckoutItemRequest(Guid? ProductId, int? Quantity, decimal? UnitPrice);

/// <summary>
/// A sale at the store: one or more catalog products, all on the same date and channel.
/// The sales go into the month's batch ("Vendas - outubro/2026"), created automatically.
/// </summary>
/// <param name="Date">Optional: today when empty.</param>
/// <param name="Channel">"InPerson"/"Online" (also accepts "Presencial", "Loja física", "Loja virtual").</param>
/// <param name="Marketplace">Online only; empty = outside a marketplace. Unknown names are created.</param>
public sealed record CheckoutRequest(
    DateOnly? Date,
    string? Channel,
    string? Marketplace,
    IReadOnlyList<CheckoutItemRequest>? Items);

/// <param name="Cost">Cost of the items whose product has a cost price; null when none has.</param>
/// <param name="Profit">Revenue minus cost of the items with cost; null when none has.</param>
public sealed record CheckoutResponse(
    SalesImportResponse Import,
    IReadOnlyList<SaleResponse> Sales,
    decimal Total,
    decimal? Cost,
    decimal? Profit);

/// <summary>Profit of the sales whose cost is known (checkout sales of products with cost price).</summary>
/// <param name="SalesWithCost">How many sales the numbers cover; 0 = no profit to show.</param>
/// <param name="Revenue">Revenue of those sales only.</param>
/// <param name="Margin">Profit / revenue (0.35 = 35%); null when there is no revenue.</param>
public sealed record ProfitSummary(int SalesWithCost, decimal Revenue, decimal Cost, decimal Profit, decimal? Margin);

/// <summary>Period of a new sales spreadsheet: "2026-11-01" to "2026-11-07" (both included).</summary>
/// <param name="Platform">The app's operating system (windows, macos, linux, android, ios): the file
/// uses its default spreadsheet font. Empty = Calibri (Excel).</param>
public sealed record CreateSalesExportRequest(string? Start, string? End, string? Platform = null);

/// <summary>A generated sales spreadsheet (listed on the spreadsheets screen; the file is downloaded apart).</summary>
/// <param name="PeriodLabel">"05/11/2026", "novembro/2026" or "02/11/2026 a 08/11/2026".</param>
/// <param name="CreatedBy">E-mail of who generated it.</param>
public sealed record SalesExportResponse(
    Guid Id,
    string FileName,
    DateOnly PeriodStart,
    DateOnly PeriodEnd,
    string PeriodLabel,
    int SalesCount,
    decimal TotalRevenue,
    DateTime CreatedAt,
    string CreatedBy);
