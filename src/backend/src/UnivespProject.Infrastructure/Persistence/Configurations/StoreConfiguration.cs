using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class StoreConfiguration : BaseEntityConfiguration<Store>
{
    public override void Configure(EntityTypeBuilder<Store> builder)
    {
        base.Configure(builder);

        builder.ToTable("stores");

        builder.Property(s => s.Name).HasMaxLength(Store.NameMaxLength).IsRequired();
        // Unique: typing an existing name asks that store for access instead of opening another one.
        builder.Property(s => s.NormalizedName).HasMaxLength(Store.NameMaxLength).IsRequired();
        builder.HasIndex(s => s.NormalizedName).IsUnique();
    }
}
