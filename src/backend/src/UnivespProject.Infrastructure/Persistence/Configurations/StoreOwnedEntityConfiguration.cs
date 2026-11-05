using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

/// <summary>Maps the store column of the store's data (<see cref="StoreOwnedEntity"/>).</summary>
internal abstract class StoreOwnedEntityConfiguration<TEntity> : BaseEntityConfiguration<TEntity>
    where TEntity : StoreOwnedEntity
{
    public override void Configure(EntityTypeBuilder<TEntity> builder)
    {
        base.Configure(builder);

        builder.Property(e => e.StoreId).IsRequired();
        // Stores are never deleted while they have data.
        builder.HasOne<Store>().WithMany().HasForeignKey(e => e.StoreId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(e => e.StoreId);
    }
}
