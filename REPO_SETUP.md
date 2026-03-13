# Repo Setup Notes

This directory is prepared as the initial content for the future public repository:

- `369pie/clawstart`

## Included

- public website pages
- installer scripts
- optional GitHub workflows
- public README draft

## Not included

- internal strategy documents
- historical archive pages
- reference analysis materials
- internal agent-only guidance

## Before first public push

1. confirm `LICENSE`
2. review `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md`
3. create remote repo `369pie/clawstart`
4. push this directory as a fresh git repository
5. verify:
   - Pages deployment
   - latest release asset aliases
   - Linux Beta raw script URL

## Suggested first push

```bash
cd .oss-export/clawstart
git init
git branch -M main
git remote add origin https://github.com/369pie/clawstart.git
git add .
git commit -m "Initial public release"
git push -u origin main
```

## GitHub web setup checklist

After the first push, finish these steps in the GitHub web UI:

1. Open repository settings and confirm the default branch is `main`.
2. If you do not want to spend GitHub Actions quota, run `bash scripts/sync-site-to-docs.sh`, commit the generated `docs/` directory, then set `Settings -> Pages -> Build and deployment -> Source` to `Deploy from a branch`, `Branch = main`, `Folder = /docs`.
3. If Actions quota is available and you prefer workflow deployment, set `Settings -> Pages -> Build and deployment -> Source` to `GitHub Actions`.
4. In `About`, paste the short description and topics from `GITHUB-LAUNCH-COPY.md`.
5. If you are using Actions, rerun the initial `Deploy ClawStart to GitHub Pages` workflow after Pages is enabled.
6. If you are not using Actions, run local checks instead:
   - `bash installer/verify-diagnose-fixtures.sh`
   - `bash installer/linux/verify-install-fixtures.sh`
7. In the repository home page, confirm:
   - the README renders correctly
   - the MIT license badge is visible
   - the Pages site URL is reachable
8. When the first release is ready, create a GitHub Release using the draft copy in `GITHUB-LAUNCH-COPY.md`.

## Recommended Actions policy

For `369pie/clawstart`, the safest default is:

- publish the website from `main /docs`
- use only standard runners (`ubuntu-latest`, `windows-latest`, `macos-latest`)
- do not use larger runners
- keep workflows manual unless you later confirm you want auto-runs
- keep release artifacts short-lived
