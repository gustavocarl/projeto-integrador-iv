using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class SalesImportConfiguration : StoreOwnedEntityConfiguration<SalesImport>
{
    public override void Configure(EntityTypeBuilder<SalesImport> builder)
    {
        base.Configure(builder);

        builder.ToTable("sales_imports");

        builder.Property(i => i.FileName).HasMaxLength(SalesImport.FileNameMaxLength).IsRequired();
        builder.Property(i => i.Source).HasConversion<string>().HasMaxLength(20);
        builder.Property(i => i.TotalRevenue).HasPrecision(18, 2);
        builder.HasIndex(i => i.CreatedAt);

        builder.HasMany(i => i.Sales)
            .WithOne()
            .HasForeignKey(s => s.SalesImportId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Navigation(i => i.Sales).UsePropertyAccessMode(PropertyAccessMode.Field);
    }
}
