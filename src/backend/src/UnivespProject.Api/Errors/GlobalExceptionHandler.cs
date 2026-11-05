using Microsoft.AspNetCore.Diagnostics;

namespace UnivespProject.Api.Errors;

/// <summary>
/// Last line of defense: turns any exception into the standard error format,
/// so the frontend never receives a stack trace or a different payload.
/// </summary>
internal sealed class GlobalExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (status, message) = exception switch
        {
            // Malformed JSON or missing body.
            BadHttpRequestException => (StatusCodes.Status400BadRequest, "Requisição inválida. Verifique os dados enviados."),
            _ => (StatusCodes.Status500InternalServerError, "Ocorreu um erro inesperado. Tente novamente mais tarde.")
        };

        if (status >= StatusCodes.Status500InternalServerError)
            logger.LogError(exception, "Unhandled exception");

        httpContext.Response.StatusCode = status;
        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = ErrorResponse.Create(status, message)
        });
    }
}
