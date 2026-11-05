using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options, ICurrentStore currentStore) : DbContext(options)
{
    public DbSet<Store> Stores => Set<Store>();
    public DbSet<User> Users => Set<User>();
    public DbSet<UserSettings> UserSettings => Set<UserSettings>();
    public DbSet<Marketplace> Marketplaces => Set<Marketplace>();
    public DbSet<SalesImport> SalesImports => Set<SalesImport>();
    public DbSet<Sale> Sales => Set<Sale>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<SalesExport> SalesExports => Set<SalesExport>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();

    /// <summary>Read by the query filters on every query (null = no store: nothing is visible).</summary>
    private Guid? CurrentStoreId => currentStore.Id;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Each store only sees its own data (also applies to ExecuteUpdate/ExecuteDelete).
        FilterByStore<Product>(modelBuilder);
        FilterByStore<Marketplace>(modelBuilder);
        FilterByStore<SalesImport>(modelBuilder);
        FilterByStore<Sale>(modelBuilder);
        FilterByStore<SalesExport>(modelBuilder);
    }

    private void FilterByStore<TEntity>(ModelBuilder modelBuilder) where TEntity : class, IStoreOwned =>
        modelBuilder.Entity<TEntity>().HasQueryFilter(e => e.StoreId == CurrentStoreId);
}
