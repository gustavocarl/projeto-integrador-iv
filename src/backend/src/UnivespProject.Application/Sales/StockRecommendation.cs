namespace UnivespProject.Application.Sales;

public enum StockAction
{
    /// <summary>Class A: most of the revenue; never let it run out.</summary>
    Prioritize,

    /// <summary>Class B, or class C that still sells many units (cheap, high turnover).</summary>
    Keep,

    /// <summary>Class C that also sells fewer units than the median product.</summary>
    ReviewRemoval,
}

/// <summary>
/// Stock suggestion from the ABC class and the units sold. Revenue alone would condemn cheap
/// products that sell a lot (cables, accessories), so a class C product is only flagged for removal
/// when it is also among the least sold in units.
/// </summary>
public static class StockRecommendation
{
    public static StockAction Recommend(AbcClass abcClass, int quantity, double medianQuantity) => abcClass switch
    {
        AbcClass.A => StockAction.Prioritize,
        AbcClass.B => StockAction.Keep,
        _ => quantity < medianQuantity ? StockAction.ReviewRemoval : StockAction.Keep,
    };

    public static double Median(IReadOnlyCollection<int> values)
    {
        if (values.Count == 0)
            return 0;

        var sorted = values.Order().ToList();
        var middle = sorted.Count / 2;
        return sorted.Count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
}
