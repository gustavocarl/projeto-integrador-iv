using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class ProductConfiguration : StoreOwnedEntityConfiguration<Product>
{
    public override void Configure(EntityTypeBuilder<Product> builder)
    {
        base.Configure(builder);

        builder.ToTable("products");

        builder.Property(p => p.Name).HasMaxLength(Product.NameMaxLength).IsRequired();
        builder.Property(p => p.Sku).HasMaxLength(Product.SkuMaxLength).IsRequired();
        builder.Property(p => p.Category).HasMaxLength(Product.CategoryMaxLength);
        builder.Property(p => p.SalePrice).HasPrecision(18, 2);
        builder.Property(p => p.CostPrice).HasPrecision(18, 2);
        builder.Property(p => p.ImageUrl).HasMaxLength(Product.ImageUrlMaxLength);
        builder.Ignore(p => p.IsLowStock);

        // Unique per store: two stores can use the same SKU.
        builder.HasIndex(p => new { p.StoreId, p.Sku }).IsUnique();
        builder.HasIndex(p => p.Name);
    }
}
