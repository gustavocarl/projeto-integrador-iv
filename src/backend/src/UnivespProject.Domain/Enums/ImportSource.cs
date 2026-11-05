namespace UnivespProject.Domain.Enums;

/// <summary>How a batch was created. A spreadsheet batch can still receive manual sales.</summary>
public enum ImportSource
{
    Spreadsheet = 1,
    Manual = 2,

    /// <summary>Monthly batch that receives the checkout sales ("Vendas - outubro/2026"), created automatically.</summary>
    Store = 3,
}
