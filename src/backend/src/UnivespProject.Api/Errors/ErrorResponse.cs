using Microsoft.AspNetCore.Mvc;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Api.Errors;

/// <summary>
/// Builds the single error format returned by the API (RFC 7807 + an "errors" list):
/// <code>{ "status": 400, "title": "...", "errors": [ { "key": "email", "message": "..." } ] }</code>
/// The frontend reads "errors" to show general messages and messages under each field.
/// </summary>
public static class ErrorResponse
{
    public const string ErrorsKey = "errors";

    public static ProblemDetails Create(int status, IEnumerable<Notification> notifications) => new()
    {
        Status = status,
        Title = TitleFor(status),
        Extensions =
        {
            [ErrorsKey] = notifications.Select(n => new { key = n.Key, message = n.Message }).ToArray()
        }
    };

    public static ProblemDetails Create(int status, string message) =>
        Create(status, [new Notification(string.Empty, message)]);

    /// <summary>
    /// When there are several kinds of notification, the most restrictive one decides the status code.
    /// </summary>
    public static int StatusFor(IEnumerable<Notification> notifications)
    {
        var types = notifications.Select(n => n.Type).ToHashSet();

        if (types.Contains(NotificationType.Unauthorized)) return StatusCodes.Status401Unauthorized;
        if (types.Contains(NotificationType.Forbidden)) return StatusCodes.Status403Forbidden;
        if (types.Contains(NotificationType.NotFound)) return StatusCodes.Status404NotFound;
        if (types.Contains(NotificationType.Conflict)) return StatusCodes.Status409Conflict;
        return StatusCodes.Status400BadRequest;
    }

    private static string TitleFor(int status) => status switch
    {
        StatusCodes.Status400BadRequest => "Dados inválidos.",
        StatusCodes.Status401Unauthorized => "Não autorizado.",
        StatusCodes.Status403Forbidden => "Acesso negado.",
        StatusCodes.Status404NotFound => "Não encontrado.",
        StatusCodes.Status409Conflict => "Conflito.",
        _ => "Erro inesperado."
    };
}
