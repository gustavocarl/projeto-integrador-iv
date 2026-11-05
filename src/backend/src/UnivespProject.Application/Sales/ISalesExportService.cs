using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>A generated file to download.</summary>
public sealed record SpreadsheetDownload(string FileName, byte[] Content);

/// <summary>
/// Sales spreadsheets of a period (a day, a week, a month or any range) with every sale, whatever
/// its batch (imported, typed in or checkout). Each one generated is kept to be downloaded again.
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISalesExportService
{
    /// <summary>Generates the spreadsheet and keeps it. Error keys: "start" and "end".</summary>
    Task<SalesExportResponse?> CreateAsync(CreateSalesExportRequest request, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SalesExportResponse>> ListAsync(CancellationToken cancellationToken = default);

    /// <summary>The file as it was generated.</summary>
    Task<SpreadsheetDownload?> DownloadAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Removes only the generated file; no sale is touched.</summary>
    Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}
