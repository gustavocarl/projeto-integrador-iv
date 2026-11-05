namespace UnivespProject.Application.Sales;

public enum AbcClass
{
    A,
    B,
    C,
}

/// <summary>
/// ABC curve (Pareto) by revenue, used to decide what to keep in stock:
/// A = the products that make the first 80% of the revenue, B = the next 15%, C = the last 5%.
/// </summary>
public static class AbcCurve
{
    public const decimal ClassALimit = 0.80m;
    public const decimal ClassBLimit = 0.95m;

    /// <summary>
    /// Classifies revenues already sorted from highest to lowest; the result keeps the same order.
    /// A product is classified by the share accumulated before it, so the top seller is always A.
    /// </summary>
    public static IReadOnlyList<AbcClass> Classify(IReadOnlyList<decimal> sortedRevenues)
    {
        var total = sortedRevenues.Sum();
        if (total <= 0)
            return sortedRevenues.Select(_ => AbcClass.C).ToList();

        var result = new List<AbcClass>(sortedRevenues.Count);
        var accumulated = 0m;
        foreach (var revenue in sortedRevenues)
        {
            var shareBefore = accumulated / total;
            result.Add(shareBefore < ClassALimit ? AbcClass.A : shareBefore < ClassBLimit ? AbcClass.B : AbcClass.C);
            accumulated += revenue;
        }

        return result;
    }
}
