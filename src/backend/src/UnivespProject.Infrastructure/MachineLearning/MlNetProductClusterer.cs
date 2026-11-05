using Microsoft.ML;
using Microsoft.ML.Data;
using Microsoft.ML.Trainers;
using UnivespProject.Application.Abstractions;

namespace UnivespProject.Infrastructure.MachineLearning;

/// <summary>K-means (ML.NET) with k-means++ starting points.</summary>
internal sealed class MlNetProductClusterer : IProductClusterer
{
    /// <summary>Fixed seed and one thread: the same products always form the same groups.</summary>
    private const int Seed = 1;

    public IReadOnlyList<int> Cluster(IReadOnlyList<double[]> points, int groups)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(groups, 2);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(groups, points.Count);

        var ml = new MLContext(Seed);

        // The vector size is only known now: the schema says it so k-means accepts the column.
        var schema = SchemaDefinition.Create(typeof(Point));
        schema[nameof(Point.Features)].ColumnType = new VectorDataViewType(NumberDataViewType.Single, points[0].Length);
        var data = ml.Data.LoadFromEnumerable(
            points.Select(p => new Point { Features = p.Select(v => (float)v).ToArray() }), schema);

        var trainer = ml.Clustering.Trainers.KMeans(new KMeansTrainer.Options
        {
            FeatureColumnName = nameof(Point.Features),
            NumberOfClusters = groups,
            InitializationAlgorithm = KMeansTrainer.InitializationAlgorithm.KMeansPlusPlus,
            NumberOfThreads = 1,
        });

        var assigned = trainer.Fit(data).Transform(data);

        // PredictedLabel is 1-based.
        return assigned.GetColumn<uint>("PredictedLabel").Select(label => (int)label - 1).ToList();
    }

    private sealed class Point
    {
        public float[] Features { get; set; } = [];
    }
}
