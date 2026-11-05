using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class LinkSalesToProductsBySku : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsCheckout",
                table: "sales",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // Until now only checkout sales had a product.
            migrationBuilder.Sql("""UPDATE sales SET "IsCheckout" = TRUE WHERE "ProductId" IS NOT NULL;""");

            // Typed-in and spreadsheet sales join the registered product with the same SKU
            // (same rule as Sale.SkuKey: the SKU in upper case; products store it in upper case).
            migrationBuilder.Sql("""
                UPDATE sales s SET "ProductId" = p."Id"
                FROM products p
                WHERE s."ProductId" IS NULL AND s."Sku" IS NOT NULL AND upper(s."Sku") = p."Sku";
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Back to "a product means a checkout sale".
            migrationBuilder.Sql("""UPDATE sales SET "ProductId" = NULL WHERE NOT "IsCheckout";""");

            migrationBuilder.DropColumn(
                name: "IsCheckout",
                table: "sales");
        }
    }
}
