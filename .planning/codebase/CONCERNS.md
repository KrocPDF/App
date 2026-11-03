# Technical Concerns & Future Roadmap Gaps

## Current Technical Debt & Risks
1. **Unverified iOS Build:**
   - As documented in ADR D-007, iOS builds and plugin configurations have not yet been compiled or validated on a physical macOS runner.
2. **Missing CI/CD Pipeline:**
   - The repository currently lacks automated GitHub Actions workflows to verify `flutter analyze` and `flutter test` on pull requests.
3. **Open-Source & Governance Assets Missing:**
   - Standard open-source repository files are missing: `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, and issue/PR templates.
4. **Cloud Processing Service Stub:**
   - `CloudProcessingService` currently throws `UnimplementedError()`. An actual backend API and authentication contract need to be established before Non-Confidential Mode can be enabled.
5. **Direct Dependency Pinning Maintenance:**
   - Strict version pinning prevents unexpected breaking changes but requires deliberate testing and updates for security patches.

