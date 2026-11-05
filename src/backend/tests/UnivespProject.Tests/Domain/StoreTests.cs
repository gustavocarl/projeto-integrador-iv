using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Common;

namespace UnivespProject.Tests.Domain;

public class StoreTests
{
    [Theory]
    [InlineData("  Loja   do João ", "Loja do João", "LOJA DO JOAO")]
    [InlineData("marcelo eletrônicos", "marcelo eletrônicos", "MARCELO ELETRONICOS")]
    public void Name_KeepsWhatWasTyped_AndComparesWithoutAccentsCaseOrExtraSpaces(
        string typed, string name, string normalized)
    {
        var store = new Store(typed);

        Assert.Equal(name, store.Name);
        Assert.Equal(normalized, store.NormalizedName);
    }

    [Fact]
    public void Rename_TooLong_KeepsTheOldName()
    {
        var store = new Store("Loja");

        Assert.False(store.Rename(new string('a', Store.NameMaxLength + 1)));
        Assert.Equal("Loja", store.Name);
        Assert.Equal("LOJA", store.NormalizedName);
    }

    [Fact]
    public void DemotedAdmin_KeepsTheAreasUntilTheAdminChangesThem()
    {
        var user = new User("Maria", "maria@exemplo.com");
        user.OpenStore(new Store("Loja"));

        user.ChangeRole(StoreRole.Member);

        Assert.Equal(StoreArea.All, user.EffectiveAreas);
        user.SetAreas(StoreArea.Checkout);
        Assert.Equal(StoreArea.Checkout, user.EffectiveAreas);
    }

    [Fact]
    public void StoreData_CantMoveToAnotherStore()
    {
        var product = new Product("Mouse", "M-1", null, 50m, null, 0, 0);
        var store = Guid.NewGuid();
        product.AssignStore(store);
        product.AssignStore(store);

        Assert.Throws<InvalidOperationException>(() => product.AssignStore(Guid.NewGuid()));
        Assert.IsAssignableFrom<IStoreOwned>(product);
    }
}
