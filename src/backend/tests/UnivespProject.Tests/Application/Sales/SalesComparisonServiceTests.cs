using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Tests.Application.Sales;

public class SalesComparisonServiceTests
{
    private static readonly DateOnly Today = new(2026, 10, 31);

    private readonly FakeSalesReportRepository _reports = new();
    private readonly Notifier _notifier = new();
    private readonly SalesComparisonService _service;
    private readonly Marketplace _amazon = new("Amazon");

    public SalesComparisonServiceTests()
    {
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 10, 31, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new SalesComparisonService(_notifier, _reports, clock);
    }

    private void Sell(DateOnly date, string product, int quantity, decimal price,
        SalesChannel channel = SalesChannel.InPerson, Marketplace? marketplace = null, string? sku = null) =>
        _reports.Sales.Add(new Sale(null, date, product, sku, quantity, price, channel, marketplace, Today));

    private IEnumerable<(string Key, string Message)> Errors =>
        _notifier.Notifications.Select(n => (n.Key, n.Message));

    [Fact]
    public async Task ListMonths_MostRecentFirst_WithTotals()
    {
        Sell(new DateOnly(2025, 1, 10), "Camiseta", 2, 50m);
        Sell(new DateOnly(2026, 1, 5), "Camiseta", 1, 50m);
        Sell(new DateOnly(2026, 1, 20), "Boné", 3, 30m);

        var months = await _service.ListMonthsAsync();

        Assert.Equal(
            [("2026-01", "janeiro/2026", 2, 4, 140m), ("2025-01", "janeiro/2025", 1, 2, 100m)],
            months.Select(m => (m.Month, m.Label, m.Sales, m.Quantity, m.Revenue)));
    }

    [Fact]
    public async Task Compare_SameMonthOfDifferentYears_PairsChannelsMarketplacesAndProducts()
    {
        Sell(new DateOnly(2025, 1, 10), "Camiseta", 2, 50m, sku: "CAM-01");
        Sell(new DateOnly(2025, 1, 12), "Caneca", 1, 40m, SalesChannel.Online, _amazon);
        Sell(new DateOnly(2026, 1, 10), "camiseta", 5, 50m, SalesChannel.Online, sku: "cam-01");
        Sell(new DateOnly(2026, 1, 31), "Boné", 1, 30m);

        var result = await _service.CompareAsync("2025-01", "2026-01");

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(("janeiro/2025", 3, 140m), (result!.Base.Label, result.Base.Quantity, result.Base.Revenue));
        Assert.Equal(("janeiro/2026", 6, 280m), (result.Target.Label, result.Target.Quantity, result.Target.Revenue));
        Assert.Equal((31, 31), (result.Target.Days, result.Target.ElapsedDays));

        Assert.Equal(
            [("InPerson", 100m, 30m), ("Online", 40m, 250m)],
            result.ByChannel.Select(c => (c.Key, c.Base.Revenue, c.Target.Revenue)));

        // Own online store in the target only; Amazon in the base only.
        Assert.Equal(
            [("Fora de marketplace", 0m, 250m), ("Amazon", 40m, 0m)],
            result.ByMarketplace.Select(m => (m.Name, m.Base.Revenue, m.Target.Revenue)));

        // Same SKU written differently is the same product; the target's spelling wins.
        Assert.Equal(
            [("camiseta", 2, 5), ("Boné", 0, 1), ("Caneca", 1, 0)],
            result.Products.Select(p => (p.Name, p.Base.Quantity, p.Target.Quantity)));
    }

    [Fact]
    public async Task Compare_ByDay_GoesToTheLongerMonth_NullPastTheShorterOne()
    {
        Sell(new DateOnly(2026, 2, 3), "Camiseta", 1, 50m);
        Sell(new DateOnly(2026, 3, 31), "Camiseta", 2, 50m);

        var result = await _service.CompareAsync("2026-02", "2026-03");

        Assert.Equal(31, result!.ByDay.Count);
        Assert.Equal(50m, result.ByDay[2].Base!.Revenue);
        Assert.Equal(0m, result.ByDay[2].Target!.Revenue);
        Assert.Null(result.ByDay[30].Base);
        Assert.Equal(100m, result.ByDay[30].Target!.Revenue);
    }

    [Fact]
    public async Task Compare_CurrentMonth_ReportsElapsedDays()
    {
        Sell(new DateOnly(2026, 9, 1), "Camiseta", 1, 50m);
        Sell(new DateOnly(2026, 10, 1), "Camiseta", 1, 50m);
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 10, 15, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);

        var result = await new SalesComparisonService(_notifier, _reports, clock).CompareAsync("2026-09", "2026-10");

        Assert.Equal((30, 30), (result!.Base.Days, result.Base.ElapsedDays));
        Assert.Equal((31, 15), (result.Target.Days, result.Target.ElapsedDays));
    }

    [Fact]
    public async Task Compare_ProfitOnlyFromSalesWithCost()
    {
        var product = new Product("Mouse", "MOU-1", "Periféricos", 100m, 60m, 10, 0);
        var sale = new Sale(null, new DateOnly(2026, 10, 2), "Mouse", "MOU-1", 2, 100m, SalesChannel.InPerson, null, Today);
        sale.SellAtCheckout(product);
        _reports.Sales.Add(sale);
        Sell(new DateOnly(2026, 10, 3), "Caneca", 1, 40m);
        Sell(new DateOnly(2026, 9, 3), "Caneca", 1, 40m);

        var result = await _service.CompareAsync("2026-09", "2026-10");

        Assert.Equal((0, 0m), (result!.Base.Profit.SalesWithCost, result.Base.Profit.Profit));
        Assert.Equal((1, 80m, 0.4m), (result.Target.Profit.SalesWithCost, result.Target.Profit.Profit, result.Target.Profit.Margin));
    }

    [Theory]
    [InlineData(null, "2026-01", "base", "Escolha o mês base.")]
    [InlineData("2026-01", " ", "target", "Escolha o mês a comparar.")]
    [InlineData("janeiro", "2026-01", "base", "Mês \"janeiro\" inválido. Use o formato AAAA-MM (ex.: 2026-01).")]
    [InlineData("2026-13", "2026-01", "base", "Mês \"2026-13\" inválido. Use o formato AAAA-MM (ex.: 2026-01).")]
    [InlineData("2026-01", "2026-1", "target", "Escolha um mês diferente do mês base.")]
    [InlineData("2026-01", "2026-04", "target", "Não há vendas em abril/2026.")]
    public async Task Compare_InvalidMonths_AreReportedOnTheirParameter(string? @base, string? target, string key, string message)
    {
        Sell(new DateOnly(2026, 1, 10), "Camiseta", 1, 50m);

        var result = await _service.CompareAsync(@base, target);

        Assert.Null(result);
        Assert.Equal([(key, message)], Errors);
    }

    [Fact]
    public async Task Compare_BothMonthsWithoutSales_ReportsBoth()
    {
        var result = await _service.CompareAsync("2025-01", "2026-01");

        Assert.Null(result);
        Assert.Equal(["base", "target"], Errors.Select(e => e.Key));
    }
}
