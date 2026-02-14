$godotPath = "$PSScriptRoot\external\Godot_v4.4.1-stable_win64.exe"
$scenePath = "scenes/test/screenshot.tscn"

if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found at $godotPath"
    exit 1
}

Write-Host "Running Screenshot Automation..."
& $godotPath --path $PSScriptRoot $scenePath

Write-Host "Screenshot should be in docs/screenshots/"
