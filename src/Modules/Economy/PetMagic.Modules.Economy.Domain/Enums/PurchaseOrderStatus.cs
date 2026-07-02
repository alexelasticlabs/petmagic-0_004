namespace PetMagic.Modules.Economy.Domain.Enums;

public static class PurchaseOrderStatus
{
    public const string Pending = "pending";

    public const string Succeeded = "succeeded";

    public const string Failed = "failed";

    public const string RefundPending = "refund_pending";

    public const string RefundRequiresManualReview = "refund_review";

    public const string Refunded = "refunded";
}
