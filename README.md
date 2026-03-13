# ClawStart

ClawStart is a Chinese-friendly installation entry and onboarding project for OpenClaw.

It is built for ordinary users, beginners, and mainland China users who need the shortest path from:

`download -> install -> first success -> next step`

## Why ClawStart exists

Many users do not fail because the underlying framework is bad.

They fail because the path is fragmented:

- too many platform branches
- unclear installation expectations
- no short first-run route
- troubleshooting guidance that is too technical

ClawStart exists to reduce that friction.

## What this repository contains

- a multi-page public website for installation, onboarding, and troubleshooting
- Windows and macOS packaging scripts
- a Linux Beta installer path
- fixture-based installer validation
- optional GitHub workflows for Pages, release, and validation

## Primary user flow

1. land on the site
2. choose the correct platform path
3. follow the quick start flow
4. route failures into troubleshooting
5. continue to the next meaningful step after setup

## Key pages

- `site/index.html`
  explain what ClawStart is and where to start
- `site/download.html`
  route users to the correct platform path
- `site/start.html`
  guide the shortest first-run setup flow
- `site/troubleshooting.html`
  route users by symptom
- `site/tutorial.html`
  show the first meaningful thing to do after setup
- `site/resources.html`
  provide follow-up materials

## Repository structure

```text
.
├── docs/
├── .github/workflows/
├── installer/
├── scripts/
└── site/
```

## Local preview

Preview the site:

```bash
cd site
python3 -m http.server 8080
```

Then open:

- `http://localhost:8080`

## Validation

Run installer fixture checks:

```bash
bash installer/verify-diagnose-fixtures.sh
bash installer/linux/verify-install-fixtures.sh
```

Current validation coverage includes:

- macOS diagnose fixtures
- Windows diagnose validation flow
- Linux Beta installer fixtures

## Release and deployment

- No-Actions Pages path: sync `site/` into `docs/`, then publish from `main /docs`
- Optional Pages workflow: `.github/workflows/pages.yml`
- Optional installer validation workflow: `.github/workflows/installer-validation.yml`
- Optional build and release workflow: `.github/workflows/release.yml`

If your GitHub Actions quota is limited, the recommended order is:

1. run local validation scripts
2. sync `site/` into `docs/`
3. publish GitHub Pages from `main /docs`
4. create releases manually until Actions quota is available again

## GitHub Actions strategy

For the public repository, the recommended Actions policy is:

- use only standard GitHub-hosted runners
- avoid larger runners
- keep all workflows manual with `workflow_dispatch`
- keep Pages branch deployment as the default publishing path
- keep validation and release workflows as low-frequency tools
- keep artifact retention short
- set time limits on jobs so accidental reruns do not burn time unnecessarily

The release workflow is expected to publish stable aliases such as:

- `ClawStart-Windows-latest.zip`
- `ClawStart-macOS-Apple-Silicon-latest.tar.gz`
- `ClawStart-macOS-Intel-latest.tar.gz`

## Linux Beta path

Linux is currently a secondary path compared with Windows and macOS.

The recommended Linux flow is:

1. install Node.js 20+
2. run the Linux Beta installer script
3. start from `~/.clawstart-linux-beta/launch.sh`

The manual CLI path should be treated as a fallback, not the primary entry path.

## Contributing

The highest-value contributions are:

- fixing broken download or onboarding flows
- improving installer reliability
- improving platform-specific instructions
- improving troubleshooting quality
- improving beginner-facing clarity

See:

- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- [SECURITY.md](./SECURITY.md)

## Project status

This public repository is an early version focused on:

- site clarity
- first-run success path
- installer validation
- public release hygiene

## License

This repository uses the MIT License.
