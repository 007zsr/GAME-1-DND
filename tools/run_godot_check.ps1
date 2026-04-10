param(
    [string]$Godot = "D:\Godot\Godot_v4.2.2-stable_win64.exe~1\Godot_v4.2.2-stable_win64_console.exe",
    [string]$Project = "E:\working_VSCODE\2026_4_8_game",
    [string]$Script = "res://tools/check_gameplay_regressions.gd",
    [int]$TimeoutSec = 90
)

$logSuffix = "{0}_{1}" -f [System.IO.Path]::GetFileNameWithoutExtension($Script), ([guid]::NewGuid().ToString("N"))
$stdout = Join-Path $env:TEMP ("godot_headless_stdout_{0}.log" -f $logSuffix)
$stderr = Join-Path $env:TEMP ("godot_headless_stderr_{0}.log" -f $logSuffix)
$exitCode = 1

Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

$p = Start-Process `
    -FilePath $Godot `
    -ArgumentList @("--path", $Project, "--headless", "--script", $Script) `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -WindowStyle Hidden

$finished = $p.WaitForExit($TimeoutSec * 1000)

if (-not $finished) {
    Write-Host "HEADLESS_TIMEOUT after $TimeoutSec sec"
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue

    if (Test-Path $stdout) {
        Write-Host "==== STDOUT ===="
        Get-Content $stdout
    }

    if (Test-Path $stderr) {
        Write-Host "==== STDERR ===="
        Get-Content $stderr
    }

    $exitCode = 124
}
else {
    if (Test-Path $stdout) {
        Write-Host "==== STDOUT ===="
        Get-Content $stdout
    }

    if (Test-Path $stderr) {
        Write-Host "==== STDERR ===="
        Get-Content $stderr
    }

    $exitCode = $p.ExitCode
}

Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

exit $exitCode
