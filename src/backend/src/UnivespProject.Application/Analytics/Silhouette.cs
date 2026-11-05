namespace UnivespProject.Application.Analytics;

/// <summary>
/// How well points fit their groups, from -1 to 1: for each point, (b - a) / max(a, b), where
/// a = mean distance to its own group and b = mean distance to the nearest other group.
/// Near 1 = compact, well separated groups; near 0 = groups that overlap.
/// </summary>
internal static class Silhouette
{
    public static double Score(IReadOnlyList<double[]> points, IReadOnlyList<int> groups)
    {
        if (points.Count < 2 || groups.Distinct().Count() < 2)
            return 0;

        var total = 0d;
        for (var i = 0; i < points.Count; i++)
        {
            var distances = Enumerable.Range(0, points.Count)
                .Where(j => j != i)
                .GroupBy(j => groups[j])
                .ToDictionary(g => g.Key, g => g.Average(j => Distance(points[i], points[j])));

            // A point alone in its group scores 0 by convention.
            if (!distances.TryGetValue(groups[i], out var own))
                continue;

            var others = distances.Where(d => d.Key != groups[i]).Select(d => d.Value).ToList();
            if (others.Count == 0)
                continue;

            var nearest = others.Min();
            var larger = Math.Max(own, nearest);
            total += larger == 0 ? 0 : (nearest - own) / larger;
        }

        return Math.Round(total / points.Count, 4);
    }

    private static double Distance(double[] a, double[] b) =>
        Math.Sqrt(a.Zip(b, (x, y) => (x - y) * (x - y)).Sum());
}
