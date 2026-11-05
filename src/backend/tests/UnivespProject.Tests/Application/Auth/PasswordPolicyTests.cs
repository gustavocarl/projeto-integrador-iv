using UnivespProject.Application.Auth;

namespace UnivespProject.Tests.Application.Auth;

public class PasswordPolicyTests
{
    [Theory]
    [InlineData("Curta1")]
    [InlineData("semmaiuscula1")]
    [InlineData("SEMMINUSCULA1")]
    [InlineData("SemNumeroAqui")]
    public void Validate_RejectsWeakPasswords(string password)
    {
        Assert.NotEmpty(PasswordPolicy.Validate(password));
    }

    [Fact]
    public void Validate_ReturnsEveryBrokenRule()
    {
        // Too short, no upper-case letter, no digit.
        Assert.Equal(3, PasswordPolicy.Validate("abc").Count());
    }

    [Fact]
    public void Validate_AcceptsStrongPassword()
    {
        Assert.Empty(PasswordPolicy.Validate("Senha123"));
    }
}
