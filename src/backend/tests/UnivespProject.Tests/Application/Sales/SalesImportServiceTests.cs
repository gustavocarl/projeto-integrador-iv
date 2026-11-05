using Microsoft.Extensions.Time.Testing;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;
using UnivespProject.Infrastructure.Spreadsheets;
using UnivespProject.Tests.Application.Settings;
using UnivespProject.Tests.Infrastructure;

namespace UnivespProject.Tests.Application.Sales;

public class SalesImportServiceTests
{
    private readonly FakeSalesImportRepository _imports = new();
    private readonly FakeMarketplaceRepository _marketplaces = new();
    private readonly FakeProductRepository _products = new();
    private readonly Notifier _notifier = new();
    private readonly FakeCurrentUserSettings _settings = new();
    private readonly SalesImportService _service;

    public SalesImportServiceTests()
    {
        var clock = new FakeTimeProvider(new DateTimeOffset(2026, 10, 29, 12, 0, 0, TimeSpan.Zero));
        clock.SetLocalTimeZone(TimeZoneInfo.Utc);
        _service = new SalesImportService(_notifier, new ClosedXmlSalesSpreadsheet(), _imports, _marketplaces, _products, _settings, clock);
    }

    private Task<SalesImportResponse?> Import(string fileName, params object?[][] rows)
    {
        var content = SpreadsheetBuilder.Build(SpreadsheetBuilder.TemplateHeader, rows);
        return _service.ImportAsync(new SpreadsheetFile(fileName, content.Length, content));
    }

    /// <summary>The user's setting "create products on import" (off by default).</summary>
    private void CreateProductsOnImport() => _settings.Value.Update(requireProductImage: null, createProductsOnImport: true);

    private static object?[] Row(string channel, string? marketplace, int quantity = 1, decimal price = 10m, string product = "Camiseta",
        int day = 1, string? sku = null) =>
        [new DateTime(2026, 10, day), product, sku, quantity, price, channel, marketplace];

    [Fact]
    public async Task ValidSpreadsheet_IsSavedWithTotals_AndCreatesEachMarketplaceOnce()
    {
        var response = await Import("vendas-outubro.xlsx",
            Row("Presencial", null, 2, 50m),
            Row("Online", "Mercado Livre", 1, 100m),
            Row("Online", "mercado  livre", 1, 100m),
            Row("Online", null, 3, 10m));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal((4, 7, 330m), (response!.SalesCount, response.TotalQuantity, response.TotalRevenue));
        Assert.Equal("vendas-outubro.xlsx", response.FileName);

        var saved = Assert.Single(_imports.Items);
        Assert.Equal(4, saved.Sales.Count);
        Assert.Equal("Mercado Livre", Assert.Single(_marketplaces.Items).Name);
        Assert.True(_imports.Saved);
    }

    [Fact]
    public async Task ExistingMarketplace_IsReused()
    {
        var existing = new Marketplace("Shopee");
        _marketplaces.Items.Add(existing);

        await Import("vendas.xlsx", Row("Online", "SHOPEE"));

        Assert.Single(_marketplaces.Items);
        Assert.Equal(existing.Id, _imports.Items[0].Sales.Single().MarketplaceId);
    }

    [Fact]
    public async Task AnyInvalidRow_RejectsTheWholeFile_WithRowNumbers()
    {
        var response = await Import("vendas.xlsx",
            Row("Online", "Shopee"),
            Row("Presencial", "Shopee"),
            Row("Drive-thru", null),
            [new DateTime(2026, 10, 1), "", null, "x", 10, "Online", null]);

        Assert.Null(response);
        Assert.Empty(_imports.Items);
        Assert.Empty(_marketplaces.Items);
        Assert.False(_imports.Saved);

        var messages = _notifier.Notifications.Select(n => n.Message).ToList();
        Assert.Contains("Linha 3: Venda presencial não pode ter marketplace.", messages);
        Assert.Contains(messages, m => m.StartsWith("Linha 4: Canal \"Drive-thru\" inválido"));
        Assert.Contains("Linha 5: O produto é obrigatório.", messages);
        Assert.Contains(messages, m => m.StartsWith("Linha 5: Valor \"x\" inválido"));
        // The unparsable quantity is reported once, not also as "required".
        Assert.DoesNotContain("Linha 5: A quantidade é obrigatória.", messages);
    }

