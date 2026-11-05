using UnivespProject.Application.Sales;

namespace UnivespProject.Tests.Application.Sales;

public class StockRecommendationTests
{
    [Theory]
    [InlineData(AbcClass.A, 1, StockAction.Prioritize)]
    [InlineData(AbcClass.B, 1, StockAction.Keep)]
    [InlineData(AbcClass.C, 20, StockAction.Keep)]          // cheap but sells a lot
    [InlineData(AbcClass.C, 10, StockAction.Keep)]          // exactly the median
    [InlineData(AbcClass.C, 3, StockAction.ReviewRemoval)]
    public void Recommends_ByClassAndUnitsSold(AbcClass abcClass, int quantity, StockAction expected)
    {
        Assert.Equal(expected, StockRecommendation.Recommend(abcClass, quantity, medianQuantity: 10));
    }

    [Theory]
    [InlineData(new[] { 5, 1, 3 }, 3.0)]
    [InlineData(new[] { 4, 1, 3, 2 }, 2.5)]
    [InlineData(new int[0], 0.0)]
    public void Median(int[] values, double expected)
    {
        Assert.Equal(expected, StockRecommendation.Median(values));
    }
}
