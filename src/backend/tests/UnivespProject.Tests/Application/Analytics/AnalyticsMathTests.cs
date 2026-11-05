using UnivespProject.Application.Analytics;

namespace UnivespProject.Tests.Application.Analytics;

public class AnalyticsMathTests
{
    [Fact]
    public void Standardize_GivesEachColumnMeanZeroAndDeviationOne_AndZerosAConstantColumn()
    {
        var scaled = FeatureScaling.Standardize([[1, 5], [3, 5], [5, 5]]);

        Assert.Equal([-1.224745, 0, 1.224745], scaled.Select(r => Math.Round(r[0], 6)));
        Assert.All(scaled, r => Assert.Equal(0, r[1]));
    }

    [Fact]
    public void Silhouette_IsNearOne_ForSeparatedGroups_AndLowWhenTheyOverlap()
    {
        double[][] points = [[0, 0], [0, 1], [10, 0], [10, 1]];

        Assert.True(Silhouette.Score(points, [0, 0, 1, 1]) > 0.9);
        Assert.True(Silhouette.Score(points, [0, 1, 0, 1]) < 0);
        Assert.Equal(0, Silhouette.Score(points, [0, 0, 0, 0]));
    }

    [Theory]
    [InlineData(true, true, "Carros-chefe")]
    [InlineData(true, false, "Alto giro")]
    [InlineData(false, true, "Alto valor, baixo giro")]
    [InlineData(false, false, "Baixo giro")]
    public void GroupNames_FollowVolumeAndPrice(bool highVolume, bool highPrice, string name)
    {
        var (actual, description) = ProductGroupNames.For(highVolume, highPrice, 1);

        Assert.Equal(name, actual);
        Assert.DoesNotContain("irregulares", description);
    }

    [Fact]
    public void GroupNames_WarnAboutIrregularSales_AndNumberRepeatedNames()
    {
        Assert.EndsWith("Vendas irregulares: aparecem em 25% dos meses.", ProductGroupNames.For(false, false, 0.25).Description);
        Assert.Equal(["Alto giro", "Baixo giro", "Alto giro 2"], ProductGroupNames.Distinct(["Alto giro", "Baixo giro", "Alto giro"]));
    }
}
