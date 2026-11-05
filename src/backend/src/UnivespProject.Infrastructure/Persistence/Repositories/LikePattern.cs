namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal static class LikePattern
{
    /// <summary>Typed % and _ are literal characters, not wildcards (escape character: \).</summary>
    public static string Escape(string value) =>
        value.Replace(@"\", @"\\").Replace("%", @"\%").Replace("_", @"\_");
}
