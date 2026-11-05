using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Base for the services that create sales from a request (typed-in sale and checkout):
/// reads the channel and finds or creates the marketplace the same way for both.
/// </summary>
internal abstract class SaleWriterService(INotifier notifier, IMarketplaceRepository marketplaces, TimeProvider timeProvider)
    : BaseService(notifier)
{
    protected IMarketplaceRepository Marketplaces { get; } = marketplaces;

    protected DateOnly Today => DateOnly.FromDateTime(timeProvider.GetLocalNow().DateTime);

    /// <summary>
    /// The channel, or null. An unreadable value is reported and added to <paramref name="reportedFields"/>
    /// (the sale would only add "is required" for it).
    /// </summary>
    protected SalesChannel? ParseChannel(string? value, HashSet<string> reportedFields)
    {
        if (SalesChannelParser.TryParse(value, out var channel))
            return channel;

        if (!string.IsNullOrWhiteSpace(value))
        {
            Notify(Sale.Fields.Channel, $"Canal \"{value}\" inválido. Use Presencial ou Online.");
            reportedFields.Add(Sale.Fields.Channel);
        }

        return null;
    }

    /// <summary>
    /// Existing marketplace with the same normalized name, or a new one (save it only on success).
    /// An invalid name is reported and returns null.
    /// </summary>
    protected async Task<(Marketplace? Marketplace, bool IsNew)> ResolveMarketplaceAsync(
        string? name, HashSet<string> reportedFields, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(name))
            return (null, false);

        var existing = await Marketplaces.GetByNormalizedNamesAsync([TextNormalizer.ToKey(name)], cancellationToken);
        if (existing.Count > 0)
            return (existing[0], false);

        var created = new Marketplace(name);
        if (created.IsValid)
            return (created, true);

        foreach (var n in created.Notifications)
            Notify(Sale.Fields.Marketplace, n.Message);
        reportedFields.Add(Sale.Fields.Marketplace);
        return (null, false);
    }
}
