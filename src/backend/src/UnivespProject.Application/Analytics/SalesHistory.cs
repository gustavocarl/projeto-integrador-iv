using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Analytics;
using UnivespProject.Application.Sales;

namespace UnivespProject.Application.Analytics;

/// <summary>A product's sales in each month of a <see cref="SalesHistory"/>.</summary>
internal sealed class ProductHistory
{
    public required string Key { get; init; }

    /// <summary>The most sold spelling of the name.</summary>
    public required string Name { get; init; }

    public required string? Sku { get; init; }

    /// <summary>The catalog product most of its sales are linked to; null when none.</summary>
    public required Guid? ProductId { get; init; }

    /// <summary>Units per month, in the order of <see cref="SalesHistory.Months"/> (0 = no sales).</summary>
    public required IReadOnlyList<int> Quantities { get; init; }

    public required IReadOnlyList<decimal> Revenues { get; init; }

    public int Quantity => Quantities.Sum();
    public decimal Revenue => Revenues.Sum();
    public double MonthlyQuantity => (double)Quantity / Quantities.Count;
    public decimal AveragePrice => Quantity == 0 ? 0m : Math.Round(Revenue / Quantity, 2);

    /// <summary>Share of the months with sales, 0 to 1.</summary>
    public double Regularity => (double)Quantities.Count(q => q > 0) / Quantities.Count;

    /// <summary>Average price in the last month it was sold (prices change over time).</summary>
    public decimal LatestPrice
    {
        get
        {
            for (var i = Quantities.Count - 1; i >= 0; i--)
            {
                if (Quantities[i] > 0)
                    return Math.Round(Revenues[i] / Quantities[i], 2);
            }

            return 0m;
        }
    }
}

/// <summary>
/// The monthly sales the analytics learn from. Only complete months that were really recorded count:
/// the current month is still going on, and a month with sales on less than half of its days
/// (a few sales typed in, a partial spreadsheet) would look like a month of poor sales.
/// Months without any sale are unknown, not zero (the store may not have imported them).
/// </summary>
internal sealed class SalesHistory
{
    /// <summary>Share of the days of a month that must have sales for it to count.</summary>
    public const double MinimumCoverage = 0.5;

    private SalesHistory(SalesMonth currentMonth, IReadOnlyList<SalesMonth> months,
        IReadOnlyList<IgnoredMonth> ignored, IReadOnlyList<ProductHistory> products)
    {
        CurrentMonth = currentMonth;
        Months = months;
        Ignored = ignored;
        Products = products;
    }

    public SalesMonth CurrentMonth { get; }

    /// <summary>The months used, oldest first.</summary>
    public IReadOnlyList<SalesMonth> Months { get; }

    /// <summary>Months with sales that were left out, oldest first.</summary>
    public IReadOnlyList<IgnoredMonth> Ignored { get; }

    /// <summary>Products sold in at least one of the <see cref="Months"/>.</summary>
    public IReadOnlyList<ProductHistory> Products { get; }

    /// <summary>Units and revenue of each month of the history, oldest first.</summary>
    public IReadOnlyList<MonthTotal> Totals() =>
        Months.Select((m, i) => new MonthTotal(m.ToString(), m.Label,
                Products.Sum(p => p.Quantities[i]), Products.Sum(p => p.Revenues[i])))
            .ToList();

    /// <summary>The same history without its last month (to test a model on a month it did not see).</summary>
    public SalesHistory WithoutLastMonth() => new(CurrentMonth, Months.Take(Months.Count - 1).ToList(), Ignored,
        Products
            .Select(p => new ProductHistory
            {
                Key = p.Key, Name = p.Name, Sku = p.Sku, ProductId = p.ProductId,
                Quantities = p.Quantities.Take(Months.Count - 1).ToList(),
                Revenues = p.Revenues.Take(Months.Count - 1).ToList(),
            })
            .Where(p => p.Quantity > 0)
            .ToList());

    public static SalesHistory Build(
        IReadOnlyList<ProductMonthTotals> totals, IReadOnlyList<MonthActivity> activity, DateOnly today)
    {
        var current = SalesMonth.Of(today);
        var months = new List<SalesMonth>();
        var ignored = new List<IgnoredMonth>();

        foreach (var item in activity.OrderBy(a => a.Year).ThenBy(a => a.Month))
        {
            var month = new SalesMonth(item.Year, item.Month);
            if (month.Index >= current.Index)
                ignored.Add(Ignore(month, "Mês em andamento: ainda não terminou."));
            else if (item.DaysWithSales < Math.Ceiling(month.Days * MinimumCoverage))
                ignored.Add(Ignore(month,
                    $"Vendas em só {item.DaysWithSales} de {month.Days} dias: parece um mês registrado pela metade."));
            else
                months.Add(month);
        }

        var position = months.Select((m, i) => (m, i)).ToDictionary(x => x.m, x => x.i);
        var products = totals
            .Where(t => position.ContainsKey(new SalesMonth(t.Year, t.Month)))
            .GroupBy(t => t.Key)
            .Select(g =>
            {
                var quantities = new int[months.Count];
                var revenues = new decimal[months.Count];
                foreach (var t in g)
                {
                    var i = position[new SalesMonth(t.Year, t.Month)];
                    quantities[i] += t.Quantity;
                    revenues[i] += t.Revenue;
                }

                var main = g.GroupBy(t => (t.ProductName, t.Sku))
                    .OrderByDescending(s => s.Sum(t => t.Quantity))
                    .ThenBy(s => s.Key.ProductName, StringComparer.Ordinal)
                    .First().Key;
                var productId = g.Where(t => t.ProductId is not null)
                    .GroupBy(t => t.ProductId)
                    .OrderByDescending(s => s.Sum(t => t.Quantity))
                    .Select(s => s.Key)
                    .FirstOrDefault();

                return new ProductHistory
                {
                    Key = g.Key, Name = main.ProductName, Sku = main.Sku, ProductId = productId,
                    Quantities = quantities, Revenues = revenues,
                };
            })
            .Where(p => p.Quantity > 0)
            .OrderBy(p => p.Key, StringComparer.Ordinal)
            .ToList();

        return new SalesHistory(current, months, ignored, products);
    }

    private static IgnoredMonth Ignore(SalesMonth month, string reason) => new(month.ToString(), month.Label, reason);
}
