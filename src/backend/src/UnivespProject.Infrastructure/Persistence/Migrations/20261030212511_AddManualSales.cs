using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddManualSales : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "sales_imports",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                // Every batch before this migration came from a spreadsheet.
                defaultValue: "Spreadsheet");

            migrationBuilder.AlterColumn<int>(
                name: "RowNumber",
                table: "sales",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Source",
                table: "sales_imports");

            migrationBuilder.AlterColumn<int>(
                name: "RowNumber",
                table: "sales",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);
        }
    }
}
