using UnivespProject.Application.Sales;

namespace UnivespProject.Application.Abstractions;

/// <summary>Units of a product sold in a month: the training data of the forecast.</summary>
/// <param name="ProductKey">The product's identity (<see cref="ProductMonthTotals.Key"/>).</param>
public sealed record DemandObservation(string ProductKey, SalesMonth Month, int Quantity);

/// <summary>A product and a month whose sales are to be predicted.</summary>
public sealed record DemandQuery(string ProductKey, SalesMonth Month);

/// <summary>
/// Learns how many units each product sells per month (product, trend and season of the year)
/// and predicts future months. Implemented with ML.NET in the Infrastructure.
/// </summary>
public interface ISalesForecaster
{
    /// <returns>The expected units of each query, in the same order; never negative.</returns>
    IReadOnlyList<double> Forecast(IReadOnlyList<DemandObservation> history, IReadOnlyList<DemandQuery> queries);
}
