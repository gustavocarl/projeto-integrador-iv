using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.Analytics;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Sales;

namespace UnivespProject.Tests.Application.Analytics;

public class ProductGroupsServiceTests
{
    private readonly FakeSalesReportRepository _reports = new();
    private readonly FakeProductClusterer _clusterer = new();
    private readonly Notifier _notifier = new();
    private readonly ProductGroupsService _service;

    public ProductGroupsServiceTests()
    {
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 11, 2, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new ProductGroupsService(_notifier, _reports, _clusterer, clock);
    }

    private IEnumerable<(string Key, string Message, NotificationType Type)> Errors =>
        _notifier.Notifications.Select(n => (n.Key, n.Message, n.Type));

    /// <summary>Two cheap products that sell a lot and two expensive ones that sell little, in September.</summary>
    private void FourProducts() =>
        _reports.Month(2026, 9,
            ("Cabo", "CAB", 60, 1_800m, null),
            ("Pen drive", "PEN", 50, 2_000m, null),
            ("Notebook", "NTB", 4, 12_000m, null),
            ("iPhone", "IPH", 3, 15_000m, null));

    [Theory]
    [InlineData(1)]
    [InlineData(7)]
    public async Task Groups_OutOfRange_IsAnError(int groups)
    {
        FourProducts();

        Assert.Null(await _service.GroupAsync(groups));

        Assert.Equal([("groups", "Escolha de 2 a 6 grupos.", NotificationType.Validation)], Errors);
    }

    [Fact]
    public async Task MoreGroupsThanProductsAllow_IsAnError()
    {
        FourProducts();

        Assert.Null(await _service.GroupAsync(4));

        Assert.Equal([("groups", "Há 4 produtos com vendas: escolha até 3 grupos.", NotificationType.Validation)], Errors);
    }

    [Fact]
    public async Task WithoutSales_IsNotFound()
    {
        Assert.Null(await _service.GroupAsync(null));

        Assert.Equal(NotificationType.NotFound, Assert.Single(Errors).Type);
    }

    [Fact]
    public async Task WithFewProducts_IsNotFound()
    {
        _reports.Month(2026, 9, ("Cabo", "CAB", 60, 1_800m, null), ("Notebook", "NTB", 4, 12_000m, null));

        Assert.Null(await _service.GroupAsync(null));
        Assert.Equal(
            [(string.Empty, "O agrupamento precisa de pelo menos 3 produtos com vendas e há 2.", NotificationType.NotFound)],
            Errors);
    }

    [Fact]
    public async Task Automatic_TriesEveryNumberOfGroups_AndKeepsTheBestSilhouette()
    {
        FourProducts();

        var result = await _service.GroupAsync(null);

        Assert.False(_notifier.HasNotifications);
        // 2 and 3 groups for 4 products; the fake always splits by volume, so 2 wins.
        Assert.Equal([2, 3], _clusterer.Requested);
        Assert.Equal([2, 3], result!.Candidates.Select(c => c.Groups));
        Assert.True(result.Automatic);
        Assert.Equal(2, result.Groups);

        var expensive = result.Clusters[0];
        Assert.Equal((1, "Alto valor, baixo giro"), (expensive.Number, expensive.Name));
        Assert.Equal(["iPhone", "Notebook"], expensive.Products.Select(p => p.Name));
        Assert.Equal((7, 27_000m, 3_857.14m), (expensive.Quantity, expensive.Revenue, expensive.AveragePrice));
        Assert.Equal(Math.Round(27_000d / 30_800, 4), expensive.RevenueShare);

        var cheap = result.Clusters[1];
        Assert.Equal((2, "Alto giro"), (cheap.Number, cheap.Name));
        Assert.Equal(["Pen drive", "Cabo"], cheap.Products.Select(p => p.Name));
        Assert.Equal(55, cheap.MonthlyQuantity);
    }

    [Fact]
    public async Task ChosenNumberOfGroups_IsKept_EvenWhenAnotherScoresBetter()
    {
        FourProducts();
        _clusterer.Rule = (points, groups) => groups == 3
            ? points.Select((_, i) => Math.Min(i, 2)).ToList()
            : points.Select(p => p[0] < 0 ? 0 : 1).ToList();

        var result = await _service.GroupAsync(3);

        Assert.False(result!.Automatic);
        Assert.Equal(3, result.Groups);
        Assert.Equal(3, result.Clusters.Count);
        Assert.Equal(result.Candidates.Single(c => c.Groups == 3).Silhouette, result.Silhouette);
    }

    [Fact]
    public async Task Features_AreVolumePriceAndRegularity_OnTheSameScale()
    {
        _reports.Month(2026, 8, ("Cabo", "CAB", 10, 300m, null), ("Mouse", "MOU", 2, 160m, null));
        _reports.Month(2026, 9, ("Cabo", "CAB", 10, 300m, null), ("Notebook", "NTB", 1, 3_000m, null));
        IReadOnlyList<double[]>? seen = null;
        _clusterer.Rule = (points, _) =>
        {
            seen = points;
            return points.Select(p => p[0] < 0 ? 0 : 1).ToList();
        };

        await _service.GroupAsync(2);

        Assert.All(seen!, p => Assert.Equal(3, p.Length));
        for (var column = 0; column < 3; column++)
            Assert.Equal(0, seen!.Average(p => p[column]), 9);
        // Regularity: the cable sold in both months, the others in one.
        Assert.True(seen![0][2] > 0 && seen[1][2] < 0 && seen[2][2] < 0);
    }
}
