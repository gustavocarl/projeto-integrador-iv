using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.Analytics;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Sales;

namespace UnivespProject.Tests.Application.Analytics;

public class SalesForecastServiceTests
{
    private readonly FakeSalesReportRepository _reports = new();
    private readonly FakeProductRepository _products = new();
    private readonly FakeSalesForecaster _forecaster = new();
    private readonly Notifier _notifier = new();
    private readonly SalesForecastService _service;

    public SalesForecastServiceTests()
    {
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 11, 2, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new SalesForecastService(_notifier, _reports, _products, _forecaster, clock);
    }

    private IEnumerable<(string Key, string Message, NotificationType Type)> Errors =>
        _notifier.Notifications.Select(n => (n.Key, n.Message, n.Type));

    /// <summary>July, August and September of 2026: a mouse (catalog) and a cable (spreadsheet only).</summary>
    private Product ThreeMonths()
    {
        var mouse = new Product("Mouse", "MOU", null, 80m, null, 5, 2);
        _products.Items.Add(mouse);
        _reports.Month(2026, 7, ("Mouse", "MOU", 10, 800m, mouse.Id), ("Cabo", null, 4, 120m, null));
        _reports.Month(2026, 8, ("Mouse", "MOU", 12, 960m, mouse.Id), ("Cabo", null, 6, 180m, null));
        _reports.Month(2026, 9, ("Mouse", "MOU", 14, 1050m, mouse.Id), ("Cabo", null, 5, 150m, null));
        return mouse;
    }

    [Theory]
    [InlineData(0)]
    [InlineData(7)]
    public async Task Months_OutOfRange_IsAnError(int months)
    {
        ThreeMonths();

        Assert.Null(await _service.ForecastAsync(months));

        Assert.Equal([("months", "Escolha de 1 a 6 meses.", NotificationType.Validation)], Errors);
        Assert.Empty(_forecaster.Calls);
    }

    [Fact]
    public async Task WithoutThreeCompleteMonths_IsNotFound()
    {
        _reports.Month(2026, 8, ("Mouse", "MOU", 10, 800m, null));
        _reports.Month(2026, 9, ("Mouse", "MOU", 12, 960m, null));

        Assert.Null(await _service.ForecastAsync(null));

        var error = Assert.Single(Errors);
        Assert.Equal((string.Empty, NotificationType.NotFound), (error.Key, error.Type));
        Assert.Equal("A previsão precisa de pelo menos 3 meses completos de vendas e há só 2. "
                     + "O mês atual e meses com vendas em menos da metade dos dias não contam.", error.Message);
    }

    [Fact]
    public async Task PredictsTheMonthsAfterTheCurrentOne_PerProduct_WithThePurchaseSuggestion()
    {
        ThreeMonths();
        // Mouse: 10 units in December, 11 in January, 12 in February; cable: 2.4 → 2.
        _forecaster.Rule = (q, _) => q.ProductKey == "MOU" ? 10 + (q.Month.Index - new SalesMonth(2026, 12).Index) : 2.4;

        var result = await _service.ForecastAsync(3);

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(["2026-07", "2026-08", "2026-09"], result!.History.Select(h => h.Month));
        Assert.Equal(
            [("2026-12", "dezembro/2026", 12, 810m), ("2027-01", "janeiro/2027", 13, 885m), ("2027-02", "fevereiro/2027", 14, 960m)],
            result.Months.Select(m => (m.Month, m.Label, m.Quantity, m.Revenue)));

        var mouse = result.Products[0];
        // Price of the last month it sold (1050 / 14 = 75), stock 5 and minimum 2: 33 + 2 - 5 = 30 to buy.
        Assert.Equal(("Mouse", 75m, 33, 2475m), (mouse.Name, mouse.Price, mouse.Quantity, mouse.Revenue));
        Assert.Equal([10, 11, 12], mouse.Quantities);
        Assert.Equal((5, 2, 30), (mouse.Stock, mouse.MinimumStock, mouse.SuggestedPurchase));

        var cable = result.Products[1];
        Assert.Equal(("Cabo", 30m, 6), (cable.Name, cable.Price, cable.Quantity));
        Assert.Equal((null, null, null), (cable.Stock, cable.MinimumStock, cable.SuggestedPurchase));
        Assert.Empty(result.IgnoredMonths);
    }

    [Fact]
    public async Task WithoutMonths_PredictsThree()
    {
        ThreeMonths();

        var result = await _service.ForecastAsync(null);

        Assert.Equal(SalesForecastService.DefaultMonths, result!.Months.Count);
    }

    [Fact]
    public async Task SuggestedPurchase_IsZero_WhenTheStockAlreadyCoversIt()
    {
        var mouse = ThreeMonths();
        mouse.Update("Mouse", "MOU", null, 80m, null, 100, 2);
        _forecaster.Rule = (_, _) => 5;

        var result = await _service.ForecastAsync(1);

        Assert.Equal(0, result!.Products.Single(p => p.Key == "MOU").SuggestedPurchase);
    }

    [Fact]
    public async Task DeactivatedProducts_TeachTheModel_ButAreNotPredicted()
    {
        var mouse = ThreeMonths();
        mouse.SetActive(false);

        var result = await _service.ForecastAsync(1);

        Assert.Equal(["CABO"], result!.Products.Select(p => p.Key));
        Assert.Contains(_forecaster.Calls[0].History, o => o.ProductKey == "MOU");
    }

    [Fact]
    public async Task Validation_TrainsWithoutTheLastMonth_AndComparesWithTheAverageGuess()
    {
        ThreeMonths();
        _forecaster.Rule = (q, _) => q.ProductKey == "MOU" ? 13 : 5;

        var result = await _service.ForecastAsync(1);

        var validation = result!.Validation!;
        Assert.Equal(("2026-09", "setembro/2026"), (validation.Month, validation.Label));
        // Sold 14 + 5 = 19. Model: 13 + 5 (error 1). Average of July and August: 11 + 5 (error 3).
        Assert.Equal((19, 18, 16), (validation.ActualQuantity, validation.PredictedQuantity, validation.BaselineQuantity));
        Assert.Equal(Math.Round(1d / 19, 4), validation.ModelError);
        Assert.Equal(Math.Round(3d / 19, 4), validation.BaselineError);

        var (history, queries) = _forecaster.Calls[1];
        Assert.DoesNotContain(history, o => o.Month == new SalesMonth(2026, 9));
        Assert.All(queries, q => Assert.Equal(new SalesMonth(2026, 9), q.Month));
    }
}
