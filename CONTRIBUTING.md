# Contributing to Speachy

Thank you for your interest in contributing to Speachy! This document provides guidelines and instructions for contributing.

## Getting Started

1. **Fork the Repository** — Create your own fork on GitHub
2. **Clone Locally** — `git clone https://github.com/yourusername/speachy.git`
3. **Create a Branch** — `git checkout -b feature/your-feature-name`
4. **Make Changes** — Implement your feature or fix
5. **Test Thoroughly** — Build and run locally to verify functionality
6. **Commit** — Use clear, descriptive commit messages
7. **Push & Create PR** — Push to your fork and open a pull request

## Code Style Guidelines

- **Language:** English comments preferred (legacy German comments acceptable)
- **Naming:** Use descriptive, camelCase names for variables and functions
- **Organization:** Use `MARK:` comments to organize sections
- **Async:** Use async/await for asynchronous operations
- **State:** Use Observable/ObservationObject for state management
- **UI:** Use SwiftUI exclusively
- **Print Statements:** Wrap all `print()` calls in `#if DEBUG` blocks for production builds

## Before Submitting a PR

- [ ] Code builds successfully in Xcode
- [ ] No compiler warnings
- [ ] All print statements wrapped in `#if DEBUG`
- [ ] Changes are focused (avoid mixing unrelated features)
- [ ] Commit messages are clear and descriptive
- [ ] No hardcoded API keys, secrets, or sensitive data

## Areas for Contribution

### Bug Fixes

If you find a bug, please open an issue first describing:
- Steps to reproduce
- Expected behavior
- Actual behavior
- Your macOS version and Xcode version

### Feature Requests

Before implementing a new feature, open an issue to discuss:
- Use case and motivation
- Proposed implementation approach
- Impact on existing functionality

### Ideas for Enhancement

- Custom hotkey configuration UI
- Floating recording indicator with audio visualization
- Support for additional transcription services
- Integration with other AI models
- Output formats (save to file, etc.)
- Keyboard shortcut customization

## Testing

- Test in multiple applications (Mail, Notes, TextEdit, etc.)
- Verify with different languages and audio quality
- Ensure Accessibility and Microphone permissions work correctly
- Test error scenarios (invalid API key, network issues, etc.)

## License

By contributing to Speachy, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to open an issue or reach out to the maintainer. We appreciate your interest in improving Speachy!
