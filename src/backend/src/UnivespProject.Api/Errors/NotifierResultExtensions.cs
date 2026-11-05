using UnivespProject.Application.Notifications;

namespace UnivespProject.Api.Errors;

public static class NotifierResultExtensions
{
    /// <summary>
    /// Every endpoint ends with this: an error response when the request produced notifications,
    /// otherwise the success response built from <paramref name="value"/>.
    /// </summary>
    public static IResult ToResult<T>(this INotifier notifier, T? value, Func<T, IResult> onSuccess)
    {
        if (notifier.HasNotifications || value is null)
        {
            var status = ErrorResponse.StatusFor(notifier.Notifications);
            return Results.Problem(ErrorResponse.Create(status, notifier.Notifications));
        }

        return onSuccess(value);
    }
}
