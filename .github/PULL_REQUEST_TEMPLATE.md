## Summary

<!-- What does this change do, and why? Link related issues, for example "Closes #123". -->

## Testing

<!-- How did you verify the change? List the commands you ran, your macOS version and Mac type, and add before/after screenshots for UI changes. `swift run MacLeaner --demo` shows realistic data without touching your disk. -->

## Checklist

- [ ] `swift test` passes locally
- [ ] Any new or changed cleanable location is validated by `SafetyPolicy` and covered by tests
- [ ] Permanent deletion is used only for data that regenerates automatically, anything the user created goes to the Trash, and nothing is preselected in review categories
- [ ] UI changes checked in both light and dark mode
- [ ] No new network access

The full safety rules are in [CONTRIBUTING.md](https://github.com/TheSecondVibe/Mac-Leaner/blob/main/CONTRIBUTING.md#safety-rules-for-contributions).
