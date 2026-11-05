using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class MarketplaceConfiguration : StoreOwnedEntityConfiguration<Marketplace>
{
    public override void Configure(EntityTypeBuilder<Marketplace> builder)
    {
        base.Configure(builder);

        builder.ToTable("marketplaces");

        builder.Property(m => m.Name).HasMaxLength(Marketplace.NameMaxLength).IsRequired();
        builder.Property(m => m.NormalizedName).HasMaxLength(Marketplace.NameMaxLength).IsRequired();
        // Unique per store: two stores can both sell on "Shopee".
        builder.HasIndex(m => new { m.StoreId, m.NormalizedName }).IsUnique();
    }
}
