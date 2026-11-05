namespace UnivespProject.Domain.Enums;

/// <summary>
/// Where the sale happened.
/// </summary>
public enum SalesChannel
{
    /// <summary>Physical store ("Presencial").</summary>
    InPerson = 1,

    /// <summary>Virtual store ("Online"), on a marketplace or outside one.</summary>
    Online = 2
}
