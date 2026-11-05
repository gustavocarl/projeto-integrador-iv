using Microsoft.AspNetCore.Identity;
using UnivespProject.Domain.Entities;
using IPasswordHasher = UnivespProject.Application.Abstractions.IPasswordHasher;

namespace UnivespProject.Infrastructure.Security;

/// <summary>
/// One-way password hashing using ASP.NET Core Identity's hasher
/// (PBKDF2 with HMAC-SHA512, random salt per password, 100k iterations).
/// </summary>
internal sealed class PasswordHasher : IPasswordHasher
{
    private readonly PasswordHasher<User> _hasher = new();

    public string Hash(string password) => _hasher.HashPassword(null!, password);

    public bool Verify(string passwordHash, string providedPassword) =>
        _hasher.VerifyHashedPassword(null!, passwordHash, providedPassword) != PasswordVerificationResult.Failed;
}
