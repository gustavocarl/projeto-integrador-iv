using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Sales;

/// <summary>
/// The spreadsheet template: sheet name and columns. Shared by the reader and the template generator.
/// </summary>
public static class SalesSpreadsheetLayout
{
    public const string SheetName = "Vendas";
    public const string InstructionsSheetName = "Instruções";
    public const string SummarySheetName = "Resumo";

    public const string Date = "Data";
    public const string Product = "Produto";
    public const string Sku = "SKU";
    public const string Quantity = "Quantidade";
    public const string UnitPrice = "Preço Unitário";
    public const string Channel = "Canal";
    public const string Marketplace = "Marketplace";

    /// <summary>Columns in template order.</summary>
    public static readonly IReadOnlyList<string> Columns = [Date, Product, Sku, Quantity, UnitPrice, Channel, Marketplace];

    /// <summary>Extra columns of the period spreadsheet, after <see cref="Columns"/> (ignored when the file is read).</summary>
    public const string Total = "Total";
    public const string Source = "Origem";
    public const string Batch = "Lote";

    /// <summary>Where a sale came from, as written in the period spreadsheet.</summary>
    public static string SourceLabel(ImportSource source) => source switch
    {
        ImportSource.Spreadsheet => "Planilha",
        ImportSource.Manual => "Manual",
        ImportSource.Store => "Caixa",
        _ => source.ToString()
    };

    /// <summary>Columns that must exist in the uploaded file (SKU and Marketplace may be left out).</summary>
    public static readonly IReadOnlyList<string> RequiredColumns = [Date, Product, Quantity, UnitPrice, Channel];

    public const long MaxFileSizeBytes = 10 * 1024 * 1024;
    public const int MaxRows = 50_000;
}
