using System.Runtime.CompilerServices;

using Xunit;

[assembly: CollectionBehavior(DisableTestParallelization = true)]

internal static class TestLoggingConfiguration
{
    [ModuleInitializer]
    internal static void DisableWindowsEventLogForTestHosts()
    {
        // WebApplication.CreateBuilder adds the Windows EventLog provider by default.
        // An unprivileged test process cannot write to it, which can hide the HTTP
        // response an integration test is asserting behind a logging exception.
        Environment.SetEnvironmentVariable("Logging__EventLog__LogLevel__Default", "None");
    }
}
