using UnivespProject.Application.Sales;

namespace UnivespProject.Tests.Application.Sales;

public class AbcCurveTests
{
    [Fact]
    public void ClassifiesByTheShareAccumulatedBeforeEachProduct()
    {
        // Shares: 50, 25, 10, 5, 4, 3, 2, 1 (%). Accumulated before: 0, 50, 75, 85, 90, 94, 97, 99.
        var classes = AbcCurve.Classify([50m, 25m, 10m, 5m, 4m, 3m, 2m, 1m]);

        Assert.Equal(
            [AbcClass.A, AbcClass.A, AbcClass.A, AbcClass.B, AbcClass.B, AbcClass.B, AbcClass.C, AbcClass.C],
            classes);
    }

    [Fact]
    public void TopSeller_IsAlwaysA_EvenWhenItAloneExceeds80Percent()
    {
        Assert.Equal([AbcClass.A, AbcClass.B, AbcClass.C], AbcCurve.Classify([90m, 6m, 4m]));
    }

    [Fact]
    public void WithoutRevenue_EverythingIsC()
    {
        Assert.Equal([AbcClass.C, AbcClass.C], AbcCurve.Classify([0m, 0m]));
    }

    [Fact]
    public void Empty_ReturnsEmpty()
    {
        Assert.Empty(AbcCurve.Classify([]));
    }
}
