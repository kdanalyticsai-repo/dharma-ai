# DharmaAI - Download All 18 Bhagavad Gita Chapter MP3s
# Source : archive.org/details/03-chapter-2_202505
# Audio  : Sri Radhe-Krishn Mandir, Derveshpur (UP) — used with permission.
# License: Public Domain Mark 1.0 (commercial use permitted by the temple).

$outputDir = "$PSScriptRoot\gita_audio"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$baseUrl = "https://archive.org/download/03-chapter-2_202505"

# Source filenames: 02Chapter1.mp3 .. 19Chapter18.mp3 (track# = chapter+1)
$chapters = @()
for ($n = 1; $n -le 18; $n++) {
    $chapters += @{
        n    = $n
        src  = ("{0:D2}Chapter{1}.mp3" -f ($n + 1), $n)
        dest = ("bg_ch{0:D2}.mp3" -f $n)
    }
}

Write-Host ""
Write-Host "  DharmaAI - Bhagavad Gita Audio Downloader" -ForegroundColor Cyan
Write-Host "  Source: archive.org/details/bhagavad-gita-chanting" -ForegroundColor DarkGray
Write-Host ""

$success = 0
$failed  = @()

foreach ($ch in $chapters) {
    $url      = "$baseUrl/$($ch.src)"
    $destPath = "$outputDir\$($ch.dest)"

    if (Test-Path $destPath) {
        $sizeMB = [math]::Round((Get-Item $destPath).Length / 1MB, 1)
        Write-Host "  [OK] Chapter $($ch.n) already exists ($sizeMB MB)" -ForegroundColor Green
        $success++
        continue
    }

    Write-Host "  [..] Chapter $($ch.n) - $($ch.src) ..." -ForegroundColor Yellow -NoNewline

    try {
        Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing `
            -Headers @{ "User-Agent" = "Mozilla/5.0 (compatible; DharmaAI/1.0)" } `
            -TimeoutSec 120 -ErrorAction Stop

        $sizeMB = [math]::Round((Get-Item $destPath).Length / 1MB, 1)
        Write-Host " $sizeMB MB [OK]" -ForegroundColor Green
        $success++
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failed += $ch.n
        if (Test-Path $destPath) { Remove-Item $destPath -Force }
    }
}

Write-Host ""
Write-Host "  -----------------------------------" -ForegroundColor DarkGray
Write-Host "  Downloaded : $success / $($chapters.Count) chapters" -ForegroundColor Cyan

if ($failed.Count -gt 0) {
    Write-Host "  Failed Ch# : $($failed -join ', ')" -ForegroundColor Red
}

if ($success -gt 0) {
    Write-Host ""
    Write-Host "  Files ready in: $outputDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  NEXT STEP - Upload to Cloudflare R2:" -ForegroundColor Cyan
    Write-Host "  1. dash.cloudflare.com > R2 > Create bucket > dharma-audio" -ForegroundColor White
    Write-Host "  2. Bucket Settings > Public Access > Allow Access" -ForegroundColor White
    Write-Host "  3. Upload all bg_ch*.mp3 files from: $outputDir" -ForegroundColor White
    Write-Host "  4. Paste the public URL into lib/config/r2_config.dart" -ForegroundColor White
    Start-Process explorer.exe $outputDir
}
