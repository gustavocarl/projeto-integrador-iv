using UnivespProject.Infrastructure.Security;

namespace UnivespProject.Tests.Infrastructure;

public class PasswordHasherTests
{
    private readonly PasswordHasher _hasher = new();

    [Fact]
    public void Hash_IsNotPlainText_AndIsSaltedPerCall()
    {
        var first = _hasher.Hash("Senha123");
        var second = _hasher.Hash("Senha123");

        Assert.DoesNotContain("Senha123", first);
        Assert.NotEqual(first, second);
    }

    [Fact]
    public void Verify_AcceptsCorrectPassword_AndRejectsWrongOne()
    {
        var hash = _hasher.Hash("Senha123");

        Assert.True(_hasher.Verify(hash, "Senha123"));
        Assert.False(_hasher.Verify(hash, "Senha124"));
    }
}
