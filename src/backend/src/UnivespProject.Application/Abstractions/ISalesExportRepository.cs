using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

/// <summary>Generated sales spreadsheets. Lists never read the files' content.</summary>
public interface ISalesExportRepository
{
    Task AddAsync(SalesExport export, CancellationToken cancellationToken = default);

    /// <summary>Most recent first, without the file content.</summary>
    Task<IReadOnlyList<SalesExportResponse>> ListAsync(CancellationToken cancellationToken = default);

    /// <summary>The file name and content; null when it does not exist.</summary>
    Task<(string FileName, byte[] Content)?> GetFileAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Removes the record (and its file) right away; false when it does not exist.</summary>
    Task<bool> DeleteAsync(Guid id, CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
