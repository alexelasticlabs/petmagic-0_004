using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddWalletBalanceNonNegativeConstraint : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // NOT VALID protects all new/updated rows immediately without scanning existing data,
            // so the deployment cannot fail because of pre-existing rows. Validation is attempted
            // right away; if legacy negative balances exist the constraint stays NOT VALID and a
            // warning is raised so operators can repair the data and VALIDATE CONSTRAINT manually.
            migrationBuilder.Sql(
                """
                ALTER TABLE economy_wallets
                    ADD CONSTRAINT "CK_economy_wallets_Balance_NonNegative" CHECK ("Balance" >= 0) NOT VALID;
                """);

            migrationBuilder.Sql(
                """
                DO $$
                BEGIN
                    ALTER TABLE economy_wallets VALIDATE CONSTRAINT "CK_economy_wallets_Balance_NonNegative";
                EXCEPTION WHEN check_violation THEN
                    RAISE WARNING 'economy_wallets contains negative balances; CK_economy_wallets_Balance_NonNegative left NOT VALID. Repair data, then run: ALTER TABLE economy_wallets VALIDATE CONSTRAINT "CK_economy_wallets_Balance_NonNegative";';
                END $$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_economy_wallets_Balance_NonNegative",
                table: "economy_wallets");
        }
    }
}
