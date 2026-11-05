using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Analytics;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Analytics;

internal sealed class ProductGroupsService(
    INotifier notifier,
    ISalesReportRepository reports,
    IProductClusterer clusterer,
    TimeProvider timeProvider) : SalesAnalyticsService(notifier, reports, timeProvider), IProductGroupsService
{
    public const int MinGroups = 2;
    public const int MaxGroups = 6;
    public const int MinimumProducts = 3;

    /// <summary>Error key: the query parameter.</summary>
    public const string GroupsField = "groups";

    public async Task<ProductGroupsResponse?> GroupAsync(int? groups, CancellationToken cancellationToken = default)
    {
        if (groups is < MinGroups or > MaxGroups)
        {
            Notify(GroupsField, $"Escolha de {MinGroups} a {MaxGroups} grupos.");
            return null;
        }

        var history = await LoadHistoryAsync(1, "O agrupamento", cancellationToken);
        if (history is null)
            return null;

        var products = history.Products;
        if (products.Count < MinimumProducts)
        {
            Notify($"O agrupamento precisa de pelo menos {MinimumProducts} produtos com vendas e há {products.Count}.",
                NotificationType.NotFound);
            return null;
        }

        if (groups >= products.Count)
        {
            Notify(GroupsField, $"Há {products.Count} produtos com vendas: escolha até {products.Count - 1} grupos.");
            return null;
        }

        var features = products.Select(Features).ToList();
        var points = FeatureScaling.Standardize(features);

        var tried = Enumerable.Range(MinGroups, Math.Min(MaxGroups, products.Count - 1) - MinGroups + 1)
            .Select(k =>
            {
                var labels = clusterer.Cluster(points, k);
                return (Groups: k, Labels: labels, Silhouette: Silhouette.Score(points, labels));
            })
            .ToList();

        // Automatic: the best silhouette; on a tie, fewer groups (simpler to read).
        var chosen = groups is { } wanted
            ? tried.First(t => t.Groups == wanted)
            : tried.OrderByDescending(t => t.Silhouette).ThenBy(t => t.Groups).First();

        return new ProductGroupsResponse(
            chosen.Groups,
            groups is null,
            chosen.Silhouette,
            tried.Select(t => new GroupingQuality(t.Groups, t.Silhouette)).ToList(),
            Describe(products, features, chosen.Labels),
            history.Totals(),
            history.Ignored);
    }

    /// <summary>
    /// Volume and price on a log scale (a R$ 5.000 notebook and a R$ 30 cable differ in proportion,
    /// not in reais), plus the share of months with sales.
    /// </summary>
    private static double[] Features(ProductHistory product) =>
    [
        Math.Log(1 + product.MonthlyQuantity),
        Math.Log(1 + (double)product.AveragePrice),
        product.Regularity,
    ];

    private static List<ProductGroup> Describe(
        IReadOnlyList<ProductHistory> products, IReadOnlyList<double[]> features, IReadOnlyList<int> labels)
    {
        var medianVolume = Median(features.Select(f => f[0]));
        var medianPrice = Median(features.Select(f => f[1]));
        var revenue = products.Sum(p => p.Revenue);

        var groups = products
            .Select((p, i) => (Product: p, Features: features[i], Label: labels[i]))
            .GroupBy(x => x.Label)
            .Select(g =>
            {
                var members = g.OrderByDescending(x => x.Product.Revenue)
                    .ThenBy(x => x.Product.Name, StringComparer.CurrentCulture)
                    .ToList();
                var quantity = members.Sum(x => x.Product.Quantity);
                var groupRevenue = members.Sum(x => x.Product.Revenue);
                var regularity = members.Average(x => x.Product.Regularity);
                var (name, description) = ProductGroupNames.For(
                    members.Average(x => x.Features[0]) >= medianVolume,
                    members.Average(x => x.Features[1]) >= medianPrice,
                    regularity);

                return new
                {
                    Name = name,
                    Description = description,
                    MonthlyQuantity = Math.Round(members.Average(x => x.Product.MonthlyQuantity), 2),
                    AveragePrice = quantity == 0 ? 0m : Math.Round(groupRevenue / quantity, 2),
                    Regularity = Math.Round(regularity, 4),
                    Quantity = quantity,
                    Revenue = groupRevenue,
                    Share = revenue == 0 ? 0 : Math.Round((double)(groupRevenue / revenue), 4),
                    Products = members.Select(x => new GroupedProduct(
                        x.Product.Key, x.Product.Name, x.Product.Sku, x.Product.ProductId,
                        Math.Round(x.Product.MonthlyQuantity, 2), x.Product.AveragePrice,
                        Math.Round(x.Product.Regularity, 4), x.Product.Quantity, x.Product.Revenue)).ToList(),
                };
            })
            .OrderByDescending(g => g.Revenue)
            .ThenByDescending(g => g.Quantity)
            .ToList();

        var names = ProductGroupNames.Distinct(groups.Select(g => g.Name).ToList());
        return groups
            .Select((g, i) => new ProductGroup(i + 1, names[i], g.Description, g.MonthlyQuantity, g.AveragePrice,
                g.Regularity, g.Quantity, g.Revenue, g.Share, g.Products))
            .ToList();
    }

    private static double Median(IEnumerable<double> values)
    {
        var sorted = values.Order().ToList();
        var middle = sorted.Count / 2;
        return sorted.Count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
    }
}