    [Theory]
    [InlineData("vendas.csv")]
    [InlineData("vendas.xls")]
    public async Task OnlyXlsxIsAccepted(string fileName)
    {
        Assert.Null(await Import(fileName, Row("Online", null)));
        Assert.Contains(_notifier.Notifications, n => n.Message.Contains(".xlsx"));
    }

    [Fact]
    public async Task EmptySpreadsheet_IsRejected()
    {
        Assert.Null(await Import("vendas.xlsx"));
        Assert.Contains(_notifier.Notifications, n => n.Message.Contains("não contém vendas"));
    }

    [Fact]
    public async Task ErrorList_IsCapped()
    {
        var rows = Enumerable.Range(0, SalesImportService.MaxReportedErrors + 20)
            .Select(_ => Row("Presencial", "Shopee"))
            .ToArray();

        await Import("vendas.xlsx", rows);

        Assert.Equal(SalesImportService.MaxReportedErrors + 1, _notifier.Notifications.Count);
        Assert.Contains("e mais 20 erro(s)", _notifier.Notifications.Last().Message);
    }

    [Fact]
    public async Task Get_UnknownImport_IsNotFound()
    {
        Assert.Null(await _service.GetAsync(Guid.NewGuid()));
        Assert.Equal(UnivespProject.Domain.Notifications.NotificationType.NotFound, _notifier.Notifications.Single().Type);
    }

    [Fact]
    public async Task Get_ReturnsEveryDayOfThePeriod_WithZerosForDaysWithoutSales()
    {
        var imported = await Import("vendas.xlsx",
            Row("Presencial", null, 2, 10m, day: 1),
            Row("Online", null, 1, 30m, day: 1),
            Row("Online", null, 1, 5m, day: 4));

        var detail = await _service.GetAsync(imported!.Id);

        Assert.Equal(
            [(1, 2, 3, 50m), (2, 0, 0, 0m), (3, 0, 0, 0m), (4, 1, 1, 5m)],
            detail!.ByDay.Select(d => (d.Date.Day, d.Sales, d.Quantity, d.Revenue)));
    }

    [Fact]
    public async Task Get_GroupsProductsBySkuOrName_SortedByRevenue_WithAbcClass()
    {
        var imported = await Import("vendas.xlsx",
            Row("Online", null, 8, 100m, "Notebook", day: 1, sku: "NTB-1"),
            Row("Online", null, 1, 100m, "Notebook i5", day: 3, sku: "ntb-1"),   // same SKU, other spelling
            Row("Presencial", null, 10, 10m, "Mouse", day: 2),
            Row("Presencial", null, 5, 10m, "mouse ", day: 5),                     // same name, no SKU
            Row("Online", null, 1, 20m, "Cabo USB", day: 2));

        var products = (await _service.GetAsync(imported!.Id))!.Products;

        Assert.Equal(["Notebook", "Mouse", "Cabo USB"], products.Select(p => p.Name));
        Assert.Equal((2, 9, 900m), (products[0].Sales, products[0].Quantity, products[0].Revenue));
        Assert.Equal(new DateOnly(2026, 10, 3), products[0].LastSaleDate);
        Assert.Equal((2, 15, 150m), (products[1].Sales, products[1].Quantity, products[1].Revenue));
        Assert.Equal(["A", "B", "C"], products.Select(p => p.AbcClass));
        // Median quantity = 9: the cable is C and sold fewer units, so it is flagged.
        Assert.Equal(["Prioritize", "Keep", "ReviewRemoval"], products.Select(p => p.Recommendation));
        Assert.Equal(1m, products.Sum(p => p.RevenueShare), 2);
    }

