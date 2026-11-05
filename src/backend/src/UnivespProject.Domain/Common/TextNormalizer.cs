using System.Globalization;
using System.Text;

namespace UnivespProject.Domain.Common;

public static class TextNormalizer
{
    /// <summary>
    /// Trims and collapses repeated spaces: "  Mercado   Livre " → "Mercado Livre".
    /// </summary>
    public static string CollapseSpaces(string value) =>
        string.Join(' ', value.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

    /// <summary>
    /// Comparison key: no accents, upper case, single spaces. "mercado  livre" and "Mercado Livre" become "MERCADO LIVRE".
    /// </summary>
    public static string ToKey(string value)
    {
        var decomposed = CollapseSpaces(value).Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                builder.Append(c);
        }

        return builder.ToString().Normalize(NormalizationForm.FormC).ToUpperInvariant();
    }
}
