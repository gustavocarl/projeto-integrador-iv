using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Tests.Application.Sales;

public class SaleServiceTests
{
    private static readonly DateOnly Today = new(2026, 10, 29);

    private readonly FakeSalesImportRepository _imports = new();
    private readonly FakeMarketplaceRepository _marketplaces = new();
    private readonly FakeProductRepository _products = new();
    private readonly Notifier _notifier = new();
    private readonly SaleService _service;

    public SaleServiceTests()
    {
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 10, 29, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new SaleService(_notifier, _imports, _marketplaces, _products, clock);
    }

    private static ManualSaleRequest Request(
        Guid? importId = null, string? importName = "Balcão outubro", string? product = "Mouse sem fio",
        int? quantity = 2, decimal? price = 79.90m, string? channel = "Online", string? marketplace = null,
        DateOnly? date = null) =>
        new(importId, importName, date ?? new DateOnly(2026, 10, 20), product, "MOU-280", quantity, price, channel, marketplace);

    private SalesImport ExistingBatch(params (int Day, int Quantity, decimal Price)[] sales)
    {
        var batch = new SalesImport("vendas-outubro.xlsx");
        var row = 2;
        foreach (var (day, quantity, price) in sales)
            batch.AddSale(new Sale(row++, new DateOnly(2026, 10, day), "Camiseta", null, quantity, price, SalesChannel.InPerson, null, Today));
        _imports.Items.Add(batch);
        return batch;
    }

    private IEnumerable<string> Keys => _notifier.Notifications.Select(n => n.Key);

    [Fact]
    public async Task NewManualBatch_IsCreatedWithTheSale()
    {
        var response = await _service.CreateAsync(Request());

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(("Balcão outubro", "Manual", 1, 2, 159.80m),
            (response!.Import.FileName, response.Import.Source, response.Import.SalesCount, response.Import.TotalQuantity, response.Import.TotalRevenue));
        Assert.Equal(("Mouse sem fio", "Online", "Online", (int?)null, (string?)null),
            (response.Sale.ProductName, response.Sale.Channel, response.Sale.ChannelName, response.Sale.RowNumber, response.Sale.Marketplace));
        Assert.Equal(ImportSource.Manual, Assert.Single(_imports.Items).Source);
        Assert.True(_imports.Saved);
    }

    [Fact]
    public async Task ExistingBatch_ReceivesTheSale_AndTotalsAreUpdated()
    {
        var batch = ExistingBatch((5, 1, 50m));

        var response = await _service.CreateAsync(Request(importId: batch.Id, importName: null, channel: "InPerson"));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal((2, 3, 209.80m), (response!.Import.SalesCount, response.Import.TotalQuantity, response.Import.TotalRevenue));
        Assert.Equal(("Spreadsheet", new DateOnly(2026, 10, 5), new DateOnly(2026, 10, 20)),
            (response.Import.Source, response.Import.PeriodStart!.Value, response.Import.PeriodEnd!.Value));
        Assert.Single(_imports.Items);
        Assert.Single(_imports.AddedSales);
    }

    [Fact]
    public async Task Marketplace_IsReusedIgnoringCase_OrCreated()
    {
        _marketplaces.Items.Add(new Marketplace("Mercado Livre"));

        var reused = await _service.CreateAsync(Request(marketplace: "mercado  livre"));
        var created = await _service.CreateAsync(Request(marketplace: "KaBuM!"));

        Assert.Equal("Mercado Livre", reused!.Sale.Marketplace);
        Assert.Equal("KaBuM!", created!.Sale.Marketplace);
        Assert.Equal(["KaBuM!", "Mercado Livre"], await _service.ListMarketplacesAsync());
    }

    [Fact]
    public async Task InvalidSale_ReportsEveryField_WithTheJsonKeys_AndSavesNothing()
    {
        var response = await _service.CreateAsync(Request(
            product: " ", quantity: 0, price: -1m, channel: "Presencial", marketplace: "Amazon", date: Today.AddDays(1)));

        Assert.Null(response);
        Assert.Equal(
            ["date", "marketplace", "productName", "quantity", "unitPrice"],
            Keys.Order());
        Assert.Empty(_imports.Items);
        Assert.Empty(_marketplaces.Items);
        Assert.False(_imports.Saved);
    }

    [Fact]
    public async Task InvalidChannel_IsReportedOnce()
    {
        await _service.CreateAsync(Request(channel: "Drive-thru"));

        var notification = Assert.Single(_notifier.Notifications);
        Assert.Equal("channel", notification.Key);
        Assert.Contains("Drive-thru", notification.Message);
    }

