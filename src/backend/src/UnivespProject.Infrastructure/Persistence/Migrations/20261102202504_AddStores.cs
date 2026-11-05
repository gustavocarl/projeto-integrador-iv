using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddStores : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_products_Sku",
                table: "products");

            migrationBuilder.DropIndex(
                name: "IX_marketplaces_NormalizedName",
                table: "marketplaces");

            migrationBuilder.AddColumn<int>(
                name: "Areas",
                table: "users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "Role",
                table: "users",
                type: "character varying(10)",
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "users",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "sales_imports",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "sales_exports",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "sales",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "products",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "StoreId",
                table: "marketplaces",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.CreateTable(
                name: "stores",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Code = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: false),
                    UpdatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_stores", x => x.Id);
                });

            // Data from before stores existed goes to one store ("Minha loja", renamable by the admin);
            // every existing user becomes its admin. Nothing to do on an empty database.
            migrationBuilder.Sql("""
                DO $$
                DECLARE new_store uuid := gen_random_uuid();
                BEGIN
                    IF EXISTS (SELECT 1 FROM users) OR EXISTS (SELECT 1 FROM products)
                       OR EXISTS (SELECT 1 FROM marketplaces) OR EXISTS (SELECT 1 FROM sales_imports)
                       OR EXISTS (SELECT 1 FROM sales_exports) THEN
                        INSERT INTO stores ("Id", "Name", "Code", "CreatedBy", "CreatedAt")
                        VALUES (new_store, 'Minha loja',
                                upper(translate(substr(md5(random()::text), 1, 8), '01', 'ZY')),
                                'system', now());
                        UPDATE users SET "StoreId" = new_store, "Role" = 'Admin', "Areas" = 63;
                        UPDATE products SET "StoreId" = new_store;
                        UPDATE marketplaces SET "StoreId" = new_store;
                        UPDATE sales_imports SET "StoreId" = new_store;
                        UPDATE sales SET "StoreId" = new_store;
                        UPDATE sales_exports SET "StoreId" = new_store;
                    END IF;
                END $$;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_users_StoreId",
                table: "users",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_sales_imports_StoreId",
                table: "sales_imports",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_sales_exports_StoreId",
                table: "sales_exports",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_sales_StoreId",
                table: "sales",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_products_StoreId",
                table: "products",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_products_StoreId_Sku",
                table: "products",
                columns: new[] { "StoreId", "Sku" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_marketplaces_StoreId",
                table: "marketplaces",
                column: "StoreId");

            migrationBuilder.CreateIndex(
                name: "IX_marketplaces_StoreId_NormalizedName",
                table: "marketplaces",
                columns: new[] { "StoreId", "NormalizedName" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_stores_Code",
                table: "stores",
                column: "Code",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_marketplaces_stores_StoreId",
                table: "marketplaces",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_products_stores_StoreId",
                table: "products",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_stores_StoreId",
                table: "sales",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_exports_stores_StoreId",
                table: "sales_exports",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_imports_stores_StoreId",
                table: "sales_imports",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_users_stores_StoreId",
                table: "users",
                column: "StoreId",
                principalTable: "stores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_marketplaces_stores_StoreId",
                table: "marketplaces");

            migrationBuilder.DropForeignKey(
                name: "FK_products_stores_StoreId",
                table: "products");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_stores_StoreId",
                table: "sales");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_exports_stores_StoreId",
                table: "sales_exports");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_imports_stores_StoreId",
                table: "sales_imports");

            migrationBuilder.DropForeignKey(
                name: "FK_users_stores_StoreId",
                table: "users");

            migrationBuilder.DropTable(
                name: "stores");

            migrationBuilder.DropIndex(
                name: "IX_users_StoreId",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_sales_imports_StoreId",
                table: "sales_imports");

            migrationBuilder.DropIndex(
                name: "IX_sales_exports_StoreId",
                table: "sales_exports");

            migrationBuilder.DropIndex(
                name: "IX_sales_StoreId",
                table: "sales");

            migrationBuilder.DropIndex(
                name: "IX_products_StoreId",
                table: "products");

            migrationBuilder.DropIndex(
                name: "IX_products_StoreId_Sku",
                table: "products");

            migrationBuilder.DropIndex(
                name: "IX_marketplaces_StoreId",
                table: "marketplaces");

            migrationBuilder.DropIndex(
                name: "IX_marketplaces_StoreId_NormalizedName",
                table: "marketplaces");

            migrationBuilder.DropColumn(
                name: "Areas",
                table: "users");

            migrationBuilder.DropColumn(
                name: "Role",
                table: "users");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "users");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "sales_imports");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "sales_exports");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "sales");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "products");

            migrationBuilder.DropColumn(
                name: "StoreId",
                table: "marketplaces");

            migrationBuilder.CreateIndex(
                name: "IX_products_Sku",
                table: "products",
                column: "Sku",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_marketplaces_NormalizedName",
                table: "marketplaces",
                column: "NormalizedName",
                unique: true);
        }
    }
}
