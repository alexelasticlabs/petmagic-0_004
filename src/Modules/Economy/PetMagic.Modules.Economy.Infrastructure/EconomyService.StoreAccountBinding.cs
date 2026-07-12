using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private Error? ResolveStoreAccountBindingError(
        StoreAccountBindingState state,
        bool alreadyLinkedToSameUser)
    {
        if (state == StoreAccountBindingState.Mismatched)
        {
            return EconomyErrors.StoreAccountBindingMismatch;
        }

        if (state == StoreAccountBindingState.Missing
            && IsStoreAccountBindingEnforced()
            && !alreadyLinkedToSameUser)
        {
            return EconomyErrors.StoreAccountBindingMissing;
        }

        return null;
    }

    private bool IsStoreAccountBindingEnforced() =>
        string.Equals(
            options.Value.StoreAccountBindingMode?.Trim(),
            "enforce",
            StringComparison.OrdinalIgnoreCase);
}
