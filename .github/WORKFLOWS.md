# GitHub Actions Workflows

Enterprise-grade CI/CD pipeline for LoRaCue Manager.

## Workflows

### 1. CI (Continuous Integration)

**File**: `.github/workflows/ci.yml`

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**Purpose**: Quality gate - validates every change

**Steps**:
1. Lint code (SwiftLint)
2. Check formatting (SwiftFormat)
3. Build iOS
4. Test iOS
5. Build macOS
6. Test macOS (with code coverage)

**When it runs**: Automatically on every push/PR

---

### 2. TestFlight (Beta Distribution)

**File**: `.github/workflows/testflight.yml`

**Triggers**:
- Git tags: `v*-beta` (e.g., `v1.0.0-beta`)
- Git tags: `v*-rc*` (e.g., `v1.0.0-rc1`, `v1.0.0-rc2`)
- Manual dispatch (GitHub UI)

**Purpose**: Deploy beta builds to TestFlight for testing

**Steps**:
1. Build iOS with beta version
2. Upload to TestFlight (iOS)
3. Build macOS with beta version
4. Upload to TestFlight (macOS)

**Version format**: `1.0.0-beta.123` or `1.0.0-rc1.123`

**Usage**:
```bash
# Create beta tag
git tag v1.0.0-beta
git push origin v1.0.0-beta

# Create release candidate tag
git tag v1.0.0-rc1
git push origin v1.0.0-rc1

# Or trigger manually via GitHub UI
```

---

### 3. Release (Production)

**File**: `.github/workflows/release.yml`

**Triggers**:
- Git tags: `v*.*.*` (e.g., `v1.0.0`, `v2.1.3`)
- Manual dispatch (GitHub UI)

**Purpose**: Deploy production builds to App Store

**Steps**:
1. Build iOS with release version
2. Upload to App Store Connect (iOS)
3. Build macOS with release version
4. Upload to App Store Connect (macOS)
5. Create GitHub Release with IPA and PKG

**Version format**: `1.0.0` (clean, no suffix)

**Usage**:
```bash
# Create release tag
git tag v1.0.0
git push origin v1.0.0

# Or trigger manually via GitHub UI
```

---

## Workflow Strategy

```
Feature branch
  ↓
  Push → CI runs (validate)
  ↓
  PR to develop → CI runs (validate)
  ↓
  Merge to develop → CI runs (validate)
  ↓
  Ready for beta testing?
  ↓
  git tag v1.0.0-beta → TestFlight deploys
  ↓
  More testing needed?
  ↓
  git tag v1.0.0-rc1 → TestFlight deploys
  ↓
  Ready for production?
  ↓
  Merge to main
  ↓
  git tag v1.0.0 → Release deploys to App Store
```

---

## Tag Naming Convention

| Tag Pattern | Example | Workflow | Destination |
|-------------|---------|----------|-------------|
| `v*-beta` | `v1.0.0-beta` | TestFlight | Beta testers |
| `v*-rc*` | `v1.0.0-rc1` | TestFlight | Beta testers |
| `v*.*.*` | `v1.0.0` | Release | App Store |

---

## Version Numbering

All workflows use **git-based versioning**:

- **Marketing Version**: From git tag (e.g., `v1.0.0` → `1.0.0`)
- **Build Number**: Git commit count (e.g., `123`)

### Examples

| Tag | Marketing Version | Build Number | Final Version |
|-----|-------------------|--------------|---------------|
| `v1.0.0-beta` | `1.0.0-beta` | `123` | `1.0.0-beta.123` |
| `v1.0.0-rc1` | `1.0.0-rc1` | `125` | `1.0.0-rc1.125` |
| `v1.0.0` | `1.0.0` | `130` | `1.0.0 (130)` |

---

## Manual Triggers

All workflows support manual triggering via GitHub UI:

1. Go to: **Actions** tab
2. Select workflow (CI, TestFlight, or Release)
3. Click **Run workflow**
4. Select branch (if applicable)
5. Click **Run workflow** button

---

## Required Secrets

Configure in: **Settings → Secrets and variables → Actions**

- `APPSTORE_ISSUER_ID`: App Store Connect API Issuer ID
- `APPSTORE_KEY_ID`: App Store Connect API Key ID
- `APPSTORE_PRIVATE_KEY`: App Store Connect API Private Key (P8 file content)

---

## Best Practices

### Development
- Always create PRs for code changes
- Wait for CI to pass before merging
- Use `develop` branch for active development

### Beta Testing
- Tag beta versions from `develop` branch
- Use `-beta` suffix for early testing
- Use `-rc1`, `-rc2` for release candidates

### Production Release
- Only tag releases from `main` branch
- Ensure all tests pass
- Merge `develop` to `main` before tagging
- Use clean version tags: `v1.0.0`, `v1.1.0`, etc.

### Versioning
- Follow semantic versioning: `MAJOR.MINOR.PATCH`
- Increment MAJOR for breaking changes
- Increment MINOR for new features
- Increment PATCH for bug fixes

---

## Troubleshooting

### CI Fails
- Check SwiftLint errors: `make lint`
- Check formatting: `make format`
- Run tests locally: `make test`

### TestFlight Upload Fails
- Verify secrets are configured
- Check code signing certificates
- Ensure bundle ID matches App Store Connect

### Release Upload Fails
- Verify App Store Connect app is created
- Check provisioning profiles
- Ensure version number is incremented

---

## Monitoring

View workflow runs:
- **Actions** tab in GitHub
- Filter by workflow name
- Check logs for detailed output
- View summaries for quick status

---

## Enterprise Features

✅ **Automated quality gates** - CI on every change
✅ **Separate beta/production** - Clear deployment paths
✅ **Git-based versioning** - Automatic version management
✅ **Manual control** - Can trigger any workflow manually
✅ **Comprehensive testing** - Unit + UI tests with coverage
✅ **Code quality** - Linting and formatting checks
✅ **Secure secrets** - API keys stored securely
✅ **Audit trail** - All deployments tracked in git tags
