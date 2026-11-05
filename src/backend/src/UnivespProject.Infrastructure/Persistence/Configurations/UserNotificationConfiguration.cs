using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class UserNotificationConfiguration : BaseEntityConfiguration<UserNotification>
{
    public override void Configure(EntityTypeBuilder<UserNotification> builder)
    {
        base.Configure(builder);

        builder.ToTable("notifications");

        builder.Property(n => n.Kind).HasConversion<string>().HasMaxLength(30);
        builder.Property(n => n.Message).HasMaxLength(UserNotification.MessageMaxLength).IsRequired();
        builder.Ignore(n => n.IsRead);

        // Deleting a user deletes the notifications they received.
        builder.HasOne<User>().WithMany().HasForeignKey(n => n.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasIndex(n => new { n.UserId, n.CreatedAt });
        builder.HasIndex(n => n.RelatedUserId);
    }
}
