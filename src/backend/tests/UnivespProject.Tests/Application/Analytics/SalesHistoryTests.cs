using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Analytics;
using UnivespProject.Application.Sales;

namespace UnivespProject.Tests.Application.Analytics;

public class SalesHistoryTests
{
    private static readonly DateOnly Today = new(2026, 11, 2);

    [Fact]
    public void LeavesOut_TheCurrentMonth_AndMonthsRecordedOnLessThanHalfOfTheDays()
    {
        var history = SalesHistory.Build(
            [
                new ProductMonthTotals(2026, 9, "Mouse", "MOU", null, 10, 100m),
                new ProductMonthTotals(2026, 10, "Mouse", "MOU", null, 2, 20m),
                new ProductMonthTotals(2026, 11, "Mouse", "MOU", null, 1, 10m),
            ],
            [new MonthActivity(2026, 9, 15), new MonthActivity(2026, 10, 15), new MonthActivity(2026, 11, 2)],
            Today);

        // September: 15 of 30 days (half) counts; October: 15 of 31 does not.
        Assert.Equal([new SalesMonth(2026, 9)], history.Months);
        Assert.Equal(
            [
                ("2026-10", "Vendas em só 15 de 31 dias: parece um mês registrado pela metade."),
                ("2026-11", "Mês em andamento: ainda não terminou."),
            ],
            history.Ignored.Select(i => (i.Month, i.Reason)));
        Assert.Equal([10], history.Products.Single().Quantities);
    }

    [Fact]
    public void MergesSpellings_PutsZeroWhereAProductDidNotSell_AndUsesTheLatestPrice()
    {
        var catalogId = Guid.NewGuid();
        var history = SalesHistory.Build(
            [
                new ProductMonthTotals(2026, 1, "Mouse sem fio", "mou-1", null, 2, 100m),
                new ProductMonthTotals(2026, 1, "Mouse Sem Fio", "MOU-1", catalogId, 5, 250m),
                new ProductMonthTotals(2026, 3, "Mouse Sem Fio", "MOU-1", catalogId, 4, 240m),
                new ProductMonthTotals(2026, 3, "Cabo", null, null, 3, 30m),
            ],
            [new MonthActivity(2026, 1, 31), new MonthActivity(2026, 2, 28), new MonthActivity(2026, 3, 31)],
            Today);

        Assert.Equal(3, history.Months.Count);
        var mouse = history.Products.Single(p => p.Key == "MOU-1");
        Assert.Equal(("Mouse Sem Fio", "MOU-1", catalogId), (mouse.Name, mouse.Sku, mouse.ProductId));
        Assert.Equal([7, 0, 4], mouse.Quantities);
        Assert.Equal(60m, mouse.LatestPrice);
        Assert.Equal(2d / 3, mouse.Regularity, 6);
        Assert.Equal(11d / 3, mouse.MonthlyQuantity, 6);

        Assert.Equal([0, 0, 3], history.Products.Single(p => p.Key == "CABO").Quantities);
        Assert.Equal([7, 0, 7], history.Totals().Select(t => t.Quantity));
    }

    [Fact]
    public void WithoutLastMonth_DropsProductsSoldOnlyInIt()
    {
        var history = SalesHistory.Build(
            [
                new ProductMonthTotals(2026, 1, "Mouse", "MOU", null, 2, 20m),
                new ProductMonthTotals(2026, 2, "Mouse", "MOU", null, 3, 30m),
                new ProductMonthTotals(2026, 2, "Cabo", "CAB", null, 1, 10m),
            ],
            [new MonthActivity(2026, 1, 31), new MonthActivity(2026, 2, 28)],
            Today);

        var training = history.WithoutLastMonth();

        Assert.Equal([new SalesMonth(2026, 1)], training.Months);
        Assert.Equal(["MOU"], training.Products.Select(p => p.Key));
        Assert.Equal([2], training.Products[0].Quantities);
    }
}
