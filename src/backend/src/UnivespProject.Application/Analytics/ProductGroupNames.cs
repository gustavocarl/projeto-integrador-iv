namespace UnivespProject.Application.Analytics;

/// <summary>
/// Names a group by where its center falls compared with the median product:
/// volume (units per month) and price, the two features a store owner reads at a glance.
/// </summary>
internal static class ProductGroupNames
{
    /// <summary>Below this share of months with sales, the description warns that sales are irregular.</summary>
    public const double IrregularBelow = 0.5;

    public static (string Name, string Description) For(bool highVolume, bool highPrice, double regularity)
    {
        var (name, description) = (highVolume, highPrice) switch
        {
            (true, true) => ("Carros-chefe",
                "Vendem bem e têm preço alto: sustentam o faturamento. Evite que faltem no estoque."),
            (true, false) => ("Alto giro",
                "Vendem muito e custam pouco: reponha com frequência."),
            (false, true) => ("Alto valor, baixo giro",
                "Vendem pouco, mas cada venda vale muito: mantenha um estoque enxuto."),
            (false, false) => ("Baixo giro",
                "Vendem pouco e custam pouco: avalie se vale manter no catálogo."),
        };

        if (regularity < IrregularBelow)
            description += $" Vendas irregulares: aparecem em {Math.Round(regularity * 100)}% dos meses.";

        return (name, description);
    }

    /// <summary>Numbers repeated names in order ("Alto giro", "Alto giro 2").</summary>
    public static List<string> Distinct(IReadOnlyList<string> names)
    {
        var seen = new Dictionary<string, int>();
        return names
            .Select(n =>
            {
                var count = seen[n] = seen.GetValueOrDefault(n) + 1;
                return count == 1 ? n : $"{n} {count}";
            })
            .ToList();
    }
}
