using UnivespProject.Domain.Entities;

namespace UnivespProject.Tests.Domain;

public class ProductTests
{
    private static Product Valid(int stock = 10, int? minimum = 2) =>
        new("  Notebook   Pro 14 ", " nb-pro-14 ", " Notebooks ", 6499.904m, 4800m, stock, minimum);

    [Fact]
    public void ValidProduct_IsNormalized()
    {
        var product = Valid();

        Assert.True(product.IsValid);
        Assert.Equal(("Notebook Pro 14", "NB-PRO-14", "Notebooks", 6499.90m, 4800m, true),
            (product.Name, product.Sku, product.Category, product.SalePrice, product.CostPrice, product.IsActive));
    }

    [Fact]
    public void InvalidProduct_ReportsEveryField()
    {
        var product = new Product(" ", null, new string('x', 61), null, -1m, -2, -3);

        Assert.False(product.IsValid);
        Assert.Equal(
            ["name", "sku", "category", "salePrice", "costPrice", "stockQuantity", "minimumStock"],
            product.Notifications.Select(n => n.Key));
    }

    [Fact]
    public void CostAboveTheSalePrice_IsAnError_AndChangesNothing()
    {
        var product = Valid();

        product.Update("Notebook Pro 14", "NB-PRO-14", null, 4000m, 4000.01m, 10, 2);

        var error = Assert.Single(product.Notifications);
        Assert.Equal(("costPrice", "O preço de custo não pode ser maior que o preço de venda: cada venda daria prejuízo."),
            (error.Key, error.Message));
        Assert.Equal((6499.90m, 4800m), (product.SalePrice, product.CostPrice));
    }

    [Theory]
    [InlineData(100.0, 100.0)]
    [InlineData(100.0, 99.99)]
    [InlineData(100.0, null)]
    [InlineData(0.0, 0.0)]
    public void CostUpToTheSalePrice_IsValid(double salePrice, double? costPrice)
    {
        var product = new Product("Cabo", "CAB", null, (decimal)salePrice, (decimal?)costPrice, 1, 0);

        Assert.True(product.IsValid);
    }

    [Fact]
    public void Update_WithErrors_ChangesNothing()
    {
        var product = Valid();

        product.Update("Outro nome", "NB-2", null, -5m, null, 3, 0);

        Assert.Equal("salePrice", Assert.Single(product.Notifications).Key);
        Assert.Equal(("Notebook Pro 14", "NB-PRO-14", 10), (product.Name, product.Sku, product.StockQuantity));
    }

    [Fact]
    public void Update_ClearsPreviousErrors()
    {
        var product = Valid();
        product.Update(null, "NB", null, 1m, null, 1, 0);

        product.Update("Notebook", "NB", null, 1m, null, 1, null);

        Assert.True(product.IsValid);
        Assert.Equal((0, (decimal?)null), (product.MinimumStock, product.CostPrice));
    }

    [Theory]
    [InlineData(4, true, 6)]
    [InlineData(10, true, 0)]
    [InlineData(11, false, 10)]
    [InlineData(0, false, 10)]
    public void RemoveFromStock_NeverGoesNegative(int quantity, bool removed, int left)
    {
        var product = Valid();

        Assert.Equal(removed, product.RemoveFromStock(quantity));
        Assert.Equal(left, product.StockQuantity);
    }

    [Theory]
    [InlineData(3, 2, false)]
    [InlineData(2, 2, true)]
    [InlineData(0, 0, true)]
    public void LowStock_IsAtOrBelowTheMinimum(int stock, int minimum, bool low) =>
        Assert.Equal(low, Valid(stock, minimum).IsLowStock);

    [Theory]
    [InlineData("ftp://exemplo.com/a.png")]
    [InlineData("exemplo.com/a.png")]
    [InlineData("javascript:alert(1)")]
    [InlineData("https://")]
    [InlineData("//exemplo.com/a.png")]
    [InlineData("/uploads/../segredo.txt")]
    public void ImageUrl_MustBeAWebLink(string url)
    {
        var product = new Product("Mouse", "MOU", null, 10m, null, 1, 0, url);

        Assert.Equal("imageUrl", Assert.Single(product.Notifications).Key);
    }

    [Fact]
    public void ImageUrl_TooLong_IsAnError()
    {
        var product = new Product("Mouse", "MOU", null, 10m, null, 1, 0, "https://exemplo.com/" + new string('a', 2048));

        Assert.Equal("imageUrl", Assert.Single(product.Notifications).Key);
    }

    [Fact]
    public void ImageUrl_Blank_IsNoImage_UnlessRequired()
    {
        Assert.Null(new Product("Mouse", "MOU", null, 10m, null, 1, 0, "  ").ImageUrl);

        var required = new Product("Mouse", "MOU", null, 10m, null, 1, 0, "  ", imageRequired: true);
        Assert.Equal("imageUrl", Assert.Single(required.Notifications).Key);
    }

    [Fact]
    public void ImageUrl_CanBeThePathOfAnUploadedImage()
    {
        var product = new Product("Mouse", "MOU", null, 10m, null, 1, 0, "/uploads/products/a1b2.png");

        Assert.True(product.IsValid);
        Assert.Equal("/uploads/products/a1b2.png", product.ImageUrl);
    }

    [Theory]
    [InlineData(100.0, 99.99, true)]
    [InlineData(100.0, 100.0, false)]
    [InlineData(100.0, 100.001, false)] // compared in cents
    [InlineData(100.0, 150.0, false)]
    public void SellsAtLoss_OnlyBelowTheCost(double cost, double unitPrice, bool loss)
    {
        var product = new Product("Mouse", "MOU-1", null, 200m, (decimal)cost, 1, 0);

        Assert.Equal(loss, product.SellsAtLoss((decimal)unitPrice));
    }

    [Fact]
    public void SellsAtLoss_NeverWithoutACost()
    {
        var product = new Product("Mouse", "MOU-1", null, 200m, null, 1, 0);

        Assert.False(product.SellsAtLoss(0m));
    }

    [Theory]
    [InlineData(100.0, 85.0, false)]
    [InlineData(100.0, 84.99, true)]
    [InlineData(100.0, 120.0, false)] // above the price: not a discount
    [InlineData(99.99, 84.99, false)] // minimum 84.9915 → 84.99
    [InlineData(99.99, 84.98, true)]
    public void ExceedsMaxDiscount_Above15PercentOff(double salePrice, double unitPrice, bool exceeds)
    {
        var product = new Product("Mouse", "MOU-1", null, (decimal)salePrice, null, 1, 0);

        Assert.Equal(exceeds, product.ExceedsMaxDiscount((decimal)unitPrice));
    }
}
