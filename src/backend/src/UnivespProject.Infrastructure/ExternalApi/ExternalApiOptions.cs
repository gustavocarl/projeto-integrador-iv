namespace UnivespProject.Infrastructure.ExternalApi;

public sealed class ExternalApiOptions
{
    public const string SectionName = "ExternalApi";

    public string BaseUrl { get; init; } = string.Empty;
    public string? ApiKey { get; init; }
    public int TimeoutSeconds { get; init; } = 30;
}
