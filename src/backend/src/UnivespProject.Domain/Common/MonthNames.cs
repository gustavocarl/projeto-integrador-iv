namespace UnivespProject.Domain.Common;

/// <summary>Portuguese month names, fixed so labels don't depend on the server's culture.</summary>
public static class MonthNames
{
    private static readonly string[] Names =
    [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"
    ];

    /// <summary>"outubro/2026".</summary>
    public static string Label(int year, int month) => $"{Names[month - 1]}/{year}";
}
