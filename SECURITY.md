# Security Policy

**DO NOT DISCLOSE SECURITY-RELATED ISSUES PUBLICLY ON THE ISSUE TRACKER.**

## What are Security-Related Issues?

An issue is security-related if there is a possibility that Draftdown is vulnerable to malicious actors. This includes, but is not limited to:

- Running arbitrary code on users' machines
- Exploiting logical errors in the source code to induce unwanted behaviour
- Inadvertent disclosure of personal data

## What are *not* Security-Related Issues?

Some behaviour of the app may look like a security-related issue, and can indeed lead to security problems when used carelessly, but is actually **expected behaviour**. In particular, please refer to the [security notes by Pandoc](https://pandoc.org/MANUAL.html#a-note-on-security) for considerations relating to the document converter Draftdown uses under the hood.

Do not report a security vulnerability for intended local file read/write behaviour, as Draftdown is a desktop editor that relies on the operating system's standard file permissions.

## Which Versions Receive Security Patches?

Only the **latest released stable version** (and the current `main` branch) receives security-related patches. Releases can be found on the [GitHub Releases](https://github.com/davidyshen/MDWriter/releases) page.

## How to Report a Security Problem

If you discover a security vulnerability in Draftdown, please report it privately using GitHub's **Private Vulnerability Reporting** feature on the [Security tab](https://github.com/davidyshen/MDWriter/security/advisories) of this repository, rather than opening a public issue or pull request.

By keeping the issue hidden from public view until a fix is released, we can investigate and address the vulnerability responsibly before public disclosure.
