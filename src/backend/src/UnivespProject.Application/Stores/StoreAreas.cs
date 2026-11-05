using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Stores;

/// <summary>Converts <see cref="StoreArea"/> flags to and from the names used in JSON.</summary>
public static class StoreAreas
{
    /// <summary>Every single area, in the app's menu order.</summary>
    public static readonly IReadOnlyList<StoreArea> Each =
    [
        StoreArea.Products, StoreArea.Checkout, StoreArea.Imports,
        StoreArea.Exports, StoreArea.Comparison, StoreArea.Analytics
    ];

    public static IReadOnlyList<string> ToNames(StoreArea areas) =>
        Each.Where(a => areas.HasFlag(a)).Select(a => a.ToString()).ToArray();

    /// <summary>
    /// Names (any casing) → flags. Unknown names are returned in <paramref name="unknown"/>; numbers
    /// are not accepted. An empty list is valid (a member with no area yet).
    /// </summary>
    public static StoreArea Parse(IEnumerable<string> names, out IReadOnlyList<string> unknown)
    {
        var result = StoreArea.None;
        var invalid = new List<string>();
        foreach (var name in names)
        {
            var match = Each.FirstOrDefault(a => string.Equals(a.ToString(), name?.Trim(), StringComparison.OrdinalIgnoreCase));
            if (match == StoreArea.None)
                invalid.Add(name ?? string.Empty);
            else
                result |= match;
        }

        unknown = invalid;
        return result;
    }
}
