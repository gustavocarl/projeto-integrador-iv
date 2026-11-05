using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Tests.Application.Sales;

public class SalesExportServiceTests
{
    private static readonly DateOnly Today = new(2026, 11, 30);

    private readonly FakeSalesReportRepository _reports = new();
    private readonly CapturingSpreadsheet _spreadsheet = new();
    private readonly Notifier _notifier = new();
    private readonly InMemorySalesExportRepository _exports = new();
    private readonly SalesExportService _service;

    public SalesExportServiceTests() =>
        _service = new SalesExportService(_notifier, _reports, _exports, _spreadsheet);

    private Task<SalesExportResponse?> Create(string? start, string? end, string? platform = null) =>
        _service.CreateAsync(new CreateSalesExportRequest(start, end, platform));

    private Sale Sell(DateOnly date, string product, string batch = "Lote de teste", ImportSource source = ImportSource.Spreadsheet)
    {
        var sale = new Sale(null, date, product, null, 1, 10m, SalesChannel.InPerson, null, Today);
        _reports.Sales.Add(sale);
        _reports.Batches[sale] = (batch, source);
        return sale;
    }

    private IEnumerable<(string Key, string Message)> Errors =>
        _notifier.Notifications.Select(n => (n.Key, n.Message));

    [Fact]
    public async Task Period_HasEverySaleOfEveryBatchInsideIt_AndTheFileIsKept()
    {
        Sell(new DateOnly(2026, 10, 31), "Fora antes");
        Sell(new DateOnly(2026, 11, 2), "Manual", "Vendas manuais - novembro/2026", ImportSource.Manual);
        Sell(new DateOnly(2026, 11, 3), "Caixa", "Vendas - novembro/2026", ImportSource.Store);
        Sell(new DateOnly(2026, 11, 8), "Planilha");
        Sell(new DateOnly(2026, 11, 9), "Fora depois");

        var export = await Create("2026-11-02", "2026-11-08");

        Assert.False(_notifier.HasNotifications);
        Assert.Equal(
            ("vendas-2026-11-02-a-2026-11-08.xlsx", new DateOnly(2026, 11, 2), new DateOnly(2026, 11, 8), "02/11/2026 a 08/11/2026", 3, 30m),
            (export!.FileName, export.PeriodStart, export.PeriodEnd, export.PeriodLabel, export.SalesCount, export.TotalRevenue));
        Assert.Equal(1, _exports.Saves);
        var file = await _service.DownloadAsync(export.Id);
        Assert.Equal(("vendas-2026-11-02-a-2026-11-08.xlsx", CapturingSpreadsheet.Content), (file!.FileName, file.Content));
        Assert.Equal("02/11/2026 a 08/11/2026", _spreadsheet.Sheet!.PeriodLabel);
        Assert.Equal(
            [("Manual", ImportSource.Manual), ("Caixa", ImportSource.Store), ("Planilha", ImportSource.Spreadsheet)],
            _spreadsheet.Sheet.Sales.Select(s => (s.ProductName, s.Source)));
    }

    [Theory]
    [InlineData("2026-11-05", "2026-11-05", "vendas-2026-11-05.xlsx", "05/11/2026")]
    [InlineData("2026-11-01", "2026-11-30", "vendas-2026-11.xlsx", "novembro/2026")]
    [InlineData("2026-02-01", "2026-02-28", "vendas-2026-02.xlsx", "fevereiro/2026")]
    [InlineData("2026-11-01", "2026-11-29", "vendas-2026-11-01-a-2026-11-29.xlsx", "01/11/2026 a 29/11/2026")]
    public void Day_WholeMonth_AndRange_AreNamedForWhatTheyAre(string start, string end, string fileName, string label)
    {
        var (from, to) = (DateOnly.Parse(start), DateOnly.Parse(end));

        Assert.Equal((fileName, label),
            (SalesExportService.FileName(from, to), SalesExportService.Label(from, to)));
    }

    [Fact]
    public async Task PeriodWithoutSales_IsNotFound()
    {
        Sell(new DateOnly(2026, 11, 2), "Camiseta");

        var export = await Create("2026-11-10", "2026-11-16");

        Assert.Null(export);
        Assert.Equal(NotificationType.NotFound, _notifier.Notifications.Single().Type);
        Assert.Equal("Não há vendas em 10/11/2026 a 16/11/2026.", _notifier.Notifications.Single().Message);
        Assert.Null(_spreadsheet.Sheet);
        Assert.Empty(_exports.Items);
    }

    [Fact]
    public async Task MissingAndInvalidDates_AreReportedPerField()
    {
        Assert.Null(await Create(null, "05/11/2026"));

        Assert.Equal(
            [("start", "Informe a data inicial."), ("end", "Data inválida. Use o formato aaaa-mm-dd (ex.: 2026-11-05).")],
            Errors);
    }

