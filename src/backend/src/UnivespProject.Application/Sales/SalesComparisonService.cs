using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;

namespace UnivespProject.Application.Sales;

internal sealed class SalesComparisonService(
    INotifier notifier,
    ISalesReportRepository reports,
    TimeProvider timeProvider) : BaseService(notifier), ISalesComparisonService
{
    /// <summary>Error keys: the query parameters.</summary>
    public static class Fields
    {
        public const string Base = "base";
        public const string Target = "target";
    }

    public async Task<IReadOnlyList<SalesMonthItem>> ListMonthsAsync(CancellationToken cancellationToken = default) =>
        (await reports.GetTotalsByMonthAsync(cancellationToken))
            .OrderByDescending(t => t.Year)
            .ThenByDescending(t => t.Month)
            .Select(t =>
            {
                var month = new SalesMonth(t.Year, t.Month);
                return new SalesMonthItem(month.ToString(), month.Label, t.Sales, t.Quantity, t.Revenue);
            })
            .ToList();

    public async Task<MonthComparisonResponse?> CompareAsync(
        string? baseMonth, string? targetMonth, CancellationToken cancellationToken = default)
    {
        var first = ParseMonth(Fields.Base, baseMonth, "Escolha o mês base.");
        var second = ParseMonth(Fields.Target, targetMonth, "Escolha o mês a comparar.");
        if (first is not { } @base || second is not { } target)
            return null;

        if (@base == target)
        {
            Notify(Fields.Target, "Escolha um mês diferente do mês base.");
            return null;
        }

        var months = (await reports.GetTotalsByMonthAsync(cancellationToken))
            .ToDictionary(t => new SalesMonth(t.Year, t.Month));
        foreach (var (key, month) in new[] { (Fields.Base, @base), (Fields.Target, target) })
        {
            if (!months.ContainsKey(month))
                Notify(key, $"Não há vendas em {month.Label}.");
        }

        if (HasNotifications)
            return null;

        var baseSummary = await SummarizeAsync(@base, months[@base], cancellationToken);
        var targetSummary = await SummarizeAsync(target, months[target], cancellationToken);

        var byChannel = Join(
                SalesBreakdown.ByChannel(await reports.GetTotalsByChannelAsync(@base.Start, @base.End, cancellationToken)),
                SalesBreakdown.ByChannel(await reports.GetTotalsByChannelAsync(target.Start, target.End, cancellationToken)))
            .OrderBy(i => i.Key == nameof(Domain.Enums.SalesChannel.InPerson) ? 0 : 1)
            .ToList();

        var byMarketplace = Join(
                SalesBreakdown.ByMarketplace(await reports.GetOnlineTotalsByMarketplaceAsync(@base.Start, @base.End, cancellationToken)),
                SalesBreakdown.ByMarketplace(await reports.GetOnlineTotalsByMarketplaceAsync(target.Start, target.End, cancellationToken)))
            .OrderByDescending(i => i.Target.Revenue)
            .ThenByDescending(i => i.Base.Revenue)
            .ThenBy(i => i.Name, StringComparer.CurrentCulture)
            .ToList();

        var products = CompareProducts(
            await reports.GetTotalsByProductAsync(@base.Start, @base.End, cancellationToken),
            await reports.GetTotalsByProductAsync(target.Start, target.End, cancellationToken));

        var byDay = CompareDays(
            @base, await reports.GetTotalsByDayAsync(@base.Start, @base.End, cancellationToken),
            target, await reports.GetTotalsByDayAsync(target.Start, target.End, cancellationToken));

        return new MonthComparisonResponse(baseSummary, targetSummary, byChannel, byMarketplace, products, byDay);
    }

    private SalesMonth? ParseMonth(string key, string? value, string requiredMessage)
    {
        if (string.IsNullOrWhiteSpace(value))
            Notify(key, requiredMessage);
        else if (!SalesMonth.TryParse(value, out var month))
            Notify(key, $"Mês \"{value.Trim()}\" inválido. Use o formato AAAA-MM (ex.: 2026-01).");
        else
            return month;

        return null;
    }

    private async Task<MonthSummary> SummarizeAsync(SalesMonth month, MonthTotals totals, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(timeProvider.GetLocalNow().DateTime);
        var elapsed = today > month.End ? month.Days
            : today < month.Start ? 0
            : today.Day;

        var cost = await reports.GetCostTotalsAsync(month.Start, month.End, cancellationToken);
        return new MonthSummary(month.ToString(), month.Label, month.Days, elapsed,
            totals.Sales, totals.Quantity, totals.Revenue, SalesBreakdown.Profit(cost));
    }

    /// <summary>Every group present in either month, with zeros on the side where it had no sales.</summary>
    private static IEnumerable<ComparisonItem> Join(List<BreakdownItem> baseItems, List<BreakdownItem> targetItems)
    {
        var baseByKey = baseItems.ToDictionary(i => i.Key);
        var targetByKey = targetItems.ToDictionary(i => i.Key);

        foreach (var key in targetItems.Select(i => i.Key).Union(baseItems.Select(i => i.Key)))
        {
            var name = (targetByKey.GetValueOrDefault(key) ?? baseByKey[key]).Name;
            yield return new ComparisonItem(key, name, null,
                Totals(baseByKey.GetValueOrDefault(key)), Totals(targetByKey.GetValueOrDefault(key)));
        }
    }

    private static PeriodTotals Totals(BreakdownItem? item) =>
        item is null ? PeriodTotals.Zero : new PeriodTotals(item.Sales, item.Quantity, item.Revenue);

    /// <summary>
    /// Merges spelling variations of the same product (same key) in each month and pairs them up.
    /// The name shown is the most sold spelling of the target month (or of the base, if not sold in the target).
    /// </summary>
    private static List<ComparisonItem> CompareProducts(IReadOnlyList<ProductTotals> baseTotals, IReadOnlyList<ProductTotals> targetTotals)
    {
        var baseByKey = baseTotals.GroupBy(t => t.Key).ToDictionary(g => g.Key, g => g.ToList());
        var targetByKey = targetTotals.GroupBy(t => t.Key).ToDictionary(g => g.Key, g => g.ToList());

        return targetByKey.Keys.Union(baseByKey.Keys)
            .Select(key =>
            {
                var inBase = baseByKey.GetValueOrDefault(key) ?? [];
                var inTarget = targetByKey.GetValueOrDefault(key) ?? [];
                var main = (inTarget.Count > 0 ? inTarget : inBase).MaxBy(t => t.Quantity)!;
                return new ComparisonItem(key, main.ProductName, main.Sku, Sum(inBase), Sum(inTarget));
            })
            .OrderByDescending(i => i.Target.Revenue)
            .ThenByDescending(i => i.Base.Revenue)
            .ThenBy(i => i.Name, StringComparer.CurrentCulture)
            .ToList();
    }

    private static PeriodTotals Sum(List<ProductTotals> totals) =>
        new(totals.Sum(t => t.Sales), totals.Sum(t => t.Quantity), totals.Sum(t => t.Revenue));

    /// <summary>Day 1 to the longer month's end; zeros on days without sales, null past a month's end.</summary>
    private static List<DayComparisonItem> CompareDays(
        SalesMonth @base, IReadOnlyList<DayTotals> baseDays, SalesMonth target, IReadOnlyList<DayTotals> targetDays)
    {
        static PeriodTotals? DayOf(SalesMonth month, Dictionary<int, DayTotals> days, int day) =>
            day > month.Days ? null
            : days.TryGetValue(day, out var t) ? new PeriodTotals(t.Sales, t.Quantity, t.Revenue)
            : PeriodTotals.Zero;

        var baseByDay = baseDays.ToDictionary(d => d.Date.Day);
        var targetByDay = targetDays.ToDictionary(d => d.Date.Day);

        return Enumerable.Range(1, Math.Max(@base.Days, target.Days))
            .Select(day => new DayComparisonItem(day, DayOf(@base, baseByDay, day), DayOf(target, targetByDay, day)))
            .ToList();
    }
}
