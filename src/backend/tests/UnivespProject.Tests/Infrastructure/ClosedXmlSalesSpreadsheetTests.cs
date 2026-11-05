using ClosedXML.Excel;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Entities;
using UnivespProject.Infrastructure.Spreadsheets;

namespace UnivespProject.Tests.Infrastructure;

public class ClosedXmlSalesSpreadsheetTests
{
    private readonly ClosedXmlSalesSpreadsheet _spreadsheet = new();

    [Fact]
    public void Template_HasHeaderAndInstructions_AndIsReadableWithNoRows()
    {
        var bytes = _spreadsheet.CreateTemplate(SpreadsheetFont.Default);

        using (var workbook = new XLWorkbook(new MemoryStream(bytes)))
        {
            Assert.Equal(["Vendas", "Instruções"], workbook.Worksheets.Select(w => w.Name));
            var header = workbook.Worksheet("Vendas").Row(1).CellsUsed().Select(c => c.GetString());
            Assert.Equal(SpreadsheetBuilder.TemplateHeader, header);
        }

        var result = _spreadsheet.Read(new MemoryStream(bytes));
        Assert.Empty(result.Errors);
        Assert.Empty(result.Rows);
    }

    [Fact]
    public void PeriodSheet_ReadsBackLikeAnImport_WithTotalOriginAndBatchColumns_AndASummary()
    {
        SaleLine[] sales =
        [
            new(new DateOnly(2026, 11, 2), "Camiseta", "CAM-1", 2, 49.9m, 99.8m, SalesChannel.InPerson, null, "Vendas manuais - novembro/2026", ImportSource.Manual),
            new(new DateOnly(2026, 11, 3), "Tênis", null, 1, 299m, 299m, SalesChannel.Online, "Mercado Livre", "vendas.xlsx", ImportSource.Spreadsheet),
            new(new DateOnly(2026, 11, 3), "Boné", null, 3, 30m, 90m, SalesChannel.InPerson, null, "Vendas - novembro/2026", ImportSource.Store)
        ];

        var bytes = _spreadsheet.CreatePeriodSheet(new SalesPeriodSheet("novembro/2026", sales, SpreadsheetFont.Default));

        using (var workbook = new XLWorkbook(new MemoryStream(bytes)))
        {
            Assert.Equal(["Vendas", "Resumo"], workbook.Worksheets.Select(w => w.Name));
            var vendas = workbook.Worksheet("Vendas");
            Assert.Equal([.. SpreadsheetBuilder.TemplateHeader, "Total", "Origem", "Lote"],
                vendas.Row(1).CellsUsed().Select(c => c.GetString()));
            Assert.Equal((99.8, "Manual", "Vendas manuais - novembro/2026"),
                (vendas.Cell(2, 8).GetDouble(), vendas.Cell(2, 9).GetString(), vendas.Cell(2, 10).GetString()));
            Assert.Equal("Caixa", vendas.Cell(4, 9).GetString());

            var resumo = workbook.Worksheet("Resumo");
            Assert.Equal("Vendas de novembro/2026", resumo.Cell(1, 1).GetString());
            Assert.Equal((3, 6, 488.8),
                (resumo.Cell(3, 2).GetDouble(), resumo.Cell(4, 2).GetDouble(), resumo.Cell(5, 2).GetDouble()));
        }

        var read = _spreadsheet.Read(new MemoryStream(bytes));
        Assert.Empty(read.Errors);
        Assert.Equal(
            [(new DateOnly(2026, 11, 2), "Camiseta", "CAM-1", 2, 49.9m, "Presencial", null),
             (new DateOnly(2026, 11, 3), "Tênis", null, 1, 299m, "Online", "Mercado Livre"),
             (new DateOnly(2026, 11, 3), "Boné", null, 3, 30m, "Presencial", null)],
            read.Rows.Select(r => (r.Date!.Value, r.Product!, r.Sku, r.Quantity!.Value, r.UnitPrice!.Value, r.Channel!, r.Marketplace)));
    }

    [Fact]
    public void Template_UsesTheFontOfTheUsersSystem_InEveryCell()
    {
        var bytes = _spreadsheet.CreateTemplate(SpreadsheetFont.Linux);

        using var workbook = new XLWorkbook(new MemoryStream(bytes));
        foreach (var cell in new[]
                 {
                     workbook.Worksheet("Vendas").Cell(1, 1), // styled header
                     workbook.Worksheet("Vendas").Cell(50, 3), // empty cell
                     workbook.Worksheet("Instruções").Cell(4, 2)
                 })
            Assert.Equal(("Liberation Sans", 10.0), (cell.Style.Font.FontName, cell.Style.Font.FontSize));
    }

