# FlareSolverr-OpenClaw Installer for Windows
# Usage: curl -sSL https://raw.githubusercontent.com/Zer0-Griffin/flaresolverr-openclaw/main/install.ps1 | powershell -ExecutionPolicy Bypass -

$ErrorActionPreference = "Stop"
$InstallDir = "$env:USERPROFILE\.openclaw\flare-solverr"
$ConfigFile = Join-Path $InstallDir "config.ini"

Write-Host "[FlareSolverr-OpenClaw] Installing..." -ForegroundColor Cyan

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Write-Host "[FlareSolverr-OpenClaw] Created installation directory: $InstallDir" -ForegroundColor Green
}

# Detect browser path
$browsers = @(
    "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)

$browserPath = $null
foreach ($b in $browsers) {
    if (Test-Path $b) {
        $browserPath = $b
        break
    }
}

if (-not $browserPath) {
    Write-Host "[FlareSolverr-OpenClaw] Warning: No supported browser found. Installing from source requires Python 3.11+." -ForegroundColor Yellow
} else {
    Write-Host "[FlareSolverr-OpenClaw] Detected browser: $browserPath" -ForegroundColor Green
}

# Download precompiled Windows x64 binary
$binaryUrl = "https://github.com/FlareSolverr/FlareSolverr/releases/latest/download/FlareSolverr_Win_x64.zip"
$zipPath = Join-Path $InstallDir "flaresolverr.zip"

Write-Host "[FlareSolverr-OpenClaw] Downloading FlareSolverr binary..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $binaryUrl -OutFile $zipPath -UseBasicParsing | Out-Null
    Write-Host "[FlareSolverr-OpenClaw] Extracting..." -ForegroundColor Cyan

    # Extract only the executable
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $exeEntry = $zip.Entries | Where-Object { $_.Name -match "flaresolverr\.exe$" }

    if ($exeEntry) {
        $extractDir = Join-Path $InstallDir "bin"
        if (-not (Test-Path $extractDir)) { New-Item -ItemType Directory $extractDir | Out-Null }

        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($exeEntry, (Join-Path $extractDir $exeEntry.Name), $true)
        Write-Host "[FlareSolverr-OpenClaw] Binary installed to: $extractDir" -ForegroundColor Green
    } else {
        # Fallback: extract everything and find the exe
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $InstallDir)
        Write-Host "[FlareSolverr-OpenClaw] Extracted to installation directory." -ForegroundColor Green
    }

    $zip.Dispose()
    Remove-Item $zipPath -Force
} catch {
    Write-Host "[FlareSolverr-OpenClaw] Download failed: $_" -ForegroundColor Yellow
    Write-Host "[FlareSolverr-OpenClaw] Trying source install via pip..." -ForegroundColor Cyan

    # Source install fallback
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = "python"
    } else {
        Write-Host "[FlareSolverr-OpenClaw] ERROR: Python not found. Install Python 3.11+ and run again." -ForegroundColor Red
        exit 1
    }

    Write-Host "[FlareSolverr-OpenClaw] Cloning FlareSolverr source..." -ForegroundColor Cyan
    $srcDir = Join-Path $InstallDir "source"
    if (Test-Path $srcDir) { Remove-Item $srcDir -Recurse -Force }

    & git clone https://github.com/FlareSolverr/FlareSolverr.git $srcDir | Out-Null

    Write-Host "[FlareSolverr-OpenClaw] Installing dependencies..." -ForegroundColor Cyan
    & $pythonCmd -m pip install -r (Join-Path $srcDir "requirements.txt") 2>&1 | Out-Null

    # Set environment variables for source mode
    $env:FLARESOLVERR_URL_BASE = "http://localhost:8191"
    [Environment]::SetEnvironmentVariable("FLARESOLVERR_URL_BASE", "http://localhost:8191", "User")
}

# Write config file
$configContent = @"
[flaresolverr]
port = 8191
timeout_seconds = 60
language = en-US
browser = $($if ($browserPath) { 'chrome' } else { 'auto' })
url_base = http://localhost:8191

; Detected browser path (optional, auto-detects if empty)
# browser_path = $browserPath
"@

Set-Content -Path $ConfigFile -Value $configContent -Encoding UTF8
Write-Host "[FlareSolverr-OpenClaw] Config written to: $ConfigFile" -ForegroundColor Green

# Write startup script
$startScript = @"
# Start FlareSolverr
`$InstallDir = "$InstallDir"
`$BinaryPath = Join-Path `$InstallDir "bin\flaresolverr.exe"

if (Test-Path `$BinaryPath) {
    Write-Host "[FlareSolverr-OpenClaw] Starting FlareSolverr on port 8191..." -ForegroundColor Cyan
    Start-Process `$BinaryPath -WorkingDirectory `$InstallDir
} else {
    `$SrcMain = Join-Path `$InstallDir "source\flaresolverr.py"
    if (Test-Path `$SrcMain) {
        Write-Host "[FlareSolverr-OpenClaw] Starting FlareSolverr from source..." -ForegroundColor Cyan
        python3 -u `$SrcMain
    } else {
        Write-Host "[FlareSolverr-OpenClaw] ERROR: Could not find flaresolverr executable or source." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[FlareSolverr-OpenClaw] FlareSolverr started. Listening on http://localhost:8191" -ForegroundColor Green
"@

$startScript | Set-Content (Join-Path $InstallDir "start.ps1") -Encoding UTF8
Write-Host "[FlareSolverr-OpenClaw] Startup script written to: $(Join-Path $InstallDir 'start.ps1')" -ForegroundColor Green

# Write stop script
$stopScript = @"
# Stop FlareSolverr
Get-Process flaresolverr* | Stop-Process -Force
Write-Host "[FlareSolverr-OpenClaw] All FlareSolverr processes stopped." -ForegroundColor Yellow
"@

$stopScript | Set-Content (Join-Path $InstallDir "stop.ps1") -Encoding UTF8
Write-Host "[FlareSolverr-OpenClaw] Stop script written to: $(Join-Path $InstallDir 'stop.ps1')" -ForegroundColor Green

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$InstallDir\bin*") {
    Write-Host "[FlareSolverr-OpenClaw] Adding installation directory to PATH (user scope)..." -ForegroundColor Cyan
    $newPath = "$currentPath;$InstallDir\bin"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
}

# Auto-detect and update OpenClaw TOOLS.md if it exists
$toolsFile = "$env:USERPROFILE\.openclaw\workspace\TOOLS.md"
if (Test-Path $toolsFile) {
    $toolsContent = Get-Content $toolsFile -Raw
    if ($toolsContent -notlike "*FlareSolverr*") {
        Write-Host "[FlareSolverr-OpenClaw] Adding FlareSolverr entry to TOOLS.md..." -ForegroundColor Cyan
        $entry = @"

### FlareSolverr
- URL: http://localhost:8191/
- Used for Cloudflare bypass via web_fetch proxy
"@
        Set-Content $toolsFile ($toolsContent.TrimEnd() + "`n" + $entry) -Encoding UTF8
        Write-Host "[FlareSolverr-OpenClaw] TOOLS.md updated." -ForegroundColor Green
    } else {
        Write-Host "[FlareSolverr-OpenClaw] FlareSolverr entry already exists in TOOLS.md." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start FlareSolverr:" -ForegroundColor White
Write-Host "  cd $InstallDir" -ForegroundColor Gray
Write-Host "  .\start.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Or run directly: flaresolverr.exe (if in PATH)" -ForegroundColor Gray
Write-Host ""
Write-Host "Config file: $ConfigFile" -ForegroundColor White
