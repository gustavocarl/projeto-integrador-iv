using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class SalesExportRepository(AppDbContext context) : ISalesExportRepository
{
    public async Task AddAsync(SalesExport export, CancellationToken cancellationToken = default) =>
        await context.SalesExports.AddAsync(export, cancellationToken);

    public async Task<IReadOnlyList<SalesExportResponse>> ListAsync(CancellationToken cancellationToken = default) =>
        await context.SalesExports
            .AsNoTracking()
            .OrderByDescending(e => e.CreatedAt)
            .Select(e => new SalesExportResponse(e.Id, e.FileName, e.PeriodStart, e.PeriodEnd, e.PeriodLabel,
                e.SalesCount, e.TotalRevenue, e.CreatedAt, e.CreatedBy))
            .ToListAsync(cancellationToken);

    public async Task<(string FileName, byte[] Content)?> GetFileAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var file = await context.SalesExports
            .AsNoTracking()
            .Where(e => e.Id == id)
            .Select(e => new { e.FileName, e.Content })
            .FirstOrDefaultAsync(cancellationToken);
        return file is null ? null : (file.FileName, file.Content);
    }

    public async Task<bool> DeleteAsync(Guid id, CancellationToken cancellationToken = default) =>
        await context.SalesExports.Where(e => e.Id == id).ExecuteDeleteAsync(cancellationToken) > 0;

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
