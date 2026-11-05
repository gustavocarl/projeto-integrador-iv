using UnivespProject.Domain.Common;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// Sales platform (Mercado Livre, Shopee, ...). Created automatically the first time a name appears in a spreadsheet.
/// </summary>
public sealed class Marketplace : StoreOwnedEntity
{
    public const int NameMaxLength = 100;

    public string Name { get; private set; } = string.Empty;

    /// <summary>Unique comparison key (see <see cref="TextNormalizer.ToKey"/>).</summary>
    public string NormalizedName { get; private set; } = string.Empty;

    // Required by Entity Framework.
    private Marketplace() { }

    public Marketplace(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            AddNotification(Fields.Name, "O nome do marketplace é obrigatório.");
            return;
        }

        name = TextNormalizer.CollapseSpaces(name);
        if (name.Length > NameMaxLength)
        {
            AddNotification(Fields.Name, $"O nome do marketplace deve ter no máximo {NameMaxLength} caracteres.");
            return;
        }

        Name = name;
        NormalizedName = TextNormalizer.ToKey(name);
    }

    public static class Fields
    {
        public const string Name = "marketplace";
    }
}
