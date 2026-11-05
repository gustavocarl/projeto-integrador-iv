using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Sales;
using UnivespProject.Infrastructure.MachineLearning;

namespace UnivespProject.Tests.Infrastructure;

/// <summary>The real ML.NET models, on data with an obvious answer.</summary>
public class MlNetAnalyticsTests
{
    private static List<DemandObservation> Monthly(string product, params int[] quantities) =>
        quantities.Select((q, i) => new DemandObservation(product, new SalesMonth(2026, 1).AddMonths(i), q)).ToList();

    [Fact]
    public void Forecaster_LearnsEachProductsLevel()
    {
        var history = Monthly("MUITO", 50, 52, 48, 50, 51, 49).Concat(Monthly("POUCO", 3, 2, 3, 2, 3, 2)).ToList();
        var next = new SalesMonth(2026, 7);

        var forecast = new MlNetSalesForecaster().Forecast(history, [new("MUITO", next), new("POUCO", next)]);

        Assert.InRange(forecast[0], 35, 70);
        Assert.InRange(forecast[1], 1, 6);
    }

    [Fact]
    public void Forecaster_FollowsAGrowingTrend()
    {
        var history = Monthly("CRESCE", 10, 14, 19, 26, 35, 47);

        var forecast = new MlNetSalesForecaster().Forecast(history, [new("CRESCE", new SalesMonth(2026, 7))]);

        Assert.True(forecast[0] > 40, $"previsto {forecast[0]}");
    }

    [Fact]
    public void Forecaster_IgnoresAFeatureThatNeverVaried_InsteadOfReturningNothing()
    {
        // Only January and July: the sine of the season is 0 in every training row.
        List<DemandObservation> history =
        [
            new("A", new SalesMonth(2025, 1), 10), new("A", new SalesMonth(2025, 7), 12), new("A", new SalesMonth(2026, 1), 11),
        ];

        var forecast = new MlNetSalesForecaster().Forecast(history, [new("A", new SalesMonth(2026, 9))]);

        Assert.InRange(forecast[0], 3, 40);
    }

    [Fact]
    public void Forecaster_IsTheSameEveryTime()
    {
        var history = Monthly("A", 5, 9, 4, 12).Concat(Monthly("B", 1, 0, 2, 1)).ToList();
        DemandQuery[] queries = [new("A", new SalesMonth(2026, 5)), new("B", new SalesMonth(2026, 6))];

        Assert.Equal(new MlNetSalesForecaster().Forecast(history, queries), new MlNetSalesForecaster().Forecast(history, queries));
    }

    [Fact]
    public void Clusterer_SeparatesObviousGroups_TheSameWayEveryTime()
    {
        double[][] points = [[0, 0, 0], [0.1, 0, 0], [0, 0.1, 0], [5, 5, 0], [5.1, 5, 0], [5, 5.1, 0]];

        var groups = new MlNetProductClusterer().Cluster(points, 2);

        Assert.Equal(groups[0], groups[1]);
        Assert.Equal(groups[0], groups[2]);
        Assert.Equal(groups[3], groups[4]);
        Assert.Equal(groups[3], groups[5]);
        Assert.NotEqual(groups[0], groups[3]);
        Assert.All(groups, g => Assert.InRange(g, 0, 1));
        Assert.Equal(groups, new MlNetProductClusterer().Cluster(points, 2));
    }
}
