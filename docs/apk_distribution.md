# APK Distribution

This repo publishes release APKs from GitHub Actions on tags that match `apk-*`.

## Local build

```powershell
.\tool\build_android_apk.ps1 -Mode release
```

The script builds the APK locally, copies it to `dist/latest.apk`, and prints the matching GitHub release URLs when `origin` points to GitHub.

## GitHub release flow

1. Push a commit to `main`.
2. Create and push a tag such as `apk-20260624-02`.
3. GitHub Actions builds `app-release.apk`.
4. The release asset is published as `app-release.apk`.

## Mobile download

Use the release page or direct asset URL once the tag run completes.
