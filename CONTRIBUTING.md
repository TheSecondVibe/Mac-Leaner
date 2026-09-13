# Contributing to Mac-Leaner

Thanks for your interest in improving Mac-Leaner, a native SwiftUI storage cleaner and menu bar app for macOS. Mac-Leaner deletes files on real machines, so safety and correctness come before new features. Please read the [safety rules](#safety-rules-for-contributions) before opening a pull request.

For anything bigger than a small fix, please open an issue first so we can agree on the approach before you put time into it.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 16 or newer, or another Swift 6 toolchain
- Nothing else: the package uses only Apple frameworks and has no third-party dependencies

## Build and run

```bash
git clone https://github.com/TheSecondVibe/Mac-Leaner.git
cd Mac-Leaner
swift build
swift run MacLeaner
```

For UI work, screenshots, or any time you don't want the app scanning your own disk, use demo mode:

```bash
swift run MacLeaner --demo
```

Demo mode fills the app with realistic fake data and never touches the disk.

You can also run `open Package.swift` to work in Xcode and use the `MacLeaner` scheme. Add `--demo` under the scheme's run arguments to get demo mode there.

## Tests

```bash
swift test
```

The tests use Swift Testing. Any change to scanning or cleaning logic needs tests. Changes to `SafetyPolicy` need tests for what is allowed and for what must be rejected. Tests must never touch real user data, so create any fixtures in a temporary directory.

## Packaging

```bash
./scripts/build_app.sh
open build/Mac-Leaner.app
```

This builds a universal (Apple silicon and Intel) release bundle at `build/Mac-Leaner.app`. The marketing version comes from the `VERSION` file at the repository root. To override it, set the `VERSION` environment variable. `BUILD_NUMBER` sets the bundle build number:

```bash
VERSION=1.2.0 BUILD_NUMBER=42 ./scripts/build_app.sh
```

CI builds the releases. Pushing a tag such as `v1.2.0` runs `.github/workflows/release.yml`, which runs the tests, packages the app and attaches `Mac-Leaner-1.2.0.zip` and its SHA-256 checksum to a GitHub release.

## Regenerating the app icon

The icon is drawn in code. After you edit `scripts/make_icon.swift`, run:

```bash
swift scripts/make_icon.swift
```

This writes `Assets/AppIcon.icns`, which is bundled into the app, and `Assets/AppIcon.png`, which the docs use. Commit both files, then run `./scripts/build_app.sh` again to bundle the new icon.

## Code layout

```text
Sources/MacLeaner/
  App/        Entry point and scenes, AppModel (app state), Preferences, SnapshotExporter
  Models/     Categories, cleanable items, clean reports, system metrics
  Services/   Disk scanning, cleaning and safety checks
              KnownLocations.swift every fixed location Mac-Leaner knows about
              SafetyPolicy.swift   validates every path before it is deleted or trashed
              CleanerEngine.swift  performs permanent deletion and Move to Trash
  Design/     Design tokens: brand and semantic colors, spacing, button styles, surfaces
  Views/      SwiftUI screens; Views/Components holds shared pieces (rows, ring, logo)
Tests/        Swift Testing suites
scripts/      build_app.sh (packaging), make_icon.swift (icon rendering)
Assets/       App icon (.icns and .png)
VERSION       Marketing version used by build_app.sh
```

`SafetyPolicy.swift` and `CleanerEngine.swift` are safety-critical. Pull requests that touch either file get extra review, so explain in the description why the change is safe.

## Safety rules for contributions

Mac-Leaner is only useful if people can trust it. Pull requests that break any of these rules will not be merged.

1. **Every cleanable location goes through `SafetyPolicy` and is covered by tests.** Fixed locations are declared once in `Services/KnownLocations.swift`, and `Services/SafetyPolicy.swift` only allows permanent deletion inside those entries (plus caches, logs and the Trash). A new location needs tests showing that the intended paths are accepted and nearby paths are rejected: parent directories, the home folder, and paths reached through symlinks or `..`. Don't delete or move files anywhere except `CleanerEngine`, and never bypass `SafetyPolicy`.
2. **Permanent deletion is only for data that regenerates automatically**, such as caches, logs and build products that apps and tools recreate on their own.
3. **Anything the user created goes to the Trash.** Documents, virtual machines, app data and anything else that can't be recreated automatically must use Move to Trash so the user can recover it. If you're not sure which kind of data something is, treat it as user data.
4. **Nothing is ever preselected in review categories.** Every item in a review category starts unselected, and the user has to opt in to each one.
5. **No network calls.** Mac-Leaner works fully offline. Don't add networking, telemetry, analytics, crash reporting or update checks that contact a server.

## Coding guidelines

- The package uses the Swift 6 language mode with strict concurrency checking. Don't introduce new compiler warnings.
- Don't add third-party dependencies.
- Match the style of the surrounding code and keep each pull request focused on one change.
- Check UI changes in both light and dark mode. Demo mode makes this easy.

## Pull request checklist

- [ ] `swift build` and `swift test` pass locally
- [ ] New or changed cleanable locations are validated by `SafetyPolicy` and covered by tests
- [ ] Permanent deletion is used only for data that regenerates automatically, and everything else uses Move to Trash
- [ ] Nothing is preselected in review categories
- [ ] UI changes are checked in light and dark mode
- [ ] No new network access or third-party dependencies

## Reporting bugs and security issues

Use the issue forms for bugs and feature requests. Never report a security issue publicly. Follow [SECURITY.md](SECURITY.md) instead.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
