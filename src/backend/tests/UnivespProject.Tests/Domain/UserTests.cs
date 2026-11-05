using UnivespProject.Domain.Entities;

namespace UnivespProject.Tests.Domain;

public class UserTests
{
    [Fact]
    public void Constructor_NormalizesEmail_AndSetsCreatedBy()
    {
        var user = new User("  Maria  ", "  Maria@Exemplo.COM ");

        Assert.True(user.IsValid);
        Assert.Equal("Maria", user.Name);
        Assert.Equal("maria@exemplo.com", user.Email);
        Assert.Equal("maria@exemplo.com", user.CreatedBy);
    }

    [Theory]
    [InlineData("")]
    [InlineData("sem-arroba")]
    [InlineData("Nome <maria@exemplo.com>")]
    public void Constructor_NotifiesInvalidEmail(string email)
    {
        var user = new User("Maria", email);

        Assert.False(user.IsValid);
        Assert.Contains(user.Notifications, n => n.Key == User.Fields.Email);
    }

    [Fact]
    public void Constructor_CollectsEveryError_InsteadOfStoppingAtTheFirst()
    {
        var user = new User(" ", "invalido");

        Assert.Equal(2, user.Notifications.Count);
        Assert.Contains(user.Notifications, n => n.Key == User.Fields.Name);
        Assert.Contains(user.Notifications, n => n.Key == User.Fields.Email);
    }
}
