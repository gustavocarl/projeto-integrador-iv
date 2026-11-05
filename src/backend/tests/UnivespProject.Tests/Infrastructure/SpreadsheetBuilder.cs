using ClosedXML.Excel;

namespace UnivespProject.Tests.Infrastructure;

/// <summary>Builds .xlsx files in memory for tests.</summary>
internal static class SpreadsheetBuilder
{
    public static readonly string[] TemplateHeader = ["Data", "Produto", "SKU", "Quantidade", "Preço Unitário", "Canal", "Marketplace"];

    public static MemoryStream Build(object?[] header, params object?[][] rows) => Build("Vendas", header, rows);

    public static MemoryStream Build(string sheetName, object?[] header, params object?[][] rows)
    {
        using var workbook = new XLWorkbook();
        var sheet = workbook.AddWorksheet(sheetName);

        object?[][] all = [header, .. rows];
        for (var r = 0; r < all.Length; r++)
        for (var c = 0; c < all[r].Length; c++)
            sheet.Cell(r + 1, c + 1).Value = XLCellValue.FromObject(all[r][c]);

        var stream = new MemoryStream();
        workbook.SaveAs(stream);
        stream.Position = 0;
        return stream;
    }
}
