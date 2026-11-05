using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Analytics;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;

namespace UnivespProject.Application.Analytics;

internal sealed class SalesForecastService(
    INotifier notifier,
    ISalesReportRepository reports,
    IProductRepository products,
    ISalesForecaster forecaster,
    TimeProvider timeProvider) : SalesAnalyticsService(notifier, reports, timeProvider), ISalesForecastService
{
    public const int DefaultMonths = 3;
    public const int MaxMonths = 6;

    /// <summary>Complete months needed: the model must see the same product more than once to find a trend.</summary>
    public const int MinimumHistory = 3;

    /// <summary>Error key: the query parameter.</summary>
    public const string MonthsField = "months";

    public async Task<SalesForecastResponse?> ForecastAsync(int? months, CancellationToken cancellationToken = default)
    {
        var horizon = months ?? DefaultMonths;
        if (horizon is < 1 or > MaxMonths)
        {
            Notify(MonthsField, $"Escolha de 1 a {MaxMonths} meses.");
            return null;
        }

        var history = await LoadHistoryAsync(MinimumHistory, "A previsão", cancellationToken);
        if (history is null)
            return null;

        var targets = Enumerable.Range(1, horizon).Select(history.CurrentMonth.AddMonths).ToList();

        var ids = history.Products.Where(p => p.ProductId is not null).Select(p => p.ProductId!.Value).ToList();
        var catalog = (await products.GetByIdsAsync(ids, cancellationToken)).ToDictionary(p => p.Id);

        // Deactivated products are no longer sold: they teach the model, but are not predicted.
        var predicted = history.Products
            .Where(p => p.ProductId is not { } id || !catalog.TryGetValue(id, out var product) || product.IsActive)
            .ToList();

        var queries = predicted.SelectMany(p => targets.Select(m => new DemandQuery(p.Key, m))).ToList();
        var units = forecaster.Forecast(Observations(history), queries);

        var rows = predicted
            .Select((p, i) =>
            {
                var quantities = Enumerable.Range(0, targets.Count)
                    .Select(m => Units(units[i * targets.Count + m]))
                    .ToList();
                var quantity = quantities.Sum();
                var price = p.LatestPrice;
                var product = p.ProductId is { } id ? catalog.GetValueOrDefault(id) : null;

                return new ProductForecast(p.Key, p.Name, p.Sku, p.ProductId, price, quantities, quantity,
                    price * quantity, product?.StockQuantity, product?.MinimumStock,
                    product is null ? null : Math.Max(0, quantity + product.MinimumStock - product.StockQuantity));
            })
            .OrderByDescending(r => r.Revenue)
            .ThenByDescending(r => r.Quantity)
            .ThenBy(r => r.Name, StringComparer.CurrentCulture)
            .ToList();

        var totals = targets
            .Select((m, i) => new MonthTotal(m.ToString(), m.Label,
                rows.Sum(r => r.Quantities[i]), rows.Sum(r => r.Price * r.Quantities[i])))
            .ToList();

        return new SalesForecastResponse(history.Totals(), totals, rows, Validate(history), history.Ignored);
    }

    /// <summary>Predicted units are whole: half a notebook is not sold.</summary>
    private static int Units(double value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);

    private static List<DemandObservation> Observations(SalesHistory history) =>
        history.Products
            .SelectMany(p => history.Months.Select((m, i) => new DemandObservation(p.Key, m, p.Quantities[i])))
            .ToList();

    /// <summary>
    /// Trains without the last month, predicts it and compares with what was sold,
    /// side by side with the simple guess (each product's average of the previous months).
    /// </summary>
    private ForecastValidation? Validate(SalesHistory history)
    {
        if (history.Months.Count < MinimumHistory)
            return null;

        var tested = history.Months[^1];
        var training = history.WithoutLastMonth();
        var previous = training.Products.ToDictionary(p => p.Key);

        var actual = history.Products.Select(p => p.Quantities[^1]).ToList();
        var total = actual.Sum();
        if (total == 0)
            return null;

        var predicted = forecaster
            .Forecast(Observations(training), history.Products.Select(p => new DemandQuery(p.Key, tested)).ToList())
            .Select(Units)
            .ToList();
        var baseline = history.Products
            .Select(p => previous.TryGetValue(p.Key, out var before) ? Units(before.MonthlyQuantity) : 0)
            .ToList();

        static double Error(IReadOnlyList<int> guess, IReadOnlyList<int> sold, int total) =>
            Math.Round(guess.Zip(sold, (g, s) => (double)Math.Abs(g - s)).Sum() / total, 4);

        return new ForecastValidation(tested.ToString(), tested.Label, total, predicted.Sum(), baseline.Sum(),
            Error(predicted, actual, total), Error(baseline, actual, total));
    }
}
