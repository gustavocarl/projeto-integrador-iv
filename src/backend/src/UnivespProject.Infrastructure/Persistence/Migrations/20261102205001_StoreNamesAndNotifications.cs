using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UnivespProject.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class StoreNamesAndNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_stores_Code",
                table: "stores");

            migrationBuilder.DropColumn(
                name: "Code",
                table: "stores");

            migrationBuilder.AddColumn<string>(
                name: "NormalizedName",
                table: "stores",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            // Same key as TextNormalizer.ToKey (spaces collapsed, no accents, upper case). Stores that
            // would end up with the same name get a number, so the unique index can be created.
            migrationBuilder.Sql("""
                update stores set "NormalizedName" = upper(translate(
                    regexp_replace(trim("Name"), '\s+', ' ', 'g'),
                    'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
                    'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'));
                with repeated as (
                    select "Id", row_number() over (partition by "NormalizedName" order by "CreatedAt") as n
                    from stores)
                update stores s set "Name" = left(s."Name", 94) || ' (' || r.n || ')',
                                    "NormalizedName" = left(s."NormalizedName", 94) || ' (' || r.n || ')'
                from repeated r where r."Id" = s."Id" and r.n > 1;
                """);

            migrationBuilder.CreateTable(
                name: "notifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Kind = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Message = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    RelatedUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: false),
                    UpdatedBy = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_notifications_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_stores_NormalizedName",
                table: "stores",
                column: "NormalizedName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_notifications_RelatedUserId",
                table: "notifications",
                column: "RelatedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_notifications_UserId_CreatedAt",
                table: "notifications",
                columns: new[] { "UserId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "notifications");

            migrationBuilder.DropIndex(
                name: "IX_stores_NormalizedName",
                table: "stores");

            migrationBuilder.DropColumn(
                name: "NormalizedName",
                table: "stores");

            migrationBuilder.AddColumn<string>(
                name: "Code",
                table: "stores",
                type: "character varying(8)",
                maxLength: 8,
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql("""
                update stores set "Code" = upper(translate(substr(md5(random()::text || "Id"::text), 1, 8), '01', 'ZY'));
                """);

            migrationBuilder.CreateIndex(
                name: "IX_stores_Code",
                table: "stores",
                column: "Code",
                unique: true);
        }
    }
}
