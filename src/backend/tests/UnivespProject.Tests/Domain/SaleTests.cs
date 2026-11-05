using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Tests.Domain;

public class SaleTests
{
    private static readonly DateOnly Today = new(2026, 10, 29);

    private static Sale NewSale(
        SalesChannel? channel = SalesChannel.Online,
        Marketplace? marketplace = null,
        DateOnly? date = null,
        int? quantity = 2,
        decimal? unitPrice = 10.555m) =>
        new(2, date ?? Today, "Camiseta", "CAM-1", quantity, unitPrice, channel, marketplace, Today);

    [Fact]
    public void ValidSale_ComputesRoundedTotal()
    {
        var sale = NewSale();

        Assert.True(sale.IsValid);
        Assert.Equal(10.56m, sale.UnitPrice);
        Assert.Equal(21.12m, sale.TotalPrice);
    }

    [Fact]
    public void InPersonSale_CannotHaveMarketplace()
    {
        var sale = NewSale(SalesChannel.InPerson, new Marketplace("Shopee"));

        var notification = Assert.Single(sale.Notifications);
        Assert.Equal(Sale.Fields.Marketplace, notification.Key);
    }

    [Fact]
    public void OnlineSale_CanBeOutsideMarketplace()
    {
        Assert.True(NewSale(SalesChannel.Online, marketplace: null).IsValid);
    }

    [Fact]
    public void FutureDate_IsRejected()
    {
        Assert.Contains(NewSale(date: Today.AddDays(1)).Notifications, n => n.Key == Sale.Fields.SaleDate);
    }

    [Fact]
    public void CollectsEveryProblem()
    {
        var sale = new Sale(5, null, " ", null, 0, -1, null, null, Today);

        Assert.Equal(5, sale.Notifications.Count);
    }

    [Fact]
    public void Marketplace_NormalizesNameForComparison()
    {
        var a = new Marketplace("  mercado   livre ");
        var b = new Marketplace("Mércado Livre");

        Assert.Equal("mercado livre", a.Name);
        Assert.Equal(a.NormalizedName, b.NormalizedName);
    }
}
