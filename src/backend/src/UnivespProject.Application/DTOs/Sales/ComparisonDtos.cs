namespace UnivespProject.Application.DTOs.Sales;

/// <summary>A month with sales, to choose from.</summary>
/// <param name="Month">"2026-01": the value sent to the comparison.</param>
/// <param name="Label">"janeiro/2026".</param>
public sealed record SalesMonthItem(string Month, string Label, int Sales, int Quantity, decimal Revenue);

public sealed record PeriodTotals(int Sales, int Quantity, decimal Revenue)
{
    public static readonly PeriodTotals Zero = new(0, 0, 0m);
}

/// <summary>The totals of one of the compared months.</summary>
/// <param name="Days">Days in the month.</param>
/// <param name="ElapsedDays">Days already gone by: less than <see cref="Days"/> for the current month.</param>
/// <param name="Profit">Only the sales whose cost is known (checkout sales of products with cost price).</param>
public sealed record MonthSummary(
    string Month,
    string Label,
    int Days,
    int ElapsedDays,
    int Sales,
    int Quantity,
    decimal Revenue,
    ProfitSummary Profit);

/// <summary>A channel, marketplace or product in both months (zeros where it had no sales).</summary>
/// <param name="Key">Same keys as the batch detail: "InPerson"/"Online", a marketplace id or "none", the product key.</param>
/// <param name="Sku">Products only.</param>
public sealed record ComparisonItem(string Key, string Name, string? Sku, PeriodTotals Base, PeriodTotals Target);

/// <summary>A day of the month in both months; null on the side whose month is shorter (no 30 February).</summary>
public sealed record DayComparisonItem(int Day, PeriodTotals? Base, PeriodTotals? Target);

/// <summary>
/// Two months side by side, over every sale of every batch. Growth = (target - base) / base.
/// </summary>
/// <param name="ByMarketplace">Online sales only, per marketplace (including "Fora de marketplace").</param>
/// <param name="Products">Every product sold in either month, highest target revenue first.</param>
/// <param name="ByDay">Day 1 up to the longer month's last day.</param>
public sealed record MonthComparisonResponse(
    MonthSummary Base,
    MonthSummary Target,
    IReadOnlyList<ComparisonItem> ByChannel,
    IReadOnlyList<ComparisonItem> ByMarketplace,
    IReadOnlyList<ComparisonItem> Products,
    IReadOnlyList<DayComparisonItem> ByDay);
