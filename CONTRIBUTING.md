# Contributing to LoRaCue Manager

## Development Setup

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- Homebrew

### Initial Setup
```bash
# Clone the repository
git clone <repository-url>
cd loracue-manager-apple

# Install tools and git hooks
make setup
```

This will:
- Install SwiftLint, SwiftFormat, and actionlint via Homebrew
- Install git hooks for commit validation and code quality checks

## Development Workflow

### Code Quality

Before committing, ensure your code passes quality checks:

```bash
# Run linter
make lint

# Format code
make format

# Run both checks
make check
```

Git hooks will automatically run these checks before each commit.

### Building

```bash
# Build for iOS Simulator
make build-ios

# Build for macOS
make build-macos

# Run tests
make test

# Clean build artifacts
make clean
```

### Git Hooks

Three git hooks are automatically installed:

1. **commit-msg**: Validates conventional commit format
2. **pre-commit**: Runs SwiftLint, SwiftFormat, and actionlint (if workflows changed)
3. **pre-push**: Builds app for macOS and iOS to ensure no build errors

These hooks prevent commits/pushes that don't meet quality standards.

### Testing

Run tests before submitting PRs:

```bash
make test
```

Tests run on macOS and include:
- Unit tests for ViewModels and Services
- UI tests for critical user flows
- Code coverage reporting

## Commit Message Guidelines

This project follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic change)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Build system changes
- **ci**: CI/CD changes
- **chore**: Maintenance tasks

### Examples
```bash
feat(ble): add device scanning with RSSI filtering
fix: resolve connection timeout on iOS 17
docs: update README with installation steps
refactor(viewmodel): simplify state management
test: add unit tests for BLEManager
```

### Scope (optional)
Common scopes:
- `ble`: Bluetooth functionality
- `usb`: USB connectivity
- `ui`: User interface
- `config`: Configuration management
- `firmware`: Firmware updates

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes**
   - Write clean, documented code
   - Add tests for new functionality
   - Follow existing code style

3. **Commit with conventional format**
   ```bash
   git commit -m "feat(scope): description"
   ```

4. **Push and create PR**
   ```bash
   git push origin feat/your-feature-name
   ```

5. **PR Requirements**
   - All CI checks must pass
   - Code review approval required
   - Tests must pass
   - No merge conflicts

## Code Style

### Swift Style Guide
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint and SwiftFormat (configured in `.swiftlint.yml` and `.swiftformat`)
- 4 spaces for indentation
- 120 character line limit

### Best Practices
- Use `Logger` instead of `print()`
- Avoid force unwrapping (`!`) - use optional binding
- Document public APIs with DocC comments
- Use meaningful variable and function names
- Keep functions small and focused

### Architecture
- Follow MVVM pattern
- Use protocols for dependency injection
- Keep business logic in ViewModels
- Use `@MainActor` for UI-related code

## Testing Guidelines

### Unit Tests
- Test ViewModels with mock services
- Test business logic thoroughly
- Use descriptive test names: `test_functionName_condition_expectedResult`

### UI Tests
- Test critical user flows
- Use accessibility identifiers
- Keep tests maintainable and readable

### Coverage
- Aim for 80%+ code coverage
- Focus on business logic and critical paths

## Documentation

### Code Documentation
- Use DocC comments for public APIs
- Include parameter descriptions and return values
- Add usage examples for complex functionality

### README Updates
- Update README for new features
- Keep architecture diagrams current
- Document breaking changes

## Getting Help

- Check existing issues and PRs
- Review documentation in README and code comments
- Ask questions in PR discussions

## License

By contributing, you agree that your contributions will be licensed under the project's license.
