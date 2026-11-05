using System.Globalization;
using ClosedXML.Excel;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;
using Layout = UnivespProject.Application.Sales.SalesSpreadsheetLayout;

namespace UnivespProject.Infrastructure.Spreadsheets;

/// <summary>
/// Reads and writes the sales spreadsheet (.xlsx) with ClosedXML.
/// Only converts cells to types; business rules stay in the domain.
/// </summary>
internal sealed class ClosedXmlSalesSpreadsheet : ISalesSpreadsheet
{
    private static readonly CultureInfo PtBr = CultureInfo.GetCultureInfo("pt-BR");
    private static readonly string[] DateFormats = ["dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "yyyy-MM-dd"];

    /// <summary>Accepted header names (compared without case/accents) for each template column.</summary>
    private static readonly Dictionary<string, string> HeaderAliases = new()
    {
        ["DATA"] = Layout.Date,
        ["DATA DA VENDA"] = Layout.Date,
        ["PRODUTO"] = Layout.Product,
        ["SKU"] = Layout.Sku,
        ["CODIGO"] = Layout.Sku,
        ["QUANTIDADE"] = Layout.Quantity,
        ["QTD"] = Layout.Quantity,
        ["PRECO UNITARIO"] = Layout.UnitPrice,
        ["VALOR UNITARIO"] = Layout.UnitPrice,
        ["PRECO"] = Layout.UnitPrice,
        ["CANAL"] = Layout.Channel,
        ["MARKETPLACE"] = Layout.Marketplace
    };

    public SalesSheetReadResult Read(Stream content)
    {
        XLWorkbook workbook;
        try
        {
            workbook = new XLWorkbook(content);
        }
        catch (Exception)
        {
            return Failed("Não foi possível ler a planilha. Verifique se é um arquivo .xlsx válido.");
        }

        using (workbook)
        {
            var sheet = workbook.Worksheets.FirstOrDefault(w => TextNormalizer.ToKey(w.Name) == TextNormalizer.ToKey(Layout.SheetName))
                        ?? workbook.Worksheets.FirstOrDefault();
            var headerRow = sheet?.FirstRowUsed();
            if (sheet is null || headerRow is null)
                return Failed("A planilha está vazia. Use o modelo e preencha a aba \"Vendas\".");

            var columns = MapColumns(headerRow);
            var missing = Layout.RequiredColumns.Where(c => !columns.ContainsKey(c)).ToList();
            if (missing.Count > 0)
                return Failed($"Coluna(s) obrigatória(s) não encontrada(s) na primeira linha: {string.Join(", ", missing)}. Use o modelo de planilha.");

            var rows = new List<SalesSheetRow>();
            var lastRow = sheet.LastRowUsed()!.RowNumber();
            for (var number = headerRow.RowNumber() + 1; number <= lastRow; number++)
            {
                var row = ReadRow(sheet.Row(number), columns);
                if (row is not null)
                    rows.Add(row);
            }

            return new SalesSheetReadResult(rows, []);
        }
    }

    public byte[] CreateTemplate(SpreadsheetFont font)
    {
        using var workbook = NewWorkbook(font);

        var sheet = AddSalesSheet(workbook, Layout.Columns);
        const int lastFormattedRow = 5001;
        FormatSalesColumns(sheet, lastFormattedRow);
        sheet.Range(2, ColumnOf(Layout.Channel), lastFormattedRow, ColumnOf(Layout.Channel))
            .CreateDataValidation()
            .List($"\"{SalesChannelParser.InPersonLabel},{SalesChannelParser.OnlineLabel}\"", true);

        AddInstructions(workbook.AddWorksheet(Layout.InstructionsSheetName));
        return Save(workbook);
    }

    public byte[] CreatePeriodSheet(SalesPeriodSheet period)
    {
        using var workbook = NewWorkbook(period.Font);

        // The template columns first (the file can be imported elsewhere), then the extra ones.
        string[] columns = [.. Layout.Columns, Layout.Total, Layout.Source, Layout.Batch];
        var sheet = AddSalesSheet(workbook, columns);
        for (var i = 0; i < period.Sales.Count; i++)
        {
            var sale = period.Sales[i];
            object?[] values =
            [
                sale.Date.ToDateTime(TimeOnly.MinValue), sale.ProductName, sale.Sku, sale.Quantity, sale.UnitPrice,
                SalesChannelParser.Label(sale.Channel), sale.Marketplace, sale.TotalPrice,
                Layout.SourceLabel(sale.Source), sale.BatchName
            ];
            for (var c = 0; c < values.Length; c++)
                sheet.Cell(i + 2, c + 1).Value = XLCellValue.FromObject(values[c]);
        }

        var lastRow = Math.Max(period.Sales.Count + 1, 2);
        FormatSalesColumns(sheet, lastRow);
        sheet.Range(2, columns.Length - 2, lastRow, columns.Length - 2).Style.NumberFormat.Format = MoneyFormat;
        sheet.Column(columns.Length - 2).Width = 16;
        sheet.Column(columns.Length - 1).Width = 12;
        sheet.Column(columns.Length).Width = 34;
        sheet.Range(1, 1, lastRow, columns.Length).SetAutoFilter();

        AddSummary(workbook.AddWorksheet(Layout.SummarySheetName), period);
        return Save(workbook);
    }

    private const string MoneyFormat = "#,##0.00";

    /// <summary>A workbook whose default style (every cell, the "Normal" style) uses <paramref name="font"/>.</summary>
    private static XLWorkbook NewWorkbook(SpreadsheetFont font)
    {
        var workbook = new XLWorkbook();
        workbook.Style.Font.FontName = font.Name;
        workbook.Style.Font.FontSize = font.Size;
        return workbook;
    }

    /// <summary>The "Vendas" sheet with a styled, frozen header row.</summary>
    private static IXLWorksheet AddSalesSheet(XLWorkbook workbook, IReadOnlyList<string> columns)
    {
        var sheet = workbook.AddWorksheet(Layout.SheetName);
        for (var i = 0; i < columns.Count; i++)
            sheet.Cell(1, i + 1).Value = columns[i];

        var header = sheet.Range(1, 1, 1, columns.Count);
        header.Style.Font.Bold = true;
        header.Style.Font.FontColor = XLColor.White;
        header.Style.Fill.BackgroundColor = XLColor.FromHtml("#3F51B5");
        sheet.SheetView.FreezeRows(1);
        return sheet;
    }

    /// <summary>Formats and widths of the template columns, from row 2 to <paramref name="lastRow"/>.</summary>
    private static void FormatSalesColumns(IXLWorksheet sheet, int lastRow)
    {
        sheet.Range(2, ColumnOf(Layout.Date), lastRow, ColumnOf(Layout.Date)).Style.DateFormat.Format = "dd/mm/yyyy";
        sheet.Range(2, ColumnOf(Layout.Quantity), lastRow, ColumnOf(Layout.Quantity)).Style.NumberFormat.Format = "0";
        sheet.Range(2, ColumnOf(Layout.UnitPrice), lastRow, ColumnOf(Layout.UnitPrice)).Style.NumberFormat.Format = MoneyFormat;

        foreach (var (column, width) in new[] { (Layout.Date, 12), (Layout.Product, 40), (Layout.Sku, 16), (Layout.Quantity, 12), (Layout.UnitPrice, 16), (Layout.Channel, 14), (Layout.Marketplace, 22) })
            sheet.Column(ColumnOf(column)).Width = width;
    }

    /// <summary>Period totals, then totals by origin and by channel.</summary>
    private static void AddSummary(IXLWorksheet sheet, SalesPeriodSheet period)
    {
        sheet.Cell(1, 1).Value = $"Vendas de {period.PeriodLabel}";
        sheet.Cell(1, 1).Style.Font.Bold = true;
        sheet.Cell(1, 1).Style.Font.FontSize = 14;

        var row = 3;
        foreach (var (label, value, money) in new (string, decimal, bool)[]
                 {
                     ("Vendas", period.Sales.Count, false),
                     ("Itens", period.Sales.Sum(s => s.Quantity), false),
                     ("Faturamento", period.Sales.Sum(s => s.TotalPrice), true)
                 })
        {
            sheet.Cell(row, 1).Value = label;
            sheet.Cell(row, 1).Style.Font.Bold = true;
            sheet.Cell(row, 2).Value = value;
            sheet.Cell(row, 2).Style.NumberFormat.Format = money ? MoneyFormat : "0";
            row++;
        }

        row = AddGroup(sheet, row + 1, Layout.Source, period.Sales.GroupBy(s => Layout.SourceLabel(s.Source)));
        row = AddGroup(sheet, row + 1, Layout.Channel, period.Sales.GroupBy(s => SalesChannelParser.Label(s.Channel)));

        sheet.Cell(row + 1, 1).Value =
            "A aba \"Vendas\" segue o modelo de importação. Importar este arquivo no sistema duplica as vendas que já estão lá.";
        sheet.Cell(row + 1, 1).Style.Font.Italic = true;
        sheet.Column(1).Width = 16;
        sheet.Column(2).Width = 12;
        sheet.Column(3).Width = 12;
        sheet.Column(4).Width = 16;
    }

    /// <summary>A small table (name, sales, items, revenue) starting at <paramref name="row"/>; returns the next free row.</summary>
    private static int AddGroup(IXLWorksheet sheet, int row, string title, IEnumerable<IGrouping<string, SaleLine>> groups)
    {
        string[] header = [title, "Vendas", "Itens", "Faturamento"];
        for (var c = 0; c < header.Length; c++)
            sheet.Cell(row, c + 1).Value = header[c];
        sheet.Range(row, 1, row, header.Length).Style.Font.Bold = true;

        foreach (var group in groups.OrderByDescending(g => g.Sum(s => s.TotalPrice)))
        {
            row++;
            sheet.Cell(row, 1).Value = group.Key;
            sheet.Cell(row, 2).Value = group.Count();
            sheet.Cell(row, 3).Value = group.Sum(s => s.Quantity);
            sheet.Cell(row, 4).Value = group.Sum(s => s.TotalPrice);
            sheet.Cell(row, 4).Style.NumberFormat.Format = MoneyFormat;
        }

        return row + 2;
    }

    private static byte[] Save(XLWorkbook workbook)
    {
        using var output = new MemoryStream();
        workbook.SaveAs(output);
        return output.ToArray();
    }

    private static Dictionary<string, int> MapColumns(IXLRow headerRow)
    {
        var columns = new Dictionary<string, int>();
        foreach (var cell in headerRow.CellsUsed())
        {
            if (HeaderAliases.TryGetValue(TextNormalizer.ToKey(cell.GetString()), out var column))
                columns.TryAdd(column, cell.Address.ColumnNumber);
        }
        return columns;
    }

    private static SalesSheetRow? ReadRow(IXLRow row, Dictionary<string, int> columns)
    {
        IXLCell? Cell(string column) => columns.TryGetValue(column, out var index) ? row.Cell(index) : null;

        if (columns.Values.All(index => row.Cell(index).Value.IsBlank))
            return null;

        var errors = new Dictionary<string, string>();

        return new SalesSheetRow(
            row.RowNumber(),
            ReadDate(Cell(Layout.Date), Sale.Fields.SaleDate, errors),
            ReadText(Cell(Layout.Product)),
            ReadText(Cell(Layout.Sku)),
            ReadInteger(Cell(Layout.Quantity), Sale.Fields.Quantity, errors),
            ReadDecimal(Cell(Layout.UnitPrice), Sale.Fields.UnitPrice, errors),
            ReadText(Cell(Layout.Channel)),
            ReadText(Cell(Layout.Marketplace)),
            errors);
    }

    private static string? ReadText(IXLCell? cell)
    {
        if (cell is null || cell.Value.IsBlank)
            return null;

        var text = cell.GetFormattedString().Trim();
        return text.Length == 0 ? null : text;
    }

    private static DateOnly? ReadDate(IXLCell? cell, string field, Dictionary<string, string> errors)
    {
        if (cell is null || cell.Value.IsBlank)
            return null;

        var value = cell.Value;
        if (value.IsDateTime)
            return DateOnly.FromDateTime(value.GetDateTime());
        if (value.IsNumber)
        {
            try
            {
                return DateOnly.FromDateTime(DateTime.FromOADate(value.GetNumber()));
            }
            catch (ArgumentException)
            {
                // Falls through to the error below.
            }
        }
        else if (value.IsText && DateOnly.TryParseExact(value.GetText().Trim(), DateFormats, PtBr, DateTimeStyles.None, out var parsed))
            return parsed;

        errors[field] = $"Data \"{cell.GetFormattedString()}\" inválida. Use o formato dd/mm/aaaa.";
        return null;
    }

    private static int? ReadInteger(IXLCell? cell, string field, Dictionary<string, string> errors)
    {
        var number = ReadDecimal(cell, field, errors);
        if (number is null)
            return null;

        if (number != decimal.Truncate(number.Value) || number > int.MaxValue || number < int.MinValue)
        {
            errors[field] = $"Quantidade \"{cell!.GetFormattedString()}\" inválida. Use um número inteiro.";
            return null;
        }

        return (int)number.Value;
    }

    private static decimal? ReadDecimal(IXLCell? cell, string field, Dictionary<string, string> errors)
    {
        if (cell is null || cell.Value.IsBlank)
            return null;

        var value = cell.Value;
        if (value.IsNumber)
            return (decimal)value.GetNumber();

        if (value.IsText)
        {
            var text = value.GetText().Replace("R$", string.Empty).Trim();
            if (decimal.TryParse(text, NumberStyles.Number, PtBr, out var parsed)
                || decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out parsed))
                return parsed;
        }

        errors[field] = $"Valor \"{cell.GetFormattedString()}\" inválido. Use apenas números.";
        return null;
    }

