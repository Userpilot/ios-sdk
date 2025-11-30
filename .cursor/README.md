# Userpilot iOS SDK - Cursor AI Rules

This directory contains the AI assistant rules for working with the Userpilot iOS SDK codebase.

## Structure

- **`rules/code-modification-rules.md`** - ⚠️ **CRITICAL RULES** that must be followed when making any code changes
- **`rules/userpilot-sdk-rules.md`** - Comprehensive SDK architecture, patterns, and best practices

## Overview

The Userpilot iOS SDK is a native Swift framework for in-app user engagement, analytics tracking, and experience delivery. It follows a protocol-oriented architecture with zero external dependencies.

### Key Principles

1. **Protocol-Oriented Design** - All components use protocols with `-ing` suffix naming
2. **Dependency Injection** - All dependencies managed through `DIContainer`
3. **Thread Safety** - Concurrent operations with proper synchronization
4. **Zero Dependencies** - Self-contained framework with no external dependencies
5. **Comprehensive Error Handling** - All operations wrapped in `tryCatch`

### Technology Stack

- **Language**: Swift 5.3+
- **Minimum iOS**: 13.0
- **Architecture**: Protocol-oriented with DI
- **Package Managers**: SPM and CocoaPods
- **Testing**: XCTest

## Quick Reference

Before making any changes, **always** review:
1. `code-modification-rules.md` for critical modification guidelines
2. `userpilot-sdk-rules.md` for architecture patterns and conventions

## Getting Started

When working with this codebase:

1. ✅ **DO**: Follow protocol-oriented approach with `-ing` suffix naming
2. ✅ **DO**: Use `DIContainer` for all dependency injection
3. ✅ **DO**: Consider thread safety in all operations
4. ✅ **DO**: Use `tryCatch` for error handling
5. ✅ **DO**: Add proper `// MARK:` comments
6. ❌ **DON'T**: Create external dependencies
7. ❌ **DON'T**: Use force unwrapping (except fatal errors)
8. ❌ **DON'T**: Ignore memory management

