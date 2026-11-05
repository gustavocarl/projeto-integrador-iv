using UnivespProject.Application.DTOs.Products;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Products;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Auth;
using UnivespProject.Tests.Application.Sales;
using UnivespProject.Tests.Application.Settings;

namespace UnivespProject.Tests.Application.Products;

public class ProductServiceTests
{
    private readonly FakeProductRepository _products = new();
    private readonly Notifier _notifier = new();
    private readonly FakeCurrentUserSettings _settings = new();
    private readonly FakeProductImageStorage _images = new();
    private readonly ProductService _service;

    public ProductServiceTests()
    {
        _service = NewService(_notifier);
    }

    private ProductService NewService(INotifier notifier) =>
        new(notifier, _products, _settings, _images);

    private static ProductRequest Request(
        string sku = "MOU-280", decimal? cost = 40m, bool? active = null, string? image = null) =>
        new("Mouse sem fio", sku, "Periféricos", 80m, cost, 15, 3, active, image);

    private Product Existing(string sku = "MOU-280")
    {
        var product = new Product("Mouse", sku, null, 80m, null, 5, 0);
        _products.Items.Add(product);
        return product;
    }

    [Fact]
    public async Task Create_SavesAnActiveProduct_WithMargin()
    {
        var response = await _service.CreateAsync(Request(sku: "mou-280"));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(("MOU-280", 0.5m, true, false), (response!.Sku, response.Margin, response.IsActive, response.IsLowStock));
        Assert.True(_products.Saved);
    }

    [Fact]
    public async Task Create_WithoutCost_HasNoMargin()
    {
        var response = await _service.CreateAsync(Request(cost: null));

        Assert.Null(response!.Margin);
    }

    [Fact]
    public async Task Create_DuplicateSku_IsAConflict()
    {
        Existing();

        Assert.Null(await _service.CreateAsync(Request(sku: " mou-280 ")));

        var error = Assert.Single(_notifier.Notifications);
        Assert.Equal(("sku", NotificationType.Conflict), (error.Key, error.Type));
        Assert.Single(_products.Items);
    }

    [Fact]
    public async Task Create_Invalid_ReportsFieldErrors()
    {
        Assert.Null(await _service.CreateAsync(new ProductRequest(null, null, null, null, null, null, null, null)));

        Assert.Equal(["name", "sku", "salePrice", "stockQuantity"], _notifier.Notifications.Select(n => n.Key));
        Assert.False(_products.Saved);
    }

    [Fact]
    public async Task Update_KeepsItsOwnSku_AndCanDeactivate()
    {
        var product = Existing();

        var response = await _service.UpdateAsync(product.Id, Request(active: false));

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(("Mouse sem fio", 15, false), (response!.Name, response.StockQuantity, response.IsActive));
    }

    [Fact]
    public async Task Update_ToAnotherProductsSku_IsAConflict()
    {
        Existing("TEC-001");
        var product = Existing();

        Assert.Null(await _service.UpdateAsync(product.Id, Request(sku: "TEC-001")));
        Assert.Equal(NotificationType.Conflict, Assert.Single(_notifier.Notifications).Type);
    }

    [Fact]
    public async Task Update_Unknown_IsNotFound()
    {
        Assert.Null(await _service.UpdateAsync(Guid.NewGuid(), Request()));
        Assert.Equal(NotificationType.NotFound, Assert.Single(_notifier.Notifications).Type);
    }

    [Fact]
    public async Task Delete_NeverSold_RemovesIt()
    {
        var product = Existing();

        Assert.True(await _service.DeleteAsync(product.Id));
        Assert.Empty(_products.Items);
    }

    [Fact]
    public async Task Delete_WithSales_IsAConflict()
    {
        var product = Existing();
        _products.Sold.Add(product.Id);

        Assert.Null(await _service.DeleteAsync(product.Id));
        Assert.Equal(NotificationType.Conflict, Assert.Single(_notifier.Notifications).Type);
        Assert.Single(_products.Items);
    }

    [Fact]
    public async Task List_HidesInactive_UnlessAsked()
    {
        Existing("A");
        Existing("B").SetActive(false);

        Assert.Single(await _service.ListAsync(null, null, includeInactive: false));
        Assert.Equal(2, (await _service.ListAsync("  ", null, includeInactive: true)).Count);
    }