    [Fact]
    public async Task EndBeforeStart_IsAnError()
    {
        Assert.Null(await Create("2026-11-10", "2026-11-01"));

        Assert.Equal([("end", "A data final não pode ser anterior à inicial.")], Errors);
    }

    [Fact]
    public async Task PeriodLongerThanAYear_IsAnError()
    {
        Assert.NotNull(await AnyFile("2025-11-01", "2026-11-01"));
        Assert.Null(await Create("2025-11-01", "2026-11-02"));

        Assert.Equal([("end", "O período pode ter no máximo 366 dias.")], Errors);
    }

    private Task<SalesExportResponse?> AnyFile(string start, string end)
    {
        Sell(new DateOnly(2026, 1, 1), "Camiseta");
        return Create(start, end);
    }

    [Theory]
    [InlineData(null, "Calibri", 11)]
    [InlineData("windows", "Calibri", 11)]
    [InlineData("macOS", "Helvetica Neue", 10)]
    [InlineData("iOS", "Helvetica Neue", 10)]
    [InlineData("linux", "Liberation Sans", 10)]
    [InlineData("android", "Roboto", 10)]
    public async Task TheSpreadsheet_UsesTheDefaultFontOfTheUsersSystem(string? platform, string font, double size)
    {
        Sell(new DateOnly(2026, 11, 2), "Camiseta");

        Assert.NotNull(await Create("2026-11-02", "2026-11-02", platform));

        Assert.Equal(new SpreadsheetFont(font, size), _spreadsheet.Sheet!.Font);
    }

    [Fact]
    public async Task UnknownSystem_IsAnError_AndNothingIsGenerated()
    {
        Sell(new DateOnly(2026, 11, 2), "Camiseta");

        Assert.Null(await Create("2026-11-02", "2026-11-02", "amiga"));

        Assert.Equal([("platform", SpreadsheetFont.InvalidMessage)], Errors);
        Assert.Null(_spreadsheet.Sheet);
        Assert.Empty(_exports.Items);
    }

    [Fact]
    public async Task List_IsMostRecentFirst_AndDeleteRemovesOnlyTheFile()
    {
        Sell(new DateOnly(2026, 11, 2), "Camiseta");
        var day = await Create("2026-11-02", "2026-11-02");
        var month = await Create("2026-11-01", "2026-11-30");

        Assert.Equal([month!.Id, day!.Id], (await _service.ListAsync()).Select(e => e.Id));

        Assert.True(await _service.DeleteAsync(day.Id));
        Assert.Equal([month.Id], (await _service.ListAsync()).Select(e => e.Id));
        Assert.Single(_reports.Sales);
    }

    [Fact]
    public async Task MissingExport_IsNotFound_ToDownloadAndToDelete()
    {
        Assert.Null(await _service.DownloadAsync(Guid.NewGuid()));
        Assert.Null(await _service.DeleteAsync(Guid.NewGuid()));

        Assert.All(_notifier.Notifications, n =>
            Assert.Equal((NotificationType.NotFound, "Planilha gerada não encontrada."), (n.Type, n.Message)));
        Assert.Equal(2, _notifier.Notifications.Count);
    }

    private sealed class InMemorySalesExportRepository : ISalesExportRepository
    {
        public List<SalesExport> Items { get; } = [];
        public int Saves { get; private set; }
        private int _clock;

        public Task AddAsync(SalesExport export, CancellationToken cancellationToken = default)
        {
            // Distinct creation times, so "most recent first" is testable.
            export.CreatedAt = new DateTime(2026, 11, 1, 0, 0, 0, DateTimeKind.Utc).AddMinutes(++_clock);
            Items.Add(export);
            return Task.CompletedTask;
        }

        public Task<IReadOnlyList<SalesExportResponse>> ListAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<SalesExportResponse>>(
                Items.OrderByDescending(e => e.CreatedAt).Select(SalesExportService.ToResponse).ToList());

        public Task<(string FileName, byte[] Content)?> GetFileAsync(Guid id, CancellationToken cancellationToken = default) =>
            Task.FromResult(Items.FirstOrDefault(e => e.Id == id) is { } e ? (e.FileName, e.Content) : ((string, byte[])?)null);

        public Task<bool> DeleteAsync(Guid id, CancellationToken cancellationToken = default) =>
            Task.FromResult(Items.RemoveAll(e => e.Id == id) > 0);

        public Task SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            Saves++;
            return Task.CompletedTask;
        }
    }

    private sealed class CapturingSpreadsheet : ISalesSpreadsheet
    {
        public static readonly byte[] Content = [1, 2, 3];

        public SalesPeriodSheet? Sheet { get; private set; }

        public SalesSheetReadResult Read(Stream content) => throw new NotSupportedException();
        public byte[] CreateTemplate(SpreadsheetFont font) => throw new NotSupportedException();

        public byte[] CreatePeriodSheet(SalesPeriodSheet sheet)
        {
            Sheet = sheet;
            return Content;
        }
    }
}
