using System.Net.Mail;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Domain.Entities;

public sealed class User : BaseEntity
{
    public const int NameMaxLength = 150;
    public const int EmailMaxLength = 254;

    public string Name { get; private set; } = string.Empty;
    public string Email { get; private set; } = string.Empty;
    public string PasswordHash { get; private set; } = string.Empty;
    public DateTime? LastLoginAt { get; private set; }

    /// <summary>The user's store (null = none yet, or removed from it).</summary>
    public Guid? StoreId { get; private set; }
    public Store? Store { get; private set; }
    public StoreRole? Role { get; private set; }

    /// <summary>Areas an admin gave to this member. Admins use <see cref="EffectiveAreas"/> (all).</summary>
    public StoreArea Areas { get; private set; }

    // Required by Entity Framework.
    private User() { }

    /// <summary>
    /// Creates a user and validates name and e-mail. Check <see cref="Notifications.Notifiable.IsValid"/> afterwards.
    /// The password hash is set with <see cref="SetPasswordHash"/> once the password itself has been accepted.
    /// </summary>
    public User(string name, string email)
    {
        SetName(name);
        SetEmail(email);
        CreatedBy = Email;
    }

    public void SetName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            AddNotification(Fields.Name, "O nome é obrigatório.");
            return;
        }

        name = name.Trim();
        if (name.Length > NameMaxLength)
        {
            AddNotification(Fields.Name, $"O nome deve ter no máximo {NameMaxLength} caracteres.");
            return;
        }

        Name = name;
    }

    public void SetEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            AddNotification(Fields.Email, "O e-mail é obrigatório.");
            return;
        }

        email = NormalizeEmail(email);
        if (email.Length > EmailMaxLength || !MailAddress.TryCreate(email, out var parsed) || parsed.Address != email)
        {
            AddNotification(Fields.Email, "O e-mail informado é inválido.");
            return;
        }

        Email = email;
    }

    public void SetPasswordHash(string passwordHash)
    {
        if (string.IsNullOrWhiteSpace(passwordHash))
        {
            AddNotification(Fields.Password, "A senha é obrigatória.");
            return;
        }

        PasswordHash = passwordHash;
    }

    /// <summary>
    /// Records a successful login. Happens before authentication, so the user is the author of the change.
    /// </summary>
    public void RegisterLogin()
    {
        LastLoginAt = DateTime.UtcNow;
        UpdatedBy = Email;
    }

    /// <summary>Opens a new store: the user becomes its admin (every area).</summary>
    public void OpenStore(Store store) => SetStore(store, StoreRole.Admin, StoreArea.All);

    /// <summary>Asks to join an existing store; nothing is accessible until an admin approves.</summary>
    public void RequestAccess(Store store) => SetStore(store, StoreRole.Pending, StoreArea.None);

    /// <summary>Approves a pending request with the areas the admin chose.</summary>
    public void Approve(StoreArea areas)
    {
        Role = StoreRole.Member;
        Areas = areas & StoreArea.All;
    }

    /// <summary>Admin ↔ member. A new admin gets every area; a demoted admin keeps them until changed.</summary>
    public void ChangeRole(StoreRole role)
    {
        Role = role;
        if (role == StoreRole.Admin)
            Areas = StoreArea.All;
    }

    /// <summary>Areas of a member (admins always have all of them).</summary>
    public void SetAreas(StoreArea areas) => Areas = areas & StoreArea.All;

    /// <summary>Removed by an admin (or the request was refused): no store until they open or join one.</summary>
    public void LeaveStore()
    {
        StoreId = null;
        Store = null;
        Role = null;
        Areas = StoreArea.None;
    }

    private void SetStore(Store store, StoreRole role, StoreArea areas)
    {
        Store = store;
        StoreId = store.Id;
        Role = role;
        Areas = areas;
    }

    /// <summary>Approved in a store (member or admin).</summary>
    public bool HasStoreAccess => StoreId is not null && Role is StoreRole.Member or StoreRole.Admin;

    public bool IsStoreAdmin => StoreId is not null && Role == StoreRole.Admin;

    /// <summary>What the user may use: everything for admins, nothing without access.</summary>
    public StoreArea EffectiveAreas => !HasStoreAccess ? StoreArea.None : IsStoreAdmin ? StoreArea.All : Areas;

    /// <summary>True when the user may use at least one of <paramref name="areas"/>.</summary>
    public bool CanUseAny(StoreArea areas) => (EffectiveAreas & areas) != StoreArea.None;

    /// <summary>
    /// Trims and lower-cases the e-mail, so the same address never differs only by casing.
    /// </summary>
    public static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    /// <summary>
    /// Notification keys, matching the JSON field names the frontend sends.
    /// </summary>
    public static class Fields
    {
        public const string Name = "name";
        public const string Email = "email";
        public const string Password = "password";
    }
}
