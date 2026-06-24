namespace PetMagic.Host.Api.Middleware;

public sealed class GracefulShutdownCoordinator
{
    private volatile bool _isStopping;

    public bool IsStopping => _isStopping;

    public void SignalStopping() => _isStopping = true;
}
