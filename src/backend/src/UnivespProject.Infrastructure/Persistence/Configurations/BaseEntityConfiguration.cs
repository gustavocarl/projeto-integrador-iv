using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Common;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

/// <summary>
/// Maps the columns every entity inherits from <see cref="BaseEntity"/>.
/// Entity configurations derive from this and call base.Configure.
/// </summary>
internal abstract class BaseEntityConfiguration<TEntity> : IEntityTypeConfiguration<TEntity>
    where TEntity : BaseEntity
{
    public virtual void Configure(EntityTypeBuilder<TEntity> builder)
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).ValueGeneratedNever();

        builder.Property(e => e.CreatedBy).HasMaxLength(254).IsRequired();
        builder.Property(e => e.UpdatedBy).HasMaxLength(254);
        builder.Property(e => e.CreatedAt).IsRequired();

        // Notifications live only in memory during validation.
        builder.Ignore(e => e.Notifications);
        builder.Ignore(e => e.IsValid);
    }
}
