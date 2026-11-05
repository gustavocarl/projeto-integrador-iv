using UnivespProject.Domain.Common;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A sales spreadsheet the user generated (every sale of a period). The file is kept as it was
/// generated, so it can be downloaded again. It is a record of the file, not a batch: its sales are
/// already in the system and are never imported again from it.
/// </summary>
public sealed class SalesExport : StoreOwnedEntity
{
    public const int FileNameMaxLength = 100;
    public const int PeriodLabelMaxLength = 60;

    public string FileName { get; private set; } = string.Empty;
    public DateOnly PeriodStart { get; private set; }
    public DateOnly PeriodEnd { get; private set; }

    /// <summary>"05/11/2026", "novembro/2026" or "02/11/2026 a 08/11/2026".</summary>
    public string PeriodLabel { get; private set; } = string.Empty;

    public int SalesCount { get; private set; }
    public decimal TotalRevenue { get; private set; }

    /// <summary>The .xlsx file.</summary>
    public byte[] Content { get; private set; } = [];

    // Required by Entity Framework.
    private SalesExport() { }

    public SalesExport(string fileName, DateOnly periodStart, DateOnly periodEnd, string periodLabel,
        int salesCount, decimal totalRevenue, byte[] content)
    {
        FileName = fileName;
        PeriodStart = periodStart;
        PeriodEnd = periodEnd;
        PeriodLabel = periodLabel;
        SalesCount = salesCount;
        TotalRevenue = totalRevenue;
        Content = content;
    }
}
