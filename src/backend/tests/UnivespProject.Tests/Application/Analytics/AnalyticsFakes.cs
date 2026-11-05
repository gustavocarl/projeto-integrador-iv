using UnivespProject.Application.Abstractions;
using UnivespProject.Tests.Application.Sales;

namespace UnivespProject.Tests.Application.Analytics;

/// <summary>Predicts with a rule given by the test and records what it was asked.</summary>
internal sealed class FakeSalesForecaster : ISalesForecaster
{
    public Func<DemandQuery, IReadOnlyList<DemandObservation>, double> Rule { get; set; } = (_, _) => 0;

    public List<(IReadOnlyList<DemandObservation> History, IReadOnlyList<DemandQuery> Queries)> Calls { get; } = [];

    public IReadOnlyList<double> Forecast(IReadOnlyList<DemandObservation> history, IReadOnlyList<DemandQuery> queries)
    {
        Calls.Add((history, queries));
        return queries.Select(q => Rule(q, history)).ToList();
    }
}

/// <summary>Groups with a rule given by the test (by default: first feature below 0 = group 0).</summary>
internal sealed class FakeProductClusterer : IProductClusterer
{
    public Func<IReadOnlyList<double[]>, int, IReadOnlyList<int>> Rule { get; set; } =
        (points, _) => points.Select(p => p[0] < 0 ? 0 : 1).ToList();

    public List<int> Requested { get; } = [];

    public IReadOnlyList<int> Cluster(IReadOnlyList<double[]> points, int groups)
    {
        Requested.Add(groups);
        return Rule(points, groups);
    }
}

/// <summary>Builds the monthly history of a <see cref="FakeSalesReportRepository"/>.</summary>
internal static class HistoryBuilder
{
    /// <summary>A recorded month (sales on every day) with these product totals.</summary>
    public static void Month(this FakeSalesReportRepository reports, int year, int month,
        params (string Name, string? Sku, int Quantity, decimal Revenue, Guid? ProductId)[] products)
    {
        reports.MonthlyTotals ??= [];
        reports.Activity ??= [];
        reports.Activity.Add(new MonthActivity(year, month, DateTime.DaysInMonth(year, month)));
        reports.MonthlyTotals.AddRange(products.Select(p =>
            new ProductMonthTotals(year, month, p.Name, p.Sku, p.ProductId, p.Quantity, p.Revenue)));
    }
}