    [Theory]
    [InlineData(false, null)]          // no batch chosen
    [InlineData(true, "Novo lote")]    // both
    public async Task Batch_MustBeExistingOrNew_NotNoneOrBoth(bool withId, string? name)
    {
        var batch = ExistingBatch((5, 1, 50m));

        Assert.Null(await _service.CreateAsync(Request(importId: withId ? batch.Id : null, importName: name)));
        Assert.Equal("importId", Assert.Single(_notifier.Notifications).Key);
    }

    [Fact]
    public async Task UnknownBatch_IsNotFound()
    {
        await _service.CreateAsync(Request(importId: Guid.NewGuid(), importName: null));

        Assert.Equal(NotificationType.NotFound, Assert.Single(_notifier.Notifications).Type);
    }

    [Fact]
    public async Task Delete_RemovesTheSale_AndRecalculatesTotals()
    {
        var batch = ExistingBatch((3, 1, 10m), (10, 2, 20m), (25, 1, 5m));
        var last = batch.Sales.Single(s => s.SaleDate.Day == 25);

        Assert.True(await _service.DeleteAsync(batch.Id, last.Id));

        Assert.Equal((2, 3, 50m, 3, 10), (batch.SalesCount, batch.TotalQuantity, batch.TotalRevenue, batch.PeriodStart!.Value.Day, batch.PeriodEnd!.Value.Day));
        Assert.Same(last, Assert.Single(_imports.RemovedSales));
        Assert.True(_imports.Saved);
    }

    [Fact]
    public async Task DeletingTheLastSale_KeepsAnEmptyBatch()
    {
        var batch = ExistingBatch((3, 1, 10m));

        await _service.DeleteAsync(batch.Id, batch.Sales.Single().Id);

        Assert.Equal((0, 0, 0m), (batch.SalesCount, batch.TotalQuantity, batch.TotalRevenue));
        Assert.Null(batch.PeriodStart);
        Assert.Single(_imports.Items);
    }

    [Fact]
    public async Task Delete_SaleOfAnotherBatch_IsNotFound()
    {
        var batch = ExistingBatch((3, 1, 10m));
        var other = ExistingBatch((4, 1, 10m));

        Assert.Null(await _service.DeleteAsync(batch.Id, other.Sales.Single().Id));
        Assert.Equal(NotificationType.NotFound, Assert.Single(_notifier.Notifications).Type);
        Assert.Equal(1, batch.SalesCount);
    }

    [Fact]
    public async Task List_PagesAndSearches_MostRecentFirst()
    {
        var batch = ExistingBatch((3, 1, 10m), (10, 1, 10m), (20, 1, 10m));
        await _service.CreateAsync(Request(importId: batch.Id, importName: null, product: "Teclado", date: new DateOnly(2026, 10, 15)));

        var page = await _service.ListAsync(batch.Id, null, page: 1, pageSize: 2);
        var search = await _service.ListAsync(batch.Id, "tecl", page: 1, pageSize: 50);

        Assert.Equal((4, 2), (page!.TotalCount, page.Items.Count));
        Assert.Equal([20, 15], page.Items.Select(s => s.Date.Day));
        Assert.Equal("Teclado", Assert.Single(search!.Items).ProductName);
    }

    [Fact]
    public async Task List_UnknownBatch_IsNotFound()
    {
        Assert.Null(await _service.ListAsync(Guid.NewGuid(), null, 1, 50));
        Assert.Equal(NotificationType.NotFound, Assert.Single(_notifier.Notifications).Type);
    }

    [Fact]
    public async Task TypedInSale_WithTheSkuOfARegisteredProduct_IsLinked_WithoutTouchingStockOrCost()
    {
        var product = new Product("Mouse sem fio", "MOU-280", null, 80m, 40m, 10, 0);
        _products.Items.Add(product);

        // Request() uses SKU "MOU-280"; typed in lower case it must still match.
        var response = await _service.CreateAsync(Request() with { Sku = "mou-280" });

        Assert.Equal((product.Id, false, (decimal?)null), (response!.Sale.ProductId, response.Sale.IsCheckout, response.Sale.TotalCost));
        Assert.Equal(10, product.StockQuantity);
    }

    [Fact]
    public async Task TypedInSale_WithoutAMatchingProduct_StaysUnlinked()
    {
        _products.Items.Add(new Product("Teclado", "TEC-01", null, 100m, null, 5, 0));

        var response = await _service.CreateAsync(Request());

        Assert.Null(response!.Sale.ProductId);
    }

    [Fact]
    public async Task DeletingALinkedTypedInSale_DoesNotReturnStock()
    {
        var product = new Product("Mouse sem fio", "MOU-280", null, 80m, null, 10, 0);
        _products.Items.Add(product);
        var created = await _service.CreateAsync(Request());

        await _service.DeleteAsync(created!.Import.Id, created.Sale.Id);

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(10, product.StockQuantity);
    }
}
