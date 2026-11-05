namespace UnivespProject.Domain.Enums;

/// <summary>A user's place in their store. Stored and sent as its name ("Admin", "Member", "Pending").</summary>
public enum StoreRole
{
    /// <summary>Asked to join with the store's code; waits for an admin.</summary>
    Pending = 1,

    /// <summary>Uses the areas an admin gave them (<see cref="StoreArea"/>).</summary>
    Member = 2,

    /// <summary>Uses everything and manages the store's users.</summary>
    Admin = 3
}
