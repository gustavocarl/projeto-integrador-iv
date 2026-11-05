using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class SaleConfiguration : StoreOwnedEntityConfiguration<Sale>
{
    public override void Configure(EntityTypeBuilder<Sale> builder)
    {
        base.Configure(builder);

        builder.ToTable("sales");

        builder.Property(s => s.ProductName).HasMaxLength(Sale.ProductNameMaxLength).IsRequired();
        builder.Property(s => s.Sku).HasMaxLength(Sale.SkuMaxLength);
        builder.Property(s => s.UnitPrice).HasPrecision(18, 2);
        builder.Property(s => s.TotalPrice).HasPrecision(18, 2);
        builder.Property(s => s.Channel).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.UnitCost).HasPrecision(18, 2);
        builder.Property(s => s.TotalCost).HasPrecision(18, 2);

        // Products with sales can't be deleted (only deactivated).
        builder.HasOne<Product>()
            .WithMany()
            .HasForeignKey(s => s.ProductId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(s => s.Marketplace)
            .WithMany()
            .HasForeignKey(s => s.MarketplaceId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(s => new { s.SalesImportId, s.SaleDate });
        builder.HasIndex(s => s.MarketplaceId);
        builder.HasIndex(s => s.ProductId);
        // Month comparison filters every batch by date.
        builder.HasIndex(s => s.SaleDate);
    }
}
