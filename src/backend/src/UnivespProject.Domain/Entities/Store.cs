using UnivespProject.Domain.Common;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A store: its users share products, sales and batches. The name is unique (compared without
/// accents, casing or extra spaces): typing an existing name on sign-up asks its admins for access.
/// </summary>
public sealed class Store : BaseEntity
{
    public const int NameMaxLength = 100;

    public string Name { get; private set; } = string.Empty;

    /// <summary>Unique comparison key (see <see cref="TextNormalizer.ToKey"/>).</summary>
    public string NormalizedName { get; private set; } = string.Empty;

    // Required by Entity Framework.
    private Store() { }

    public Store(string? name) => Rename(name);

    /// <summary>Validates and sets the name; nothing changes when invalid.</summary>
    public bool Rename(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            AddNotification(Fields.Name, "Informe o nome da loja.");
            return false;
        }

        name = TextNormalizer.CollapseSpaces(name);
        if (name.Length > NameMaxLength)
        {
            AddNotification(Fields.Name, $"O nome da loja deve ter no máximo {NameMaxLength} caracteres.");
            return false;
        }

        Name = name;
        NormalizedName = KeyOf(name);
        return true;
    }

    /// <summary>How store names are compared ("Loja  da Maria" = "loja da maría").</summary>
    public static string KeyOf(string name) => TextNormalizer.ToKey(name);

    public static class Fields
    {
        public const string Name = "name";
    }
}
