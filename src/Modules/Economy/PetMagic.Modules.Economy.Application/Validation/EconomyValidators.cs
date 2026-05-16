using FluentValidation;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Application.Validation;

public sealed class ClaimWeeklyGrantCommandValidator : AbstractValidator<ClaimWeeklyGrantCommand>
{
    public ClaimWeeklyGrantCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class ClaimAdRewardCommandValidator : AbstractValidator<ClaimAdRewardCommand>
{
    public ClaimAdRewardCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class SpendBalanceCommandValidator : AbstractValidator<SpendBalanceCommand>
{
    public SpendBalanceCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(120);
    }
}

public sealed class CreditBalanceCommandValidator : AbstractValidator<CreditBalanceCommand>
{
    public CreditBalanceCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Source).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(120);
    }
}

public sealed class CreatePackPurchaseCommandValidator : AbstractValidator<CreatePackPurchaseCommand>
{
    public CreatePackPurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PackId).NotEmpty();
        RuleFor(x => x.CurrencyCode).NotEmpty().Length(3);
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
    }
}

public sealed class ConfirmPackPurchaseCommandValidator : AbstractValidator<ConfirmPackPurchaseCommand>
{
    public ConfirmPackPurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.OrderId).NotEmpty();
    }
}

public sealed class StripeWebhookCommandValidator : AbstractValidator<StripeWebhookCommand>
{
    public StripeWebhookCommandValidator()
    {
        RuleFor(x => x.RawBody).NotEmpty();
        RuleFor(x => x.StripeSignature).NotEmpty();
    }
}
