# Run from an elevated PowerShell after preparing the model and CLI bundle.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$pocRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$pocLocal = Join-Path $pocRoot '.local'
$pocExe = Join-Path $pocLocal 'server-build/bundle/bin/jocaagura_ai_server.exe'
$pocModel = Join-Path $pocLocal 'gemma-4-E2B-it.litertlm'
$pocReport = Join-Path $pocLocal 'offline-evidence.json'
$pocExpectedHash = '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c'
$pocPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pocPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from PowerShell as administrator to disable/restore physical network adapters.'
}
if (-not (Test-Path -LiteralPath $pocExe -PathType Leaf)) { throw 'Build the CLI bundle first.' }
if ((Get-FileHash -LiteralPath $pocModel -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pocExpectedHash) {
    throw 'The local model does not match the pinned POC artifact.'
}
$pocPreviousModel = $env:JOCAAGURA_MODEL_PATH
$pocPreviousLibraries = $env:LLAMADART_LITERT_LM_LIB_DIR
$env:JOCAAGURA_MODEL_PATH = $pocModel
$env:LLAMADART_LITERT_LM_LIB_DIR = Join-Path $pocLocal 'server-build/bundle/lib'
$pocAdapters = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
$pocRuns = @()
$pocStarted = [DateTime]::UtcNow.ToString('o')
try {
    foreach ($pocAdapter in $pocAdapters) {
        Disable-NetAdapter -InputObject $pocAdapter -Confirm:$false
    }
    if (@(Get-NetAdapter -Physical | Where-Object Status -eq 'Up').Count -ne 0) {
        throw 'A physical network adapter remains connected; offline proof aborted.'
    }
    for ($pocRun = 1; $pocRun -le 2; $pocRun++) {
        $pocBefore = @(Get-NetAdapter -Physical | Select-Object Name, Status)
        $pocOut = Join-Path $pocLocal "offline-$pocRun.stdout"
        $pocErr = Join-Path $pocLocal "offline-$pocRun.stderr"
        # Own the .NET process directly: Windows PowerShell 5 Start-Process can
        # lose ExitCode after WaitForExit/Refresh on its returned Process object.
        $pocProcess = [Diagnostics.Process]::new()
        $pocProcess.StartInfo.FileName = $pocExe
        $pocProcess.StartInfo.Arguments = 'smoke'
        $pocProcess.StartInfo.UseShellExecute = $false
        $pocProcess.StartInfo.CreateNoWindow = $true
        $pocProcess.StartInfo.RedirectStandardOutput = $true
        $pocProcess.StartInfo.RedirectStandardError = $true
        try {
            [void]$pocProcess.Start()
            $pocProcessId = $pocProcess.Id
            $pocOutputTask = $pocProcess.StandardOutput.ReadToEndAsync()
            $pocErrorTask = $pocProcess.StandardError.ReadToEndAsync()
            if (-not $pocProcess.WaitForExit(120000)) {
                $pocProcess.Kill()
                throw 'POC exceeded two minutes; process stopped and result is a failure, not cancellation support.'
            }
            $pocExitCode = $pocProcess.ExitCode
            $pocOutputTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $pocOut -Encoding utf8
            $pocErrorTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $pocErr -Encoding utf8
        } finally {
            $pocProcess.Dispose()
        }
        $pocResult = Get-Content -Raw -LiteralPath $pocOut | ConvertFrom-Json
        $pocAfter = @(Get-NetAdapter -Physical | Select-Object Name, Status)
        $pocPass = $pocExitCode -eq 0 -and $pocResult.passed -eq $true `
            -and $pocResult.result.text.Trim() -ceq 'OK' `
            -and @($pocAfter | Where-Object Status -eq 'Up').Count -eq 0
        $pocRuns += [pscustomobject]@{
            run = $pocRun; pid = $pocProcessId; exitCode = $pocExitCode; passed = $pocPass
            physicalAdaptersBefore = $pocBefore; physicalAdaptersAfter = $pocAfter
            output = $pocResult
        }
        if (-not $pocPass) { throw "Offline run $pocRun failed; inspect the local logs." }
    }
} finally {
    try {
        foreach ($pocAdapter in $pocAdapters) {
            Enable-NetAdapter -InterfaceDescription $pocAdapter.InterfaceDescription -Confirm:$false
        }
    } finally {
        $env:JOCAAGURA_MODEL_PATH = $pocPreviousModel
        $env:LLAMADART_LITERT_LM_LIB_DIR = $pocPreviousLibraries
        [pscustomobject]@{
            startedUtc = $pocStarted
            finishedUtc = [DateTime]::UtcNow.ToString('o')
            executableSha256 = (Get-FileHash -LiteralPath $pocExe -Algorithm SHA256).Hash.ToLowerInvariant()
            modelSha256 = $pocExpectedHash
            method = 'Physical network adapters disabled; fresh socket-free application process for each run.'
            runs = $pocRuns
            passed = $pocRuns.Count -eq 2 -and @($pocRuns | Where-Object passed -ne $true).Count -eq 0
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $pocReport -Encoding utf8
    }
}
Write-Host "Offline proof passed. Network adapters restored. Evidence: $pocReport"
