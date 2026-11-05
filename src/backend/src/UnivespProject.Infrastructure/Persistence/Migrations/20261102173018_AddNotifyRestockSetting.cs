using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddNotifyRestockSetting : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "NotifyRestock",
                table: "user_settings",
                type: "boolean",
                nullable: false,
                // Existing users get the warnings on, the setting's default.
                defaultValue: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "NotifyRestock",
                table: "user_settings");
        }
    }
}
