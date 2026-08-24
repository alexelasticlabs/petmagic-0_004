using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AlignPremiumAllowanceAndTestPackPrices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_subscription_plans
                SET "MonthlyTokenLimit" = 40,
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Id" IN ('monthly', 'yearly');

                UPDATE economy_currency_packs
                SET "PriceAmount" = CASE "Code"
                    WHEN 'starter' THEN 0.99
                    WHEN 'creator' THEN 1.49
                    WHEN 'viral' THEN 1.99
                    ELSE "PriceAmount"
                END
                WHERE "Code" IN ('starter', 'creator', 'viral')
                  AND "CurrencyCode" IN ('USD', 'EUR');
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_subscription_plans
                SET "MonthlyTokenLimit" = CASE "Id"
                    WHEN 'monthly' THEN 500
                    WHEN 'yearly' THEN 1000
                    ELSE "MonthlyTokenLimit"
                END,
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Id" IN ('monthly', 'yearly');

                UPDATE economy_currency_packs
                SET "PriceAmount" = CASE
                    WHEN "CurrencyCode" = 'USD' AND "Code" = 'starter' THEN 6.99
                    WHEN "CurrencyCode" = 'USD' AND "Code" = 'creator' THEN 14.99
                    WHEN "CurrencyCode" = 'USD' AND "Code" = 'viral' THEN 29.99
                    WHEN "CurrencyCode" = 'EUR' AND "Code" = 'starter' THEN 6.29
                    WHEN "CurrencyCode" = 'EUR' AND "Code" = 'creator' THEN 13.49
                    WHEN "CurrencyCode" = 'EUR' AND "Code" = 'viral' THEN 26.99
                    ELSE "PriceAmount"
                END
                WHERE "Code" IN ('starter', 'creator', 'viral')
                  AND "CurrencyCode" IN ('USD', 'EUR');
                """);
        }
    }
}