    private static int ColumnOf(string column) => Layout.Columns.ToList().IndexOf(column) + 1;

    private static void AddInstructions(IXLWorksheet sheet)
    {
        sheet.Cell(1, 1).Value = "Como preencher a aba \"Vendas\"";
        sheet.Cell(1, 1).Style.Font.Bold = true;
        sheet.Cell(1, 1).Style.Font.FontSize = 14;

        (string Column, string Rule)[] rules =
        [
            (Layout.Date, "Obrigatório. Data da venda (dd/mm/aaaa). Não pode estar no futuro."),
            (Layout.Product, $"Obrigatório. Nome do produto (até {Sale.ProductNameMaxLength} caracteres)."),
            (Layout.Sku, $"Opcional. Código do produto (até {Sale.SkuMaxLength} caracteres). Liga a venda ao produto cadastrado com o mesmo SKU; se ainda não houver um, o produto só é cadastrado na importação quando a preferência \"Cadastrar produtos ao importar\" estiver ligada (desligada por padrão)."),
            (Layout.Quantity, "Obrigatório. Número inteiro maior que zero."),
            (Layout.UnitPrice, "Obrigatório. Preço de uma unidade, em reais (ex.: 49,90)."),
            (Layout.Channel, "Obrigatório. Presencial (loja física) ou Online (loja virtual)."),
            (Layout.Marketplace, "Opcional. Onde a venda online foi feita (ex.: Mercado Livre, Shopee). Deixe vazio para vendas fora de marketplace. Vendas presenciais não podem ter marketplace.")
        ];

        sheet.Cell(3, 1).Value = "Coluna";
        sheet.Cell(3, 2).Value = "Regra";
        sheet.Range(3, 1, 3, 2).Style.Font.Bold = true;
        for (var i = 0; i < rules.Length; i++)
        {
            sheet.Cell(4 + i, 1).Value = rules[i].Column;
            sheet.Cell(4 + i, 2).Value = rules[i].Rule;
        }

        var exampleRow = 4 + rules.Length + 2;
        sheet.Cell(exampleRow, 1).Value = "Exemplos (não são importados)";
        sheet.Cell(exampleRow, 1).Style.Font.Bold = true;

        object[][] examples =
        [
            [.. Layout.Columns],
            [new DateTime(2026, 10, 1), "Camiseta Básica", "CAM-001", 2, 49.90, SalesChannelParser.InPersonLabel, ""],
            [new DateTime(2026, 10, 1), "Tênis Corrida", "TEN-010", 1, 299.00, SalesChannelParser.OnlineLabel, "Mercado Livre"],
            [new DateTime(2026, 10, 2), "Boné", "BON-003", 3, 39.90, SalesChannelParser.OnlineLabel, ""]
        ];
        for (var r = 0; r < examples.Length; r++)
        for (var c = 0; c < examples[r].Length; c++)
            sheet.Cell(exampleRow + 1 + r, 1 + c).Value = XLCellValue.FromObject(examples[r][c]);

        sheet.Range(exampleRow + 1, 1, exampleRow + 1, Layout.Columns.Count).Style.Font.Bold = true;
        sheet.Range(exampleRow + 2, 1, exampleRow + examples.Length, 1).Style.DateFormat.Format = "dd/mm/yyyy";
        sheet.Column(1).Width = 18;
        sheet.Column(2).Width = 90;
        sheet.Column(2).Style.Alignment.WrapText = true;
    }

    private static SalesSheetReadResult Failed(string error) => new([], [error]);
}