    [Fact]
    public async Task Import_LinksRowsToRegisteredProductsBySku_IgnoringCase()
    {
        var mouse = new Product("Mouse sem fio", "MOU-280", null, 80m, 40m, 10, 0);
        _products.Items.Add(mouse);

        // The setting is off by default.
        var response = await Import("vendas.xlsx",
            Row("Presencial", null, 2, 80m, "Mouse", sku: "mou-280"),
            Row("Presencial", null, 1, 10m, "Caneta", sku: "CAN-01"),
            Row("Presencial", null, 1, 10m, "Sem SKU"));

        var sales = Assert.Single(_imports.Items).Sales.ToList();
        Assert.Equal([mouse.Id, null, null], sales.Select(s => s.ProductId));
        // Without the setting, unknown SKUs don't become products.
        Assert.Equal(mouse, Assert.Single(_products.Items));
        Assert.Equal(0, response!.CreatedProducts);
        Assert.All(sales, s => Assert.False(s.IsCheckout));
        // Imported sales don't take stock or carry cost.
        Assert.Equal((10, (decimal?)null), (mouse.StockQuantity, sales[0].TotalCost));
    }

    [Fact]
    public async Task Import_RegistersUnknownSkusAsProducts_AndLinksTheirSales()
    {
        var mouse = new Product("Mouse sem fio", "MOU-280", null, 80m, 40m, 10, 0);
        _products.Items.Add(mouse);
        CreateProductsOnImport();

        var response = await Import("vendas.xlsx",
            Row("Presencial", null, 2, 80m, "Mouse", sku: "mou-280"),
            Row("Online", null, 1, 12m, "Caneta azul", day: 1, sku: "can-01"),
            Row("Online", null, 1, 15m, "Caneta Azul BIC", day: 5, sku: "CAN-01"),
            Row("Presencial", null, 3, 14m, "Caneta azul", day: 3, sku: "CAN-01"),
            Row("Presencial", null, 1, 10m, "Sem SKU"));

        Assert.Equal(1, response!.CreatedProducts);
        var caneta = Assert.Single(_products.Items, p => p.Id != mouse.Id);
        // The name used most, the latest price; nothing that the spreadsheet doesn't say.
        Assert.Equal(("Caneta azul", "CAN-01", 15m), (caneta.Name, caneta.Sku, caneta.SalePrice));
        Assert.Equal((null, (decimal?)null, null, 0, 0, true),
            (caneta.Category, caneta.CostPrice, caneta.ImageUrl, caneta.StockQuantity, caneta.MinimumStock, caneta.IsActive));

        var sales = Assert.Single(_imports.Items).Sales.ToList();
        Assert.Equal([mouse.Id, caneta.Id, caneta.Id, caneta.Id, null], sales.Select(s => s.ProductId));
        // Older sales with the new SKU are linked too; the existing product is left alone.
        Assert.Equal([(caneta.Id, "CAN-01")], _products.Synced);
        Assert.Equal((10, 80m), (mouse.StockQuantity, mouse.SalePrice));
    }

    [Fact]
    public async Task AlreadyRegisteredProducts_AreNeverRegisteredAgain()
    {
        // Registered by hand (with another spelling of the SKU) and deactivated: still the same product.
        var inactive = new Product("Teclado antigo", "TEC-01", null, 100m, null, 0, 0);
        inactive.SetActive(false);
        _products.Items.Add(inactive);
        CreateProductsOnImport();

        var first = await Import("outubro.xlsx",
            Row("Presencial", null, 1, 90m, "Teclado", sku: "tec-01"),
            Row("Presencial", null, 1, 20m, "Caneta", sku: "CAN-01"),
            Row("Online", null, 2, 21m, "Caneta", sku: "can-01"));
        var second = await Import("novembro.xlsx",
            Row("Presencial", null, 1, 22m, "Caneta azul", sku: "CAN-01"),
            Row("Presencial", null, 1, 95m, "Teclado", sku: "TEC-01"));

        // Only CAN-01 was new, and only on the first import (repeated rows = one product).
        Assert.Equal((1, 0), (first!.CreatedProducts, second!.CreatedProducts));
        Assert.Equal(["CAN-01", "TEC-01"], _products.Items.Select(p => p.Sku).Order());
        var caneta = _products.Items.Single(p => p.Sku == "CAN-01");

        // Every sale goes to the existing product, which is left as it was.
        Assert.Equal([inactive.Id, caneta.Id, caneta.Id], _imports.Items[0].Sales.Select(s => s.ProductId));
        Assert.Equal([caneta.Id, inactive.Id], _imports.Items[1].Sales.Select(s => s.ProductId));
        Assert.Equal(("Caneta", 21m), (caneta.Name, caneta.SalePrice));
        Assert.Equal(("Teclado antigo", 100m, false), (inactive.Name, inactive.SalePrice, inactive.IsActive));
    }