    [Fact]
    public void PeriodSheet_UsesTheFontOfTheUsersSystem_AndKeepsTheTitleBigger()
    {
        SaleLine[] sales = [new(new DateOnly(2026, 11, 2), "Camiseta", null, 1, 10m, 10m, SalesChannel.InPerson, null, "Lote", ImportSource.Manual)];

        var bytes = _spreadsheet.CreatePeriodSheet(new SalesPeriodSheet("novembro/2026", sales, SpreadsheetFont.Apple));

        using var workbook = new XLWorkbook(new MemoryStream(bytes));
        var data = workbook.Worksheet("Vendas").Cell(2, 2).Style.Font;
        Assert.Equal(("Helvetica Neue", 10.0), (data.FontName, data.FontSize));
        var title = workbook.Worksheet("Resumo").Cell(1, 1).Style.Font;
        Assert.Equal(("Helvetica Neue", 14.0), (title.FontName, title.FontSize));
    }

    [Fact]
    public void Read_ConvertsTypedCells_AndSkipsBlankRows()
    {
        using var file = SpreadsheetBuilder.Build(
            SpreadsheetBuilder.TemplateHeader,
            [new DateTime(2026, 10, 1), "Camiseta", "CAM-1", 2, 49.9, "Presencial", null],
            [null, null, null, null, null, null, null],
            [new DateTime(2026, 10, 2), "Tênis", null, 1, 299, "Online", "Mercado Livre"]);

        var result = _spreadsheet.Read(file);

        Assert.Empty(result.Errors);
        Assert.Equal(2, result.Rows.Count);
        var first = result.Rows[0];
        Assert.Equal((2, new DateOnly(2026, 10, 1), "Camiseta", 2, 49.9m, "Presencial"),
            (first.RowNumber, first.Date, first.Product, first.Quantity, first.UnitPrice, first.Channel));
        Assert.Null(first.Marketplace);
        Assert.Equal(4, result.Rows[1].RowNumber);
        Assert.Equal("Mercado Livre", result.Rows[1].Marketplace);
    }

    [Fact]
    public void Read_AcceptsBrazilianTextFormats_AndHeaderVariations()
    {
        using var file = SpreadsheetBuilder.Build(
            ["data", "PRODUTO", "Qtd", "Preco unitario", "canal"],
            ["05/10/2026", "Boné", "3", "R$ 1.234,56", "loja física"]);

        var row = Assert.Single(_spreadsheet.Read(file).Rows);

        Assert.Equal(new DateOnly(2026, 10, 5), row.Date);
        Assert.Equal(3, row.Quantity);
        Assert.Equal(1234.56m, row.UnitPrice);
        Assert.Empty(row.CellErrors);
    }

    [Fact]
    public void Read_ReportsCellErrorsByField()
    {
        using var file = SpreadsheetBuilder.Build(
            SpreadsheetBuilder.TemplateHeader,
            ["ontem", "Camiseta", null, 1.5, "abc", "Online", null]);

        var row = Assert.Single(_spreadsheet.Read(file).Rows);

        Assert.Null(row.Date);
        Assert.Null(row.Quantity);
        Assert.Null(row.UnitPrice);
        Assert.Equal(
            new[] { Sale.Fields.SaleDate, Sale.Fields.Quantity, Sale.Fields.UnitPrice }.Order(),
            row.CellErrors.Keys.Order());
    }

    [Fact]
    public void Read_MissingRequiredColumns_IsAFileError()
    {
        using var file = SpreadsheetBuilder.Build(["Data", "Produto"], [new DateTime(2026, 10, 1), "Camiseta"]);

        var result = _spreadsheet.Read(file);

        var error = Assert.Single(result.Errors);
        Assert.Contains("Quantidade", error);
        Assert.Contains("Canal", error);
    }

    [Fact]
    public void Read_InvalidFile_IsAFileError()
    {
        var result = _spreadsheet.Read(new MemoryStream("não é excel"u8.ToArray()));

        Assert.Single(result.Errors);
    }
}
