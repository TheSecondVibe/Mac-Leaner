# Security Policy

Mac-Leaner deletes and moves files on your Mac. We treat any bug that could make it touch files the user did not review as a security issue, and we're grateful for reports that help us find them.

## Reporting a vulnerability

Please don't report security problems in public issues, discussions or pull requests.

Report them privately through GitHub private vulnerability reporting:

**<https://github.com/TheSecondVibe/Mac-Leaner/security/advisories/new>**

You can also open the repository's **Security** tab and choose **Report a vulnerability**.

It helps if your report includes:

- The Mac-Leaner version, the macOS version and the Mac type (Apple silicon or Intel)
- What the issue is and what it could lead to
- Steps to reproduce, ideally a script or directory layout that sets up the scenario in a throwaway folder
- Any ideas for a fix

Please test only with files and accounts you own, and never put real personal data in a proof of concept.

We aim to acknowledge reports within a few days and will keep you updated while we investigate. Unless you'd rather stay anonymous, we'll credit you in the published advisory. Please keep the issue private until a fix is released.

## What counts as a security issue

- Anything that could make Mac-Leaner delete, move or read files beyond what the user reviewed and confirmed
- Path traversal or symlink escapes, for example a symbolic link, a `..` component or a path swapped between scan and cleanup that sends a cleanup outside its intended location
- Ways around `SafetyPolicy`, such as a protected location becoming cleanable
- Data deleted permanently when it should have gone to the Trash
- Privilege issues, such as Mac-Leaner running with or asking for more privileges than it needs, or a less privileged process being able to change what it deletes or moves
- Any network access or data leaving your Mac, since Mac-Leaner is designed to work fully offline

Wrong size estimates, UI glitches and crashes that don't affect which files are touched are ordinary bugs. Please report them with the bug report form.

## Supported versions

Security fixes are released only for the latest release. If you can, confirm the issue on the [latest release](https://github.com/TheSecondVibe/Mac-Leaner/releases/latest) before reporting it.

| Version        | Supported |
| -------------- | --------- |
| Latest release | Yes       |
| Older releases | No        |
