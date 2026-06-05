using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Economy.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(EconomyDbContext))]
    [Migration("20260604221000_AddEconomySavedPaymentMethodHotPathIndex")]
    public partial class AddEconomySavedPaymentMethodHotPathIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_espm_UserId_Provider_Active_Default_Updated",
                table: "economy_saved_payment_methods",
                columns: new[] { "UserId", "Provider", "IsActive", "IsDefault", "UpdatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_espm_UserId_Provider_Active_Default_Updated",
                table: "economy_saved_payment_methods");
        }
    }
}
