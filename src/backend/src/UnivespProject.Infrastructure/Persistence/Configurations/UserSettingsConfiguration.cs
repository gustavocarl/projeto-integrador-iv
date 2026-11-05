using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class UserSettingsConfiguration : BaseEntityConfiguration<UserSettings>
{
    public override void Configure(EntityTypeBuilder<UserSettings> builder)
    {
        base.Configure(builder);

        builder.ToTable("user_settings");

        builder.Property(s => s.RequireProductImage).HasDefaultValue(false);
        builder.Property(s => s.CreateProductsOnImport).HasDefaultValue(false);
        // No model default: with a database default of true, EF would never insert false
        // (the CLR default). Existing rows get true from the migration.
        builder.Property(s => s.NotifyRestock);
        builder.Property(s => s.Theme).HasConversion<string>().HasMaxLength(10).HasDefaultValue(AppTheme.Dark);

        // One row per user; removed together with the user.
        builder.HasIndex(s => s.UserId).IsUnique();
        builder.HasOne<User>().WithOne().HasForeignKey<UserSettings>(s => s.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
