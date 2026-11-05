namespace UnivespProject.Application.Analytics;

/// <summary>Puts every feature on the same scale so none dominates the distances of the k-means.</summary>
internal static class FeatureScaling
{
    /// <summary>
    /// Z-score per column: (value - mean) / standard deviation.
    /// A column where every row is equal carries no information and becomes 0.
    /// </summary>
    public static List<double[]> Standardize(IReadOnlyList<double[]> rows)
    {
        if (rows.Count == 0)
            return [];

        var columns = rows[0].Length;
        var means = new double[columns];
        var deviations = new double[columns];
        for (var c = 0; c < columns; c++)
        {
            var column = c;
            means[c] = rows.Average(r => r[column]);
            deviations[c] = Math.Sqrt(rows.Average(r => Math.Pow(r[column] - means[column], 2)));
        }

        return rows
            .Select(r => r.Select((v, c) => deviations[c] < 1e-12 ? 0d : (v - means[c]) / deviations[c]).ToArray())
            .ToList();
    }
}
