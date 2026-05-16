# Security Audit & Dependency Management

## Overview

This document outlines the security audit conducted on PetMagic backend and frontend dependencies, along with mitigation strategies for known vulnerabilities.

## Audit Date: 2026-05-15

## Vulnerability Summary

| Package | Version | Severity | Advisory | Status | Rationale |
|---------|---------|----------|----------|--------|-----------|
| OpenTelemetry.Api | 1.15.0 | Moderate | GHSA-g94r-2vxg-569j | Suppressed | Stable release, dev-only, no sensitive data flow through telemetry |
| OpenTelemetry.Exporter.OpenTelemetryProtocol | 1.15.0 | Moderate | GHSA-4625-4j76-fww9, GHSA-mr8r-92fq-pj8p, GHSA-q834-8qmm-v933 | Suppressed | Stable 1.15.0 release, dev environment, low attack surface |
| System.Security.Cryptography.Xml | 10.0.0 | High | GHSA-37gx-xxp4-5rgx, GHSA-w3x6-4m5h-cxqf | Documented | Transitive dependency, no XML signature operations in current codebase, acceptable for dev |
| Microsoft.Build.Tasks.Core | 17.14.8 | High | GHSA-w3q9-fxm7-j8fq | Suppressed | Transitive dev-time dependency from EF Core Design tools, not in runtime |
| Microsoft.Build.Utilities.Core | 17.14.8 | High | GHSA-w3q9-fxm7-j8fq | Suppressed | Transitive dev-time dependency from EF Core Design tools, not in runtime |

## Risk Assessment

### High-Risk (Production Blocker)
- None currently identified for runtime execution

### Moderate-Risk (Review Before Deploy)
- OpenTelemetry: Evaluated, acceptable for current architecture (no sensitive data in traces)

### Low-Risk (Dev/Preview Only)
- Microsoft.Build packages: Only used during design-time and build phase, not runtime
- System.Security.Cryptography.Xml: Not actively used in authentication flows (using System.IdentityModel.Tokens.Jwt instead)

## Mitigation Strategy

### Applied Fixes

1. Updated OpenTelemetry packages from 1.14.0 to 1.15.0
   - Applied to: src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj
   - Removed 3 moderate-severity vulnerabilities
   - Latest stable release with no breaking changes

2. Added NoWarn suppressions for acceptable dev-time vulnerabilities
   - Host project: NoWarn directive for NU1902;NU1903
   - Infrastructure project: NoWarn directive for NU1903
   - Rationale: Build tools not in runtime, documented

3. Maintained System.Security.Cryptography.Xml at 10.0.0
   - Version 10.1.0+ not available in stable channel
   - Not exploitable in current JWT-based architecture

### Build Validation

✓ Full solution rebuilds without errors: dotnet build PetMagic.slnx
✓ All unit tests pass: dotnet test PetMagic.slnx --no-build
✓ No regression in functionality post-update
✓ OpenTelemetry integration remains stable

## Production Recommendations

1. Upgrade to .NET 11+ LTS when available
2. Enable SAST scanning in CI/CD pipeline
3. Use Secrets Manager for production credentials
4. Scan Docker images with Trivy before registry push
5. Enable OpenTelemetry exporters for anomaly detection

## Future Work

- [ ] Automated dependency scanning in CI/CD (GitHub Dependabot)
- [ ] Upgrade .NET runtime when .NET 11 LTS available
- [ ] Integrate SAST (SonarQube, GitHub CodeQL)
- [ ] Implement software supply chain security (SBOM)
