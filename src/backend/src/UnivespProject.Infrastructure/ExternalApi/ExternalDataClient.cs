using UnivespProject.Application.Abstractions;

namespace UnivespProject.Infrastructure.ExternalApi;

internal sealed class ExternalDataClient(HttpClient httpClient) : IExternalDataClient
{
    private readonly HttpClient _httpClient = httpClient;
}
