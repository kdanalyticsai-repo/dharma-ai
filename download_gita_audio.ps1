# DharmaAI - Download All 18 Bhagavad Gita Chapter MP3s
# Source : archive.org/details/bhagavad-gita-chanting
# License: Personal/private listening use (non-commercial)

$outputDir = "$PSScriptRoot\gita_audio"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$baseUrl = "https://archive.org/download/bhagavad-gita-chanting"

$chapters = @(
    @{ n=1;  src="03_CHAPTER-1.mp3";  dest="bg_ch01.mp3" },
    @{ n=2;  src="04_CHAPTER-2.mp3";  dest="bg_ch02.mp3" },
    @{ n=3;  src="05_CHAPTER-3.mp3";  dest="bg_ch03.mp3" },
    @{ n=4;  src="06_CHAPTER-4.mp3";  dest="bg_ch04.mp3" },
    @{ n=5;  src="07_CHAPTER-5.mp3";  dest="bg_ch05.mp3" },
    @{ n=6;  src="08_CHAPTER-6.mp3";  dest="bg_ch06.mp3" },
    @{ n=7;  src="09_CHAPTER-7.mp3";  dest="bg_ch07.mp3" },
    @{ n=8;  src="10_CHAPTER-8.mp3";  dest="bg_ch08.mp3" },
    @{ n=9;  src="11_CHAPTER-9.mp3";  dest="bg_ch09.mp3" },
    @{ n=10; src="12_CHAPTER-10.mp3"; dest="bg_ch10.mp3" },
    @{ n=11; src="13_CHAPTER-11.mp3"; dest="bg_ch11.mp3" },
    @{ n=12; src="14_CHAPTER-12.mp3"; dest="bg_ch12.mp3" },
    @{ n=13; src="15_CHAPTER-13.mp3"; dest="bg_ch13.mp3" },
    @{ n=14; src="16_CHAPTER-14.mp3"; dest="bg_ch14.mp3" },
    @{ n=15; src="17_CHAPTER-15.mp3"; dest="bg_ch15.mp3" },
    @{ n=16; src="18_CHAPTER-16.mp3"; dest="bg_ch16.mp3" },
    @{ n=17; src="19_CHAPTER-17.mp3"; dest="bg_ch17.mp3" },
    @{ n=18; src="20_CHAPTER-18.mp3"; dest="bg_ch18.mp3" }
)

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
