$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$sitePath = Join-Path $projectRoot "build\web"
$downloadPath = Join-Path $sitePath "downloads"

if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
  throw "APK release tidak ditemukan. Buat APK terlebih dahulu dengan flutter build apk --release."
}

Set-Location $projectRoot
if (Test-Path -LiteralPath (Join-Path $projectRoot ".env") -PathType Leaf) {
  flutter build web --dart-define-from-file=.env
} else {
  Write-Warning "File .env tidak ditemukan; fitur yang membutuhkan Supabase tidak aktif di website."
  flutter build web
}
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
Copy-Item -LiteralPath $apkPath -Destination (Join-Path $downloadPath "guriang-garut.apk") -Force
Write-Host "Website siap di $sitePath"
