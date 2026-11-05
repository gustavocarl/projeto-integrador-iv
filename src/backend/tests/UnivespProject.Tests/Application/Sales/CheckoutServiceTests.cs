using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Infrastructure.Spreadsheets;

using UnivespProject.Tests.Application.Settings;

namespace UnivespProject.Tests.Application.Sales;

public class CheckoutServiceTests
{
    private readonly FakeSalesImportRepository _imports = new();
    private readonly FakeMarketplaceRepository _marketplaces = new();
    private readonly FakeProductRepository _products = new();
    private readonly Notifier _notifier = new();
    private readonly FakeTimeProvider _clock;
    private readonly CheckoutService _service;

    private readonly Product _notebook;
    private readonly Product _mouse;

    public CheckoutServiceTests()
    {
        _clock = new FakeTimeProvider(new DateTimeOffset(2026, 10, 29, 12, 0, 0, TimeSpan.Zero));
        _clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new CheckoutService(_notifier, _products, _imports, _marketplaces, _clock);

        _notebook = new Product("Notebook Pro 14", "NB-14", "Notebooks", 6000m, 4500m, 3, 1);
        _mouse = new Product("Mouse sem fio", "MOU-280", "Periféricos", 80m, null, 10, 2);
        _products.Items.AddRange([_notebook, _mouse]);
    }

    private static CheckoutRequest Request(params CheckoutItemRequest[] items) =>
        new(null, "Presencial", null, items);

    private CheckoutItemRequest Item(Product product, int? quantity = 1, decimal? price = null) =>
        new(product.Id, quantity, price);

    private IEnumerable<string> Keys => _notifier.Notifications.Select(n => n.Key);

    [Fact]
    public async Task Checkout_CreatesTheMonthsBatch_TakesStock_AndCalculatesProfit()
    {
        var response = await _service.CheckoutAsync(Request(Item(_notebook, 2), Item(_mouse, 3, 70m)));

        Assert.False(_notifier.HasNotifications);
        var batch = Assert.Single(_imports.Items);
        Assert.Equal(("Vendas - outubro/2026", ImportSource.Store, 2), (batch.FileName, batch.Source, batch.SalesCount));
        Assert.Equal((1, 7), (_notebook.StockQuantity, _mouse.StockQuantity));
        // Cost only for the notebook: 2 × 6000 − 2 × 4500.
        Assert.Equal((12210m, (decimal?)9000m, (decimal?)3000m), (response!.Total, response.Cost, response.Profit));
        Assert.Equal([_notebook.Id, _mouse.Id], response.Sales.Select(s => s.ProductId!.Value));
        Assert.All(response.Sales, s => Assert.True(s.IsCheckout));
        Assert.Equal(70m, response.Sales[1].UnitPrice);
        Assert.True(_imports.Saved);
    }

    [Fact]
    public async Task Checkout_SameMonth_ReusesTheBatch()
    {
        await _service.CheckoutAsync(Request(Item(_mouse)));
        await _service.CheckoutAsync(Request(Item(_mouse)) with { Date = new DateOnly(2026, 10, 2) });

        var batch = Assert.Single(_imports.Items);
        Assert.Equal(2, batch.SalesCount);
        Assert.Single(_imports.AddedSales);
    }

    [Fact]
    public async Task Checkout_AnotherMonth_CreatesAnotherBatch()
    {
        await _service.CheckoutAsync(Request(Item(_mouse)) with { Date = new DateOnly(2026, 9, 30) });

        Assert.Equal("Vendas - setembro/2026", Assert.Single(_imports.Items).FileName);
    }

    [Fact]
    public async Task NotEnoughStock_AcrossLines_FailsTheWholeSale()
    {
        Assert.Null(await _service.CheckoutAsync(Request(Item(_mouse, 2), Item(_notebook, 2), Item(_notebook, 2))));

        Assert.Equal(["items[2].quantity"], Keys);
        Assert.Equal((3, 10), (_notebook.StockQuantity, _mouse.StockQuantity));
        Assert.Empty(_imports.Items);
    }

    [Fact]
    public async Task InactiveOrUnknownProducts_AreRejected()
    {
        _mouse.SetActive(false);

        Assert.Null(await _service.CheckoutAsync(Request(Item(_mouse), new CheckoutItemRequest(Guid.NewGuid(), 1, null),
            new CheckoutItemRequest(null, 1, null))));

        Assert.Equal(["items[0].productId", "items[1].productId", "items[2].productId"], Keys);
    }

    [Fact]
    public async Task PriceBelowTheCost_FailsTheWholeSale_OnThatLine()
    {
        // Notebook cost: 4500 (also more than 15% off: the cost error is the one reported).
        Assert.Null(await _service.CheckoutAsync(Request(Item(_mouse), Item(_notebook, 1, 4499.99m))));

        var error = Assert.Single(_notifier.Notifications);
        Assert.Equal("items[1].unitPrice", error.Key);
        Assert.Equal("O preço não pode ser menor que o custo (R$ 4.500,00): a venda daria prejuízo.", error.Message);
        Assert.Equal((3, 10), (_notebook.StockQuantity, _mouse.StockQuantity));
        Assert.Empty(_imports.Items);
    }

