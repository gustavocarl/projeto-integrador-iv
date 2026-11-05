namespace UnivespProject.Application.Abstractions;

/// <summary>
/// Splits points into groups of similar ones (k-means). Implemented with ML.NET in the Infrastructure.
/// </summary>
public interface IProductClusterer
{
    /// <param name="points">One row per product, every row with the same features, already on the same scale.</param>
    /// <param name="groups">How many groups to form (at least 2, less than the number of points).</param>
    /// <returns>The group of each point, from 0 to <paramref name="groups"/> - 1, in the same order.</returns>
    IReadOnlyList<int> Cluster(IReadOnlyList<double[]> points, int groups);
}
