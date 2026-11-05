using UnivespProject.Application.Sales;

namespace UnivespProject.Application.Abstractions;

/// <summary>
/// A data row read from the spreadsheet. Values are already typed; a cell that could not be
/// converted is null and its problem is in <see cref="CellErrors"/>, keyed by the field
/// (<see cref="Domain.Entities.Sale.Fields"/>).
/// </summary>
public sealed record SalesSheetRow(
    int RowNumber,
    DateOnly? Date,
    string? Product,
    string? Sku,
    int? Quantity,
    decimal? UnitPrice,
    string? Channel,
    string? Marketplace,
    IReadOnlyDictionary<string, string> CellErrors);

/// <param name="Rows">Non-empty data rows.</param>
/// <param name="Errors">File-level problems (unreadable file, missing columns). When present, rows are empty.</param>
public sealed record SalesSheetReadResult(IReadOnlyList<SalesSheetRow> Rows, IReadOnlyList<string> Errors);

/// <summary>Every sale of a period, for the period spreadsheet.</summary>
/// <param name="PeriodLabel">"05/11/2026", "novembro/2026" or "01/11/2026 a 07/11/2026".</param>
/// <param name="Font">Default font of the workbook (the user's operating system).</param>
public sealed record SalesPeriodSheet(string PeriodLabel, IReadOnlyList<SaleLine> Sales, SpreadsheetFont Font);

/// <summary>
/// Reads uploaded sales spreadsheets and builds the template users fill in.
/// </summary>
public interface ISalesSpreadsheet
{
    SalesSheetReadResult Read(Stream content);

    /// <param name="font">Default font of the workbook (the user's operating system).</param>
    byte[] CreateTemplate(SpreadsheetFont font);

    /// <summary>
    /// The period's sales in the template layout (the file can be read back) plus total, origin and
    /// batch columns, and a summary sheet.
    /// </summary>
    byte[] CreatePeriodSheet(SalesPeriodSheet sheet);
}