    [Fact]
    public async Task PriceEqualToTheCost_IsSold_WithNoProfit()
    {
        // A product whose cost is above the 15% discount floor: 100 → minimum 85, cost 90.
        var cable = new Product("Cabo", "CAB-1", null, 100m, 90m, 5, 0);
        _products.Items.Add(cable);

        var response = await _service.CheckoutAsync(Request(Item(cable, 1, 90m)));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal((decimal?)0m, response!.Profit);
    }

    [Fact]
    public async Task DiscountAbove15Percent_FailsTheWholeSale_OnThatLine()
    {
        // Mouse: 80 → minimum 68 (no cost). Notebook: 6000 → minimum 5100 (cost 4500).
        Assert.Null(await _service.CheckoutAsync(Request(Item(_mouse, 1, 67.99m), Item(_notebook, 1, 5099.99m))));

        Assert.Equal(
            [
                ("items[0].unitPrice", "O desconto não pode passar de 15% do preço do produto: o mínimo é R$ 68,00."),
                ("items[1].unitPrice", "O desconto não pode passar de 15% do preço do produto: o mínimo é R$ 5.100,00.")
            ],
            _notifier.Notifications.Select(n => (n.Key, n.Message)));
        Assert.Equal((3, 10), (_notebook.StockQuantity, _mouse.StockQuantity));
        Assert.Empty(_imports.Items);
    }

    [Fact]
    public async Task Exactly15PercentOff_OrAboveThePrice_IsSold()
    {
        var response = await _service.CheckoutAsync(Request(Item(_mouse, 1, 68m), Item(_notebook, 1, 6500m)));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(6568m, response!.Total);
    }

    [Fact]
    public async Task SharedFieldErrors_AreReportedOnce_ItemErrorsPerLine()
    {
        var request = new CheckoutRequest(new DateOnly(2026, 11, 1), "Fax", null,
            [Item(_mouse, 0), Item(_notebook, 1, -1m)]);

        Assert.Null(await _service.CheckoutAsync(request));

        Assert.Equal(["channel", "date", "items[0].quantity", "items[1].unitPrice"], Keys.Order());
    }

    [Fact]
    public async Task EmptySale_IsRejected()
    {
        Assert.Null(await _service.CheckoutAsync(new CheckoutRequest(null, "Online", null, null)));

        Assert.Equal(["items"], Keys);
    }

    [Fact]
    public async Task Online_WithANewMarketplace_CreatesIt()
    {
        await _service.CheckoutAsync(new CheckoutRequest(null, "Online", "  shopee ", [Item(_mouse)]));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal("shopee", Assert.Single(_marketplaces.Items).Name);
    }

    [Fact]
    public async Task DeletingACheckoutSale_ReturnsItsStock()
    {
        var response = await _service.CheckoutAsync(Request(Item(_mouse, 4)));
        var sales = new SaleService(_notifier, _imports, _marketplaces, _products, _clock);

        Assert.True(await sales.DeleteAsync(response!.Import.Id, response.Sales[0].Id));

        Assert.Equal(10, _mouse.StockQuantity);
    }

    [Fact]
    public async Task DeletingTheBatch_ReturnsEveryProductsStock()
    {
        await _service.CheckoutAsync(Request(Item(_mouse, 4), Item(_notebook, 1)));
        var response = await _service.CheckoutAsync(Request(Item(_mouse, 1)));
        var imports = new SalesImportService(_notifier, new ClosedXmlSalesSpreadsheet(), _imports, _marketplaces, _products, new FakeCurrentUserSettings(), _clock);

        Assert.True(await imports.DeleteAsync(response!.Import.Id));

        Assert.Equal((10, 3), (_mouse.StockQuantity, _notebook.StockQuantity));
        Assert.Empty(_imports.Items);
    }

    [Fact]
    public async Task DeletionImpact_ShowsTheUnitsThatGoBackToStock()
    {
        await _service.CheckoutAsync(Request(Item(_mouse, 4), Item(_notebook, 1)));
        var response = await _service.CheckoutAsync(Request(Item(_mouse, 1)));
        var imports = new SalesImportService(_notifier, new ClosedXmlSalesSpreadsheet(), _imports, _marketplaces, _products, new FakeCurrentUserSettings(), _clock);

        var impact = await imports.GetDeletionImpactAsync(response!.Import.Id);

        Assert.Equal((3, 2, 6), (impact!.SalesCount, impact.LinkedProducts, impact.StockReturned));
    }

    [Fact]
    public async Task Detail_ShowsTheProfitOfTheSalesWithCost()
    {
        var response = await _service.CheckoutAsync(Request(Item(_notebook, 1), Item(_mouse, 1)));
        var imports = new SalesImportService(_notifier, new ClosedXmlSalesSpreadsheet(), _imports, _marketplaces, _products, new FakeCurrentUserSettings(), _clock);

        var detail = await imports.GetAsync(response!.Import.Id);

        Assert.Equal(new ProfitSummary(1, 6000m, 4500m, 1500m, 0.25m), detail!.Profit);
    }
}
