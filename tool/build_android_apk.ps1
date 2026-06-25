param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$flutter = 'C:\flutter-sdk\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
  throw "Flutter not found at $flutter"
}

& $flutter pub get
if ($LASTEXITCODE -ne 0) {
  throw "flutter pub get failed"
}

$dart = Join-Path (Split-Path $flutter -Parent) 'cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dart)) {
  throw "Dart not found at $dart"
}

& $dart run tool\patch_fast_paddle_ocr_dict.dart
if ($LASTEXITCODE -ne 0) {
  throw "fast_paddle_ocr dictionary patch failed"
}

if ($Mode -eq 'release') {
  & $flutter build apk --release
} else {
  & $flutter build apk --debug
}

if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk failed"
}

$artifactDir = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

$builtApk = if ($Mode -eq 'release') {
  Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
} else {
  Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
}

$latestApk = Join-Path $artifactDir 'latest.apk'
try {
  Copy-Item -Force $builtApk $latestApk
} catch {
  $fallbackApk = Join-Path $artifactDir ('EventMate-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.apk')
  Write-Warning "Could not refresh latest.apk: $($_.Exception.Message)"
  Copy-Item -Force $builtApk $fallbackApk
  Write-Host "Fallback APK copy: $fallbackApk"
}

$origin = (git remote get-url origin).Trim()
$repoPath = $null
if ($origin -match 'github\.com[:/](?<path>.+?)(\.git)?$') {
  $repoPath = $Matches['path']
}

$releaseTag = 'apk-' + (Get-Date -Format 'yyyyMMdd') + '-01'
$releasePage = if ($repoPath) {
  "https://github.com/$repoPath/releases/tag/$releaseTag"
} else {
  '(set after pushing the tag)'
}
$assetUrl = if ($repoPath) {
  "https://github.com/$repoPath/releases/download/$releaseTag/app-release.apk"
} else {
  '(set after pushing the tag)'
}

Write-Host "Built APK: $builtApk"
Write-Host "Copied APK: $latestApk"
Write-Host "GitHubReleaseUrl: $releasePage"
Write-Host "GitHubReleaseAssetUrl: $assetUrl"
