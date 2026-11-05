using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUserSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "user_settings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequireProductImage = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    CreateProductsOnImport = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    CreatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: false),
                    UpdatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_settings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_user_settings_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_user_settings_UserId",
                table: "user_settings",
                column: "UserId",
                unique: true);

            // Keeps the setting of users who already turned "require image" on (the others get the defaults).
            migrationBuilder.Sql("""
                INSERT INTO user_settings ("Id", "UserId", "RequireProductImage", "CreateProductsOnImport", "CreatedBy", "CreatedAt")
                SELECT gen_random_uuid(), "Id", TRUE, FALSE, "Email", now() AT TIME ZONE 'utc'
                FROM users
                WHERE "RequireProductImage";
                """);

            migrationBuilder.DropColumn(
                name: "RequireProductImage",
                table: "users");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "RequireProductImage",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.Sql("""
                UPDATE users u SET "RequireProductImage" = s."RequireProductImage"
                FROM user_settings s
                WHERE s."UserId" = u."Id";
                """);

            migrationBuilder.DropTable(
                name: "user_settings");
        }
    }
}