    [Fact]
    public async Task InvalidSpreadsheet_RegistersNoProduct()
    {
        CreateProductsOnImport();
        await Import("vendas.xlsx",
            Row("Presencial", null, 1, 10m, "Caneta", sku: "CAN-01"),
            Row("Presencial", "Shopee", 1, 10m, "Lápis", sku: "LAP-01"));

        Assert.Empty(_products.Items);
        Assert.Empty(_products.Synced);
        Assert.Empty(_imports.Items);
    }

    [Fact]
    public void NewProduct_IsNotMadeForASkuThatWouldBeStoredDifferently()
    {
        var today = new DateOnly(2026, 10, 29);
        var sale = new Sale(2, today, "Camisa", "CÂM-01", 1, 10m, SalesChannel.InPerson, null, today);

        Assert.Null(SalesImportService.NewProduct(sale.SkuKey!, [sale]));
    }

    [Fact]
    public async Task DeletionImpact_CountsTheLinkedProducts_AndChangesNothing()
    {
        _products.Items.Add(new Product("Mouse sem fio", "MOU-280", null, 80m, null, 10, 0));
        _products.Items.Add(new Product("Caneta", "CAN-01", null, 5m, null, 10, 0));
        await Import("vendas.xlsx",
            Row("Presencial", null, 2, 80m, "Mouse", sku: "MOU-280"),
            Row("Online", null, 1, 80m, "Mouse", sku: "mou-280"),
            Row("Presencial", null, 3, 5m, "Caneta", sku: "CAN-01"),
            Row("Presencial", null, 1, 10m, "Sem cadastro", sku: "XYZ-9"),
            Row("Presencial", null, 1, 10m, "Sem SKU"));
        var batch = Assert.Single(_imports.Items);

        var impact = await _service.GetDeletionImpactAsync(batch.Id);

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(new SalesImportDeletionImpactResponse(batch.Id, "vendas.xlsx", 5, 275m, 2, 0), impact);
        Assert.Single(_imports.Items);
        Assert.Equal(5, batch.Sales.Count);
    }

    [Fact]
    public void Template_UsesTheFontOfTheUsersSystem()
    {
        var bytes = _service.CreateTemplate("linux");

        using var workbook = new ClosedXML.Excel.XLWorkbook(new MemoryStream(bytes!));
        Assert.Equal("Liberation Sans", workbook.Worksheet("Vendas").Cell(1, 1).Style.Font.FontName);
        Assert.Equal("Calibri", new ClosedXML.Excel.XLWorkbook(new MemoryStream(_service.CreateTemplate()!))
            .Worksheet("Vendas").Cell(1, 1).Style.Font.FontName);
    }

    [Fact]
    public void Template_ForAnUnknownSystem_IsAnError()
    {
        Assert.Null(_service.CreateTemplate("amiga"));

        Assert.Equal(("platform", SpreadsheetFont.InvalidMessage),
            (_notifier.Notifications.Single().Key, _notifier.Notifications.Single().Message));
    }

    [Fact]
    public async Task DeletionImpact_OfAMissingBatch_IsNotFound()
    {
        Assert.Null(await _service.GetDeletionImpactAsync(Guid.NewGuid()));

        Assert.Equal(NotificationType.NotFound, Assert.Single(_notifier.Notifications).Type);
    }

    [Fact]
    public async Task DeletingABatch_ReturnsStockOnlyForCheckoutSales()
    {
        var mouse = new Product("Mouse sem fio", "MOU-280", null, 80m, null, 10, 0);
        _products.Items.Add(mouse);
        await Import("vendas.xlsx", Row("Presencial", null, 3, 80m, "Mouse", sku: "MOU-280"));

        await _service.DeleteAsync(Assert.Single(_imports.Items).Id);

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(10, mouse.StockQuantity);
    }
}
