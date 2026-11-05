using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Configurations;

internal sealed class SalesExportConfiguration : StoreOwnedEntityConfiguration<SalesExport>
{
    public override void Configure(EntityTypeBuilder<SalesExport> builder)
    {
        base.Configure(builder);

        builder.ToTable("sales_exports");

        builder.Property(e => e.FileName).HasMaxLength(SalesExport.FileNameMaxLength).IsRequired();
        builder.Property(e => e.PeriodLabel).HasMaxLength(SalesExport.PeriodLabelMaxLength).IsRequired();
        builder.Property(e => e.TotalRevenue).HasPrecision(18, 2);
        builder.Property(e => e.Content).IsRequired();

        // The list is shown most recent first.
        builder.HasIndex(e => e.CreatedAt);
    }
}
