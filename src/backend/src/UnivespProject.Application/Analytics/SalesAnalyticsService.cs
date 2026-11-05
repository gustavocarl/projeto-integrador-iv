using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Analytics;

/// <summary>
/// Base of the machine learning analyses: loads the monthly sales history (every batch)
/// and reports when there is not enough of it.
/// </summary>
public abstract class SalesAnalyticsService(
    INotifier notifier,
    ISalesReportRepository reports,
    TimeProvider timeProvider) : BaseService(notifier)
{
    protected DateOnly Today => DateOnly.FromDateTime(timeProvider.GetLocalNow().DateTime);

    /// <param name="minimumMonths">Complete months the analysis needs.</param>
    /// <param name="analysis">"A previsão": the subject of the error message.</param>
    /// <returns>Null (with a NotFound notification) when the history is too short.</returns>
    private protected async Task<SalesHistory?> LoadHistoryAsync(
        int minimumMonths, string analysis, CancellationToken cancellationToken)
    {
        var history = SalesHistory.Build(
            await reports.GetTotalsByProductAndMonthAsync(cancellationToken),
            await reports.GetDaysWithSalesByMonthAsync(cancellationToken),
            Today);

        if (history.Months.Count >= minimumMonths)
            return history;

        var needed = minimumMonths == 1 ? "1 mês completo" : $"{minimumMonths} meses completos";
        var found = history.Months.Count switch
        {
            0 => "ainda não há nenhum",
            1 => "há só 1",
            var n => $"há só {n}",
        };
        Notify($"{analysis} precisa de pelo menos {needed} de vendas e {found}. "
               + "O mês atual e meses com vendas em menos da metade dos dias não contam.",
            NotificationType.NotFound);
        return null;
    }
}
