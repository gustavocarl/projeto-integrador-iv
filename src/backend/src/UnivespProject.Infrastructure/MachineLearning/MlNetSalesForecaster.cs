using Microsoft.ML;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Sales;

namespace UnivespProject.Infrastructure.MachineLearning;

/// <summary>
/// Poisson regression (ML.NET, L-BFGS): units sold are counts, so the model predicts
/// log(expected units) = product effect + trend + season of the year. One model for every product:
/// each one has few months, but they share the trend and the season.
/// </summary>
internal sealed class MlNetSalesForecaster : ISalesForecaster
{
    /// <summary>Fixed seed: the same history always gives the same forecast.</summary>
    private const int Seed = 1;

    private const string ProductVector = "ProductVector";
    private const string Time = "Time";
    private const string Features = "Features";

    public IReadOnlyList<double> Forecast(IReadOnlyList<DemandObservation> history, IReadOnlyList<DemandQuery> queries)
    {
        if (queries.Count == 0)
            return [];

        // Months counted from the first one of the history (small numbers for the optimizer).
        var origin = history.Min(o => o.Month.Index);
        var ml = new MLContext(Seed);

        var rows = history.Select(o => DemandRow.Of(o.ProductKey, o.Month, origin, o.Quantity)).ToList();
        var questions = queries.Select(q => DemandRow.Of(q.ProductKey, q.Month, origin, 0)).ToList();
        Standardize(rows, questions);
        var training = ml.Data.LoadFromEnumerable(rows);

        var pipeline = ml.Transforms.Categorical.OneHotEncoding(ProductVector, nameof(DemandRow.Product))
            .Append(ml.Transforms.Concatenate(Time,
                nameof(DemandRow.Trend), nameof(DemandRow.SeasonSin), nameof(DemandRow.SeasonCos)))
            .Append(ml.Transforms.Concatenate(Features, ProductVector, Time))
            .Append(ml.Regression.Trainers.LbfgsPoissonRegression(
                labelColumnName: nameof(DemandRow.Label), featureColumnName: Features));

        var model = pipeline.Fit(training);
        var predictions = model.Transform(ml.Data.LoadFromEnumerable(questions));

        return ml.Data.CreateEnumerable<DemandPrediction>(predictions, reuseRowObject: false)
            .Select(p => float.IsFinite(p.Score) ? Math.Max(0d, p.Score) : 0d)
            .ToList();
    }

    /// <summary>
    /// Z-score of the time features with the training rows' mean and deviation (queries use the same ones).
    /// A feature that never varies in training (only January and July: sine always 0) becomes 0:
    /// the model learned nothing from it, and dividing by a zero deviation would give infinity.
    /// </summary>
    private static void Standardize(List<DemandRow> training, List<DemandRow> queries)
    {
        foreach (var (get, set) in new (Func<DemandRow, float> Get, Action<DemandRow, float> Set)[]
                 {
                     (r => r.Trend, (r, v) => r.Trend = v),
                     (r => r.SeasonSin, (r, v) => r.SeasonSin = v),
                     (r => r.SeasonCos, (r, v) => r.SeasonCos = v),
                 })
        {
            var mean = training.Average(get);
            var deviation = Math.Sqrt(training.Average(r => Math.Pow(get(r) - mean, 2)));
            foreach (var row in training.Concat(queries))
                set(row, deviation < 1e-6 ? 0f : (float)((get(row) - mean) / deviation));
        }
    }

    private sealed class DemandRow
    {
        public string Product { get; set; } = string.Empty;

        /// <summary>Months since the start of the history.</summary>
        public float Trend { get; set; }

        /// <summary>Month of the year on a circle: December is next to January.</summary>
        public float SeasonSin { get; set; }

        public float SeasonCos { get; set; }

        /// <summary>Units sold.</summary>
        public float Label { get; set; }

        public static DemandRow Of(string product, SalesMonth month, int origin, int quantity)
        {
            var angle = 2 * Math.PI * (month.Month - 1) / 12;
            return new DemandRow
            {
                Product = product,
                Trend = month.Index - origin,
                SeasonSin = (float)Math.Sin(angle),
                SeasonCos = (float)Math.Cos(angle),
                Label = quantity,
            };
        }
    }

    private sealed class DemandPrediction
    {
        public float Score { get; set; }
    }
}
