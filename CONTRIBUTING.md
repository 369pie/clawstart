# Contributing to ClawStart

Thanks for contributing to ClawStart.

This project is focused on one thing first:

making the first OpenClaw installation and onboarding path clearer and more reliable for Chinese-speaking users.

## Contribution priorities

High-value contributions:

- fixing broken download or onboarding flows
- improving installer reliability
- improving troubleshooting guidance
- improving platform-specific setup instructions
- clarifying beginner-facing copy
- fixing broken links, metadata, or release wiring

Lower priority contributions:

- adding new parallel pages
- adding heavy product features unrelated to install/onboarding
- expanding internal or enterprise-only concepts into the public site

## Before you start

Please check:

- the existing issue tracker
- the current user path in `site/`
- the installer scripts in `installer/`

If your change affects user-facing wording, prefer simple, beginner-friendly language.

## Local development

Preview the site:

```bash
cd site
python3 -m http.server 8080
```

Run installer validation:

```bash
bash installer/verify-diagnose-fixtures.sh
bash installer/linux/verify-install-fixtures.sh
```

## Pull request guidelines

Please keep pull requests:

- focused
- easy to review
- consistent with the current product scope

Good PRs usually include:

- what changed
- why it changed
- which user path it improves
- how it was verified

## Copy and UX rules

- prefer action-first writing
- avoid over-explaining technical concepts
- keep `ClawStart` as the main brand
- mention `OpenClaw` only where technically necessary
- treat Linux as a secondary path, with the Linux Beta script as the recommended route

## Out of scope

Please do not add:

- unrelated design overhauls
- internal planning documents
- archived legacy pages back into the main path
- experimental pages that dilute the main install flow
