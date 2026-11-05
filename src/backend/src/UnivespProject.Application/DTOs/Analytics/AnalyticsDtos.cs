namespace UnivespProject.Application.DTOs.Analytics;

/// <summary>A month left out of the analysis and why.</summary>
/// <param name="Month">"2026-10".</param>
/// <param name="Label">"outubro/2026".</param>
public sealed record IgnoredMonth(string Month, string Label, string Reason);

/// <summary>Units and revenue of a month (sold, or predicted).</summary>
public sealed record MonthTotal(string Month, string Label, int Quantity, decimal Revenue);

/// <summary>A product's prediction for the coming months.</summary>
/// <param name="Price">Average price in the last month it was sold: the predicted revenue uses it.</param>
/// <param name="Quantities">Predicted units per month, in the order of <see cref="SalesForecastResponse.Months"/>.</param>
/// <param name="Quantity">Total of <paramref name="Quantities"/>.</param>
/// <param name="Stock">Catalog products only (null for sales without a registered product).</param>
/// <param name="SuggestedPurchase">
/// Units to buy so the stock covers the forecast and stays at the minimum: forecast + minimum - stock (never below 0).
/// Catalog products only.
/// </param>
public sealed record ProductForecast(
    string Key,
    string Name,
    string? Sku,
    Guid? ProductId,
    decimal Price,
    IReadOnlyList<int> Quantities,
    int Quantity,
    decimal Revenue,
    int? Stock,
    int? MinimumStock,
    int? SuggestedPurchase);

/// <summary>
/// How the model did on a month it already knows: trained without the last month of the history,
/// it predicted that month, compared with what was sold. Error = sum of |predicted - sold| / units sold.
/// </summary>
/// <param name="BaselineQuantity">The simple guess: each product's average of the previous months.</param>
public sealed record ForecastValidation(
    string Month,
    string Label,
    int ActualQuantity,
    int PredictedQuantity,
    int BaselineQuantity,
    double ModelError,
    double BaselineError);

/// <summary>Sales predicted for the coming months, per product (ML.NET Poisson regression).</summary>
/// <param name="History">Months the model learned from, oldest first.</param>
/// <param name="Months">The predicted months, oldest first.</param>
/// <param name="Products">Highest predicted revenue first.</param>
/// <param name="Validation">Null with only the minimum history (nothing left to test on) or no sales in the tested month.</param>
public sealed record SalesForecastResponse(
    IReadOnlyList<MonthTotal> History,
    IReadOnlyList<MonthTotal> Months,
    IReadOnlyList<ProductForecast> Products,
    ForecastValidation? Validation,
    IReadOnlyList<IgnoredMonth> IgnoredMonths);

/// <summary>A product inside a group, with the features used to group it.</summary>
/// <param name="MonthlyQuantity">Average units per month of the history (months without sales count as 0).</param>
/// <param name="Regularity">Share of the months with sales, 0 to 1.</param>
public sealed record GroupedProduct(
    string Key,
    string Name,
    string? Sku,
    Guid? ProductId,
    double MonthlyQuantity,
    decimal AveragePrice,
    double Regularity,
    int Quantity,
    decimal Revenue);

/// <summary>A group of products that sell alike (k-means).</summary>
/// <param name="Number">1 = the group with the highest revenue.</param>
/// <param name="MonthlyQuantity">Average of its products.</param>
/// <param name="RevenueShare">Share of the revenue of every product, 0 to 1.</param>
/// <param name="Products">Highest revenue first.</param>
public sealed record ProductGroup(
    int Number,
    string Name,
    string Description,
    double MonthlyQuantity,
    decimal AveragePrice,
    double Regularity,
    int Quantity,
    decimal Revenue,
    double RevenueShare,
    IReadOnlyList<GroupedProduct> Products);

/// <summary>How well a number of groups separates the products: silhouette from -1 to 1 (higher = better).</summary>
public sealed record GroupingQuality(int Groups, double Silhouette);

/// <summary>The products split into groups by how they sell (volume, price and regularity).</summary>
/// <param name="Automatic">True when the number of groups was chosen by the best silhouette.</param>
/// <param name="Candidates">Every number of groups tried, to show why it was chosen.</param>
/// <param name="Months">Months the features were computed from, oldest first.</param>
public sealed record ProductGroupsResponse(
    int Groups,
    bool Automatic,
    double Silhouette,
    IReadOnlyList<GroupingQuality> Candidates,
    IReadOnlyList<ProductGroup> Clusters,
    IReadOnlyList<MonthTotal> Months,
    IReadOnlyList<IgnoredMonth> IgnoredMonths);
