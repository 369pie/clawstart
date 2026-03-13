# Repo Setup Notes

This directory is prepared as the initial content for the future public repository:

- `369pie/clawstart`

## Included

- public website pages
- installer scripts
- GitHub workflows
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
