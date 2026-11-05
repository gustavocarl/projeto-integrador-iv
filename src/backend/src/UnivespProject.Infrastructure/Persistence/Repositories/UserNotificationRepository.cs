using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class UserNotificationRepository(AppDbContext context) : IUserNotificationRepository
{
    public async Task<IReadOnlyList<UserNotification>> ListLatestAsync(
        Guid userId, int take, CancellationToken cancellationToken = default) =>
        await context.UserNotifications.AsNoTracking()
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(take)
            .ToListAsync(cancellationToken);

    public Task<int> CountUnreadAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.UserNotifications.CountAsync(n => n.UserId == userId && n.ReadAt == null, cancellationToken);

    public Task<UserNotification?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        context.UserNotifications.FirstOrDefaultAsync(n => n.Id == id, cancellationToken);

    public async Task<IReadOnlyList<UserNotification>> ListUnreadAsync(
        Guid userId, CancellationToken cancellationToken = default) =>
        await context.UserNotifications
            .Where(n => n.UserId == userId && n.ReadAt == null)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<UserNotification>> ListUnreadAboutAsync(
        NotificationKind kind, Guid relatedUserId, CancellationToken cancellationToken = default) =>
        await context.UserNotifications
            .Where(n => n.Kind == kind && n.RelatedUserId == relatedUserId && n.ReadAt == null)
            .ToListAsync(cancellationToken);

    public async Task AddAsync(UserNotification notification, CancellationToken cancellationToken = default) =>
        await context.UserNotifications.AddAsync(notification, cancellationToken);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
