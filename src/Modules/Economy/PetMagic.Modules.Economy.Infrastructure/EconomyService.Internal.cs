using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private StripeClient CreateStripeClient(string apiKey)
    {
        return new StripeClient(apiKey);
    }
}
