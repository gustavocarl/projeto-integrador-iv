using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

public sealed record AccessToken(string Token, DateTime ExpiresAt);

public interface ITokenService
{
    AccessToken Generate(User user);
}
