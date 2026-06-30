using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<PaymentMethodSetupResponse>> CreatePaymentMethodSetupAsync(
        CreatePaymentMethodSetupCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PaymentMethodSetupResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PaymentMethodSetupResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var customerResult = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, null, cancellationToken);
        if (customerResult.IsFailure)
        {
            return Result.Failure<PaymentMethodSetupResponse>(customerResult.Error);
        }

        var setupResult = await paymentGateway.CreatePaymentMethodSetupAsync(
            new PaymentMethodSetupCreateRequest(provider, command.UserId, customerResult.Value.ExternalCustomerId, stripeApiKey),
            cancellationToken);

        if (setupResult.IsFailure)
        {
            return Result.Failure<PaymentMethodSetupResponse>(setupResult.Error);
        }

        return Result.Success(new PaymentMethodSetupResponse(
            provider,
            setupResult.Value.ExternalSetupId,
            setupResult.Value.CheckoutUrl));
    }

    public async Task<Result> RemovePaymentMethodAsync(RemovePaymentMethodCommand command, CancellationToken cancellationToken)
    {
        var method = await dbContext.SavedPaymentMethods
            .FirstOrDefaultAsync(x => x.Id == command.PaymentMethodId && x.UserId == command.UserId && x.IsActive, cancellationToken);

        if (method is null)
        {
            return Result.Failure(EconomyErrors.PaymentMethodNotFound);
        }

        var detachResult = await paymentGateway.DetachPaymentMethodAsync(
            new PaymentMethodDetachRequest(method.Provider, method.ExternalPaymentMethodId),
            cancellationToken);

        if (detachResult.IsFailure)
        {
            return Result.Failure(detachResult.Error);
        }

        method.IsActive = false;
        method.IsDefault = false;
        method.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }
}
