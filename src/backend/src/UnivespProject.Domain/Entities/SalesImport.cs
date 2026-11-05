using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A batch of sales: one uploaded spreadsheet, or a batch the user created to type sales in.
/// Each batch is kept separately so batches can be compared. Totals are stored to list
/// batches without reading every sale.
/// </summary>
public sealed class SalesImport : StoreOwnedEntity
{
    public const int FileNameMaxLength = 255;

    private readonly List<Sale> _sales = [];

    /// <summary>The spreadsheet's file name, or the name the user gave a manual batch.</summary>
    public string FileName { get; private set; } = string.Empty;
    public ImportSource Source { get; private set; } = ImportSource.Spreadsheet;
    public int SalesCount { get; private set; }
    public int TotalQuantity { get; private set; }
    public decimal TotalRevenue { get; private set; }
    public DateOnly? PeriodStart { get; private set; }
    public DateOnly? PeriodEnd { get; private set; }

    public IReadOnlyCollection<Sale> Sales => _sales;

    // Required by Entity Framework.
    private SalesImport() { }

    public SalesImport(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
        {
            AddNotification(Fields.File, "O nome do arquivo é obrigatório.");
            return;
        }

        fileName = Path.GetFileName(fileName.Trim());
        FileName = fileName.Length > FileNameMaxLength ? fileName[..FileNameMaxLength] : fileName;
    }

    /// <summary>A batch for sales typed in by the user.</summary>
    public static SalesImport CreateManual(string? name)
    {
        var batch = new SalesImport { Source = ImportSource.Manual };
        name = string.IsNullOrWhiteSpace(name) ? null : TextNormalizer.CollapseSpaces(name);

        if (name is null)
            batch.AddNotification(Fields.Name, "Informe o nome do novo lote.");
        else if (name.Length > FileNameMaxLength)
            batch.AddNotification(Fields.Name, $"O nome do lote deve ter no máximo {FileNameMaxLength} caracteres.");
        else
            batch.FileName = name;

        return batch;
    }

    /// <summary>Name of the checkout batch of the month of <paramref name="date"/>: "Vendas - outubro/2026".</summary>
    public static string StoreBatchName(DateOnly date) => $"Vendas - {MonthNames.Label(date.Year, date.Month)}";

    /// <summary>The checkout batch of a month, created the first time something is sold in it.</summary>
    public static SalesImport CreateStoreMonth(DateOnly date) =>
        new() { Source = ImportSource.Store, FileName = StoreBatchName(date) };

    /// <summary>
    /// Adds a valid sale and updates the totals. Invalid sales are ignored; validate them first.
    /// </summary>
    public void AddSale(Sale sale)
    {
        if (!sale.IsValid)
            return;

        _sales.Add(sale);
        SalesCount++;
        TotalQuantity += sale.Quantity;
        TotalRevenue += sale.TotalPrice;

        if (PeriodStart is null || sale.SaleDate < PeriodStart)
            PeriodStart = sale.SaleDate;
        if (PeriodEnd is null || sale.SaleDate > PeriodEnd)
            PeriodEnd = sale.SaleDate;
    }

    /// <summary>
    /// Removes one sale and recalculates the totals. The sales must be loaded;
    /// returns null when the sale is not in this batch.
    /// </summary>
    public Sale? RemoveSale(Guid saleId)
    {
        var sale = _sales.FirstOrDefault(s => s.Id == saleId);
        if (sale is null)
            return null;

        _sales.Remove(sale);
        SalesCount = _sales.Count;
        TotalQuantity = _sales.Sum(s => s.Quantity);
        TotalRevenue = _sales.Sum(s => s.TotalPrice);
        PeriodStart = _sales.Count == 0 ? null : _sales.Min(s => s.SaleDate);
        PeriodEnd = _sales.Count == 0 ? null : _sales.Max(s => s.SaleDate);
        return sale;
    }

    public static class Fields
    {
        public const string File = "file";
        public const string Name = "importName";
    }
}
