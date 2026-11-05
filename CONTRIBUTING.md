# Development workflow

Use the existing shared branches in this order:

1. Start from the latest `dev`, bring `feat` up to date, and implement the feature on `feat`.
2. Commit with a descriptive prefix and push `feat`.
3. When the feature is complete, merge `feat` into `dev` using a merge commit and push `dev`.
4. Run the repository checks on `dev`. Fix failures on `feat` and merge the fix into `dev`.
5. Once checks pass and the feature is verified on `dev`, merge `dev` into `main` using a merge commit and push `main`.
6. Keep local work on `dev` between features. Synchronize `feat` from `dev` before starting the next feature.

Do not push feature work directly to `main`. Do not force-push shared branches. Keep `hotfix` and `release` separate from this normal feature flow.

Example commit messages:

- `[UPDATE] Add employee account management`
- `[UPDATE] Update mobile login UI`
- `[FIX] Hide scheduling fields for management roles`
- `[TEST] Cover account permissions and session revocation`
- `[DOCS] Document account setup and API contracts`
- `[MERGE] Merge completed feature into dev`
- `[MERGE] Promote tested dev to main`

Never commit real `.env` files, credentials, access tokens, signing keys, or build outputs. Keep fake test credentials clearly confined to tests and examples.

## Mobile checks

```powershell
flutter pub get
flutter analyze
flutter test
```

Do not build APKs as part of routine unit/widget verification. Build or run on a device when platform validation is requested and the local environment has sufficient disk space.

Configure the API with `--dart-define=API_BASE_URL=...`. Tokens must use secure storage. Platform changes require Android/iOS verification on a supported environment; iOS requires macOS.

The conventions are packaged in `.codex/skills/hr-attendance-mobile.skill`.