    [Fact]
    public async Task Create_LinksTheSalesThatAlreadyHaveItsSku()
    {
        var response = await _service.CreateAsync(Request(sku: "mou-280"));

        Assert.Equal([(response!.Id, "MOU-280")], _products.Synced);
    }

    [Fact]
    public async Task Update_RelinksSalesToTheNewSku()
    {
        var product = Existing();

        await _service.UpdateAsync(product.Id, Request(sku: "MOU-300"));

        Assert.Equal([(product.Id, "MOU-300")], _products.Synced);
    }

    [Fact]
    public async Task InvalidUpdate_DoesNotTouchTheLinks()
    {
        var product = Existing();

        await _service.UpdateAsync(product.Id, Request(sku: ""));

        Assert.Empty(_products.Synced);
    }

    [Fact]
    public async Task Image_IsOptional_WhenTheUserDoesNotRequireIt()
    {
        var response = await _service.CreateAsync(Request());

        Assert.Null(response!.ImageUrl);
    }

    [Fact]
    public async Task Image_IsSavedAndReturned()
    {
        var response = await _service.CreateAsync(Request(image: " https://cdn.exemplo.com/mouse.png "));

        Assert.Equal("https://cdn.exemplo.com/mouse.png", response!.ImageUrl);
    }

    [Fact]
    public async Task Image_IsRequired_WhenTheUserSettingSaysSo()
    {
        _settings.Value.Update(requireProductImage: true, createProductsOnImport: null);

        Assert.Null(await _service.CreateAsync(Request()));

        var error = Assert.Single(_notifier.Notifications);
        Assert.Equal(("imageUrl", NotificationType.Validation), (error.Key, error.Type));
        Assert.Empty(_products.Items);
    }

    [Fact]
    public async Task Image_Required_AlsoBlocksAnUpdateWithoutImage()
    {
        var product = Existing();
        _settings.Value.Update(requireProductImage: true, createProductsOnImport: null);

        Assert.Null(await _service.UpdateAsync(product.Id, Request()));
        Assert.Equal("imageUrl", Assert.Single(_notifier.Notifications).Key);

        // A new request, with the image this time.
        var service = NewService(new Notifier());
        var response = await service.UpdateAsync(product.Id, Request(image: "https://cdn.exemplo.com/mouse.png"));
        Assert.Equal("https://cdn.exemplo.com/mouse.png", response!.ImageUrl);
    }

    [Fact]
    public async Task UploadedImage_CanBeUsed()
    {
        var path = _images.Add();

        var response = await _service.CreateAsync(Request(image: path));

        Assert.Equal(path, response!.ImageUrl);
    }

    [Fact]
    public async Task UploadedImage_ThatDoesNotExist_IsAnError()
    {
        Assert.Null(await _service.CreateAsync(Request(image: "/uploads/products/sumiu.png")));

        var error = Assert.Single(_notifier.Notifications);
        Assert.Equal(("imageUrl", "A imagem enviada não foi encontrada. Envie o arquivo novamente."), (error.Key, error.Message));
    }

    [Fact]
    public async Task ChangingTheImage_DeletesTheOldUploadedFile()
    {
        var old = _images.Add("velha.png");
        var created = await _service.CreateAsync(Request(image: old));
        var replacement = _images.Add("nova.png");

        await NewService(new Notifier()).UpdateAsync(created!.Id, Request(image: replacement));

        Assert.False(_images.Exists(old));
        Assert.True(_images.Exists(replacement));
    }

    [Fact]
    public async Task AnImageSharedWithAnotherProduct_IsKept()
    {
        var shared = _images.Add();
        var first = await _service.CreateAsync(Request(sku: "A-1", image: shared));
        await NewService(new Notifier()).CreateAsync(Request(sku: "B-1", image: shared));

        await NewService(new Notifier()).UpdateAsync(first!.Id, Request(sku: "A-1"));

        Assert.True(_images.Exists(shared));
    }

    [Fact]
    public async Task DeletingAProduct_DeletesItsUploadedImage()
    {
        var path = _images.Add();
        var created = await _service.CreateAsync(Request(image: path));

        Assert.True(await NewService(new Notifier()).DeleteAsync(created!.Id));

        Assert.False(_images.Exists(path));
    }
}
