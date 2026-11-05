using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class UserConfiguration : BaseEntityConfiguration<User>
{
    public override void Configure(EntityTypeBuilder<User> builder)
    {
        base.Configure(builder);

        builder.ToTable("users");

        builder.Property(u => u.Name).HasMaxLength(User.NameMaxLength).IsRequired();
        builder.Property(u => u.Email).HasMaxLength(User.EmailMaxLength).IsRequired();
        builder.Property(u => u.PasswordHash).IsRequired();

        builder.HasIndex(u => u.Email).IsUnique();

        builder.Property(u => u.Role).HasConversion<string>().HasMaxLength(10);
        // Flags as a number (sum of StoreArea values).
        builder.Property(u => u.Areas).HasConversion<int>();
        builder.Ignore(u => u.HasStoreAccess);
        builder.Ignore(u => u.IsStoreAdmin);
        builder.Ignore(u => u.EffectiveAreas);
        builder.HasOne(u => u.Store).WithMany().HasForeignKey(u => u.StoreId).OnDelete(DeleteBehavior.Restrict);
    }
}
