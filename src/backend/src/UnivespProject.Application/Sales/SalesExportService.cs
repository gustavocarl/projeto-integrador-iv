using System.Globalization;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Sales;

internal sealed class SalesExportService(
    INotifier notifier,
    ISalesReportRepository reports,
    ISalesExportRepository exports,
    ISalesSpreadsheet spreadsheet) : BaseService(notifier), ISalesExportService
{
    /// <summary>Longest period of one spreadsheet, in days.</summary>
    public const int MaxDays = 366;

    /// <summary>Error keys: the query parameters.</summary>
    public static class Fields
    {
        public const string Start = "start";
        public const string End = "end";
    }

    private static readonly CultureInfo PtBr = CultureInfo.GetCultureInfo("pt-BR");

    public async Task<SalesExportResponse?> CreateAsync(CreateSalesExportRequest request, CancellationToken cancellationToken = default)
    {
        var first = ParseDate(Fields.Start, request.Start, "Informe a data inicial.");
        var last = ParseDate(Fields.End, request.End, "Informe a data final.");
        if (!SpreadsheetFont.TryFor(request.Platform, out var font))
            Notify(SpreadsheetFont.Field, SpreadsheetFont.InvalidMessage);
        if (first is not { } from || last is not { } to || HasNotifications)
            return null;

        if (to < from)
            Notify(Fields.End, "A data final não pode ser anterior à inicial.");
        else if (to.DayNumber - from.DayNumber + 1 > MaxDays)
            Notify(Fields.End, $"O período pode ter no máximo {MaxDays} dias.");
        if (HasNotifications)
            return null;

        var label = Label(from, to);
        var sales = await reports.ListSalesAsync(from, to, cancellationToken);
        if (sales.Count == 0)
        {
            Notify($"Não há vendas em {label}.", NotificationType.NotFound);
            return null;
        }

        var export = new SalesExport(FileName(from, to), from, to, label, sales.Count, sales.Sum(s => s.TotalPrice),
            spreadsheet.CreatePeriodSheet(new SalesPeriodSheet(label, sales, font)));
        await exports.AddAsync(export, cancellationToken);
        await exports.SaveChangesAsync(cancellationToken);
        return ToResponse(export);
    }

    public Task<IReadOnlyList<SalesExportResponse>> ListAsync(CancellationToken cancellationToken = default) =>
        exports.ListAsync(cancellationToken);

    public async Task<SpreadsheetDownload?> DownloadAsync(Guid id, CancellationToken cancellationToken = default)
    {
        if (await exports.GetFileAsync(id, cancellationToken) is { } file)
            return new SpreadsheetDownload(file.FileName, file.Content);

        NotFound();
        return null;
    }

    public async Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        if (await exports.DeleteAsync(id, cancellationToken))
            return true;

        NotFound();
        return null;
    }

    private void NotFound() => Notify("Planilha gerada não encontrada.", NotificationType.NotFound);

    internal static SalesExportResponse ToResponse(SalesExport export) =>
        new(export.Id, export.FileName, export.PeriodStart, export.PeriodEnd, export.PeriodLabel,
            export.SalesCount, export.TotalRevenue, export.CreatedAt, export.CreatedBy);

    /// <summary>"05/11/2026", "novembro/2026" (a whole month) or "01/11/2026 a 07/11/2026".</summary>
    internal static string Label(DateOnly from, DateOnly to) =>
        from == to ? Day(from)
        : IsWholeMonth(from, to) ? SalesMonth.Of(from).Label
        : $"{Day(from)} a {Day(to)}";

    /// <summary>"vendas-2026-11-05.xlsx", "vendas-2026-11.xlsx" or "vendas-2026-11-01-a-2026-11-07.xlsx".</summary>
    internal static string FileName(DateOnly from, DateOnly to) =>
        from == to ? $"vendas-{Iso(from)}.xlsx"
        : IsWholeMonth(from, to) ? $"vendas-{SalesMonth.Of(from)}.xlsx"
        : $"vendas-{Iso(from)}-a-{Iso(to)}.xlsx";

    private static bool IsWholeMonth(DateOnly from, DateOnly to) =>
        from.Day == 1 && SalesMonth.Of(from) is var month && to == month.End;

    private static string Day(DateOnly date) => date.ToString("dd/MM/yyyy", PtBr);
    private static string Iso(DateOnly date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private DateOnly? ParseDate(string key, string? value, string missingMessage)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            Notify(key, missingMessage);
            return null;
        }

        if (DateOnly.TryParseExact(value.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            return date;

        Notify(key, "Data inválida. Use o formato aaaa-mm-dd (ex.: 2026-11-05).");
        return null;
    }
}
