using System.Globalization;
using UnivespProject.Domain.Common;

namespace UnivespProject.Application.Sales;

/// <summary>A calendar month, written "2026-01" in the API.</summary>
public readonly record struct SalesMonth(int Year, int Month)
{
    public DateOnly Start => new(Year, Month, 1);
    public DateOnly End => Start.AddMonths(1).AddDays(-1);
    public int Days => DateTime.DaysInMonth(Year, Month);

    /// <summary>"janeiro/2026".</summary>
    public string Label => MonthNames.Label(Year, Month);

    /// <summary>Months since year 0: consecutive months have consecutive indexes.</summary>
    public int Index => Year * 12 + Month - 1;

    public SalesMonth AddMonths(int months) => Of(Start.AddMonths(months));

    public static SalesMonth Of(DateOnly date) => new(date.Year, date.Month);

    /// <summary>Accepts "2026-01" (also "2026-1").</summary>
    public static bool TryParse(string? value, out SalesMonth month)
    {
        month = default;
        var parts = value?.Trim().Split('-');
        if (parts is not { Length: 2 }
            || !int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var year)
            || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var number)
            || year is < 1 or > 9999 || number is < 1 or > 12)
            return false;

        month = new SalesMonth(year, number);
        return true;
    }

    public override string ToString() => $"{Year:D4}-{Month:D2}";
}
