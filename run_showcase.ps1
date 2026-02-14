$godotPath = "$PSScriptRoot\external\Godot_v4.4.1-stable_win64.exe" 
if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found at $godotPath"
    exit 1
}
& $godotPath --path $PSScriptRoot "res://scenes/showcase.tscn"
