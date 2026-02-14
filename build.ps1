# Build script for It Gets Deeper
$BuildDir = "build"
$GodotExe = "external\Godot_v4.4.1-stable_win64.exe"

Write-Host "Starting Build Process..." -ForegroundColor Cyan

# Ensure build directory exists
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}
else {
    Write-Host "Cleaning build directory..."
    Remove-Item -Path "$BuildDir\*" -Recurse -Force | Out-Null
}

# Run Godot Export
Write-Host "Exporting Windows Desktop..." -ForegroundColor Green
& $GodotExe --headless --export-release "Windows Desktop" "$BuildDir/ItGetsDeeper.exe"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful! Output in $BuildDir/" -ForegroundColor Green
    
    # Check for Steam files
    if (Test-Path "$BuildDir/steam_api64.dll") {
        Write-Host "Warning: steam_api64.dll found in build folder. This should have been excluded." -ForegroundColor Yellow
    }
    else {
        Write-Host "Verified: No Steam dependencies found." -ForegroundColor Gray
    }
}
else {
    Write-Host "Build Failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
