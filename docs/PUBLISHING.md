# Publish your source repository

This folder is the source distribution. Publish **its contents**, not the surrounding private development checkout. There is no inherited Git history, signing state or original-owner configuration.

Before upload, inspect the files and run:

```sh
python3 tools/audit_public.py --release
```

Remove generated build/ output if it exists before making a source archive. Don't upload a local vehicle profile, optional model without redistribution rights, credentials, captured reports, Xcode user data or simulator/device containers. Read .gitignore and docs/PRIVACY.md. The audit is heuristic and doesn't replace inspection.

Create an empty repository on GitHub. If using Git locally:

```sh
git init -b main
git add .
git diff --cached --stat
# Inspect the staged contents before committing.
git commit -m "Initial public source"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

Use your own Git name/email, account and authentication flow. This project includes no remote repository or publish credentials. Keep LICENSE and THIRD_PARTY_NOTICES.md. The included GitHub Actions workflow runs source checks and an unsigned simulator build when GitHub executes it; local verification does not prove that hosted workflow has run.

If using GitHub's browser upload, include the hidden .gitignore and .github files too. The downloadable ZIP is a convenient source transport; uploading only the ZIP as one repository file does not expose browsable build sources—extract it and upload the contents instead.
