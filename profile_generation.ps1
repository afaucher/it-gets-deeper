# Profiling script for Tunnel Generation
$GodotExe = "external\Godot_v4.4.1-stable_win64.exe"

Write-Host "Starting Headless Profiling Session..." -ForegroundColor Cyan

# We run with --headless and -v to ensure we see the output.
# We'll use a timeout or just wait for the specific completion string.
$process = Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--verbose" -PassThru -NoNewWindow -RedirectStandardOutput "profile_output.log" -RedirectStandardError "profile_error.log"

Write-Host "Waiting for generation to complete (this may take a minute)..."

$completed = $false
$startTime = Get-Date

while (-not $process.HasExited) {
    if (Test-Path "profile_output.log") {
        $content = Get-Content "profile_output.log" -Tail 5
        if ($content -match "Initial chunks complete.") {
            $completed = $true
            Write-Host "Generation Finished!" -ForegroundColor Green
            break
        }
    }
    
    # Timeout after 2 minutes
    if (((Get-Date) - $startTime).TotalSeconds -gt 300) {
        Write-Host "Profiling timed out!" -ForegroundColor Red
        break
    }
    
    Start-Sleep -Seconds 2
}

if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
}

if ($completed) {
    Write-Host "`n--- PROFILING RESULTS ---" -ForegroundColor Yellow
    Get-Content "profile_output.log" | Where-Object { $_ -match "TUNNEL GENERATOR PROFILING REPORT|Total Loading Time|Time in Density|Time in Marching Cubes|Time in Interpolation|Time in Mesh Finalization|Time in Collision Generation|---" }
}
else {
    Write-Host "Failed to capture profiling report. Check profile_error.log" -ForegroundColor Red
    if (Test-Path "profile_error.log") {
        Get-Content "profile_error.log" -Tail 20
    }
}
