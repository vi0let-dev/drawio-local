#Requires -Version 5.1
<#
.SYNOPSIS
    Export draw.io / Mermaid / CSV / VSDX sources to one or more formats
    (PNG, SVG, PDF, JPG, XML, HTML) with the locally installed draw.io Desktop CLI.
    Fully offline: no MCP server, no mcp.draw.io, no cloud rasterizer.

.DESCRIPTION
    Thin, dependency-free wrapper around:
        draw.io.exe --export --format <fmt> [--embed-diagram] [--transparent]
                    [--border N] [--quality N] [--scale N] [--recursive]
                    --output <path> <input>

    The wrapper exists because draw.io.exe is a GUI-subsystem binary: PowerShell's
    call operator (&) does not wait for it, so a naive call returns before the
    export finishes. This script waits, enforces a timeout, supports several
    output formats in one invocation, and fails loudly when an output file is
    missing or empty.

.PARAMETER Format
    One or more of png, svg, pdf, jpg, xml, html. With several values the source
    is exported once per format (e.g. -Format png,svg writes diagram.png and
    diagram.svg). Default: inferred from -OutputPath, else pdf.

.PARAMETER Scale
    Multiplies the rendered size (draw.io -s). For paper figures a 2x/3x PNG is
    usually what reaches ~300 dpi at single-column width.

.EXAMPLE
    powershell -NoProfile -File scripts\Export-Drawio.ps1 -Check

.EXAMPLE
    powershell -NoProfile -File scripts\Export-Drawio.ps1 -InputPath .\diagram.mmd -OutputPath .\diagram.png -Format png,svg -Embed -Border 10 -Scale 2

.EXAMPLE
    powershell -NoProfile -File scripts\Export-Drawio.ps1 -InputPath .\diagrams -OutputPath .\out -Format svg,png -Recursive

.NOTES
    Exit codes: 0 success, 1 usage/resolution error, 2 draw.io failed,
                3 output missing, 4 timeout.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$InputPath,

    [string]$OutputPath,

    # Accepts "png", "png,svg", or a PowerShell array. Validated below so that
    # `powershell -File ... -Format png,svg` (a single string) keeps working.
    [string[]]$Format,

    [switch]$Embed,

    [switch]$Transparent,

    [int]$Border = -1,

    [int]$Quality = -1,

    [int]$Scale = -1,

    [switch]$Recursive,

    [string]$DrawioExe,

    [int]$TimeoutSeconds = 180,

    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$KnownFormats = @('png', 'svg', 'pdf', 'jpg', 'xml', 'html')
$SupportedInputExtensions = @('.drawio', '.xml', '.vsdx', '.csv', '.mmd', '.mermaid')

function Write-Info([string]$Message) { Write-Host "[drawio-local] $Message" }
function Write-Fail([string]$Message) { Write-Host "[drawio-local] ERROR: $Message" -ForegroundColor Red }

function Get-VersionOf([string]$Path) {
    try {
        $item = Get-Item -LiteralPath $Path
        if ($item.VersionInfo -and $item.VersionInfo.FileVersion) { return $item.VersionInfo.FileVersion }
    }
    catch { }
    return $null
}

function Find-DrawioExe {
    param([string]$Explicit)

    $tried = New-Object System.Collections.Generic.List[string]
    $add = {
        param($p)
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        $p = [Environment]::ExpandEnvironmentVariables($p)
        if ($tried -contains $p) { return }
        $tried.Add($p)
    }

    # 1. Explicit parameter, then environment variable, then PATH.
    if ($Explicit) { & $add $Explicit; if (Test-Path -LiteralPath $Explicit) { return @{ Path = (Resolve-Path -LiteralPath $Explicit).Path; Tried = $tried } } }
    if ($env:DRAWIO_EXE) { & $add $env:DRAWIO_EXE; if (Test-Path -LiteralPath $env:DRAWIO_EXE) { return @{ Path = (Resolve-Path -LiteralPath $env:DRAWIO_EXE).Path; Tried = $tried } } }

    foreach ($name in @('drawio', 'draw.io', 'drawio.exe', 'draw.io.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) {
            & $add $cmd.Source
            if (Test-Path -LiteralPath $cmd.Source) { return @{ Path = $cmd.Source; Tried = $tried } }
        }
    }

    # 2. Common install roots; a portable unzip keeps the exe one level down.
    #    Any drive root that contains a "draw.io" folder is also checked, so a
    #    portable unzip on a secondary drive is found without hard-coded paths.
    $roots = New-Object System.Collections.Generic.List[string]
    if ($env:ProgramFiles) { $roots.Add((Join-Path $env:ProgramFiles 'draw.io')) }
    if (${env:ProgramFiles(x86)}) { $roots.Add((Join-Path ${env:ProgramFiles(x86)} 'draw.io')) }
    if ($env:LOCALAPPDATA) { $roots.Add((Join-Path $env:LOCALAPPDATA 'Programs\draw.io')) }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        if ($drive.Root) { $roots.Add((Join-Path $drive.Root 'draw.io')) }
    }

    foreach ($root in $roots) {
        & $add $root
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $direct = Join-Path $root 'draw.io.exe'
        if (Test-Path -LiteralPath $direct) { return @{ Path = $direct; Tried = $tried } }
        $hit = Get-ChildItem -LiteralPath $root -Filter 'draw.io.exe' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($hit) { return @{ Path = $hit.FullName; Tried = $tried } }
    }

    # 3. Uninstall registry entries (per-user and machine-wide).
    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($key in $uninstallRoots) {
        if (-not (Test-Path $key)) { continue }
        foreach ($sub in Get-ChildItem $key -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $sub.PSPath -ErrorAction SilentlyContinue
            if (-not $props -or -not $props.DisplayName) { continue }
            if ($props.DisplayName -notmatch 'draw\.io') { continue }
            if (-not $props.InstallLocation) { continue }
            $candidate = Join-Path $props.InstallLocation 'draw.io.exe'
            & $add $candidate
            if (Test-Path -LiteralPath $candidate) { return @{ Path = $candidate; Tried = $tried } }
        }
    }

    return @{ Path = $null; Tried = $tried }
}

function Quote-Arg([string]$Value) {
    # draw.io's own argument parser follows the usual Windows quoting rules.
    # A trailing backslash would escape the closing quote, so double it.
    $v = $Value
    if ($v.EndsWith('\')) { $v = $v + '\' }
    return '"' + $v.Replace('"', '\"') + '"'
}

function Invoke-DrawioCli {
    param(
        [string]$Exe,
        [string]$Arguments,
        [int]$Timeout
    )

    # Start-Process with -RedirectStandardOutput does not reliably populate
    # ExitCode, so drive the process through System.Diagnostics.Process.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = 'Hidden'
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        [void]$proc.Start()
    }
    catch {
        return @{ Started = $false; Error = $_.Exception.Message; ExitCode = $null; StdErr = ''; StdOut = ''; Seconds = 0 }
    }

    $errTask = $proc.StandardError.ReadToEndAsync()
    $outTask = $proc.StandardOutput.ReadToEndAsync()

    $completed = $proc.WaitForExit($Timeout * 1000)
    if (-not $completed) {
        try { $proc.Kill(); [void]$proc.WaitForExit(5000) } catch { }
        $sw.Stop()
        return @{ Started = $true; TimedOut = $true; ExitCode = $null; StdErr = ''; StdOut = ''; Seconds = $sw.Elapsed.TotalSeconds }
    }

    [void]$proc.WaitForExit()
    $sw.Stop()

    $stderr = ''
    if ($errTask) { try { $stderr = $errTask.Result } catch { } }
    $stdout = ''
    if ($outTask) { try { $stdout = $outTask.Result } catch { } }

    return @{ Started = $true; TimedOut = $false; ExitCode = $proc.ExitCode; StdErr = $stderr; StdOut = $stdout; Seconds = $sw.Elapsed.TotalSeconds }
}

# ---------------------------------------------------------------- resolve exe
$found = Find-DrawioExe -Explicit $DrawioExe
if (-not $found.Path) {
    Write-Fail 'draw.io Desktop executable not found.'
    Write-Host 'Searched:'
    foreach ($t in $found.Tried) { Write-Host "  - $t" }
    Write-Host ''
    Write-Host 'Install draw.io Desktop (https://www.drawio.com/) or pass -DrawioExe "<path to draw.io.exe>",'
    Write-Host 'or set the DRAWIO_EXE environment variable.'
    exit 1
}

$exePath = $found.Path
$version = Get-VersionOf $exePath
Write-Info ("draw.io Desktop: {0}" -f $exePath)
if ($version) { Write-Info ("version: {0}" -f $version) }

if ($Check) {
    Write-Info 'check passed (no export performed)'
    exit 0
}

# ------------------------------------------------------------------ validate
if ([string]::IsNullOrWhiteSpace($InputPath)) {
    Write-Fail '-InputPath is required (or use -Check).'
    exit 1
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    Write-Fail ("input not found: {0}" -f $InputPath)
    exit 1
}
$inputFull = (Resolve-Path -LiteralPath $InputPath).Path
$inputIsDir = Test-Path -LiteralPath $inputFull -PathType Container

if (-not $inputIsDir) {
    $ext = [System.IO.Path]::GetExtension($inputFull).ToLowerInvariant()
    if ($SupportedInputExtensions -notcontains $ext) {
        Write-Fail ("unsupported input type '{0}'. Supported: {1}" -f $ext, ($SupportedInputExtensions -join ', '))
        exit 1
    }
}
elseif (-not $Recursive) {
    Write-Info 'input is a directory; converting the files directly inside it (use -Recursive for sub-folders)'
}

# Which formats to produce? Accept comma-separated values from -File callers.
$formatsToRun = @()
if ($Format -and $Format.Count -gt 0) {
    foreach ($entry in $Format) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        foreach ($part in ($entry -split ',')) {
            $p = $part.Trim().ToLowerInvariant()
            if ($p) { $formatsToRun += $p }
        }
    }
}
elseif ($OutputPath) {
    $probeExt = [System.IO.Path]::GetExtension($OutputPath).TrimStart('.').ToLowerInvariant()
    if ($KnownFormats -contains $probeExt) { $formatsToRun = @($probeExt) }
}
if ($formatsToRun.Count -eq 0) { $formatsToRun = @('pdf') }

foreach ($f in $formatsToRun) {
    if ($KnownFormats -notcontains $f) { Write-Fail ("unsupported format '{0}'" -f $f); exit 1 }
}

# Resolve the output base (no extension) or directory mode.
$outputDirMode = $false
$outputBase = $null

if ($OutputPath) {
    $outRaw = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $looksLikeDir = ($OutputPath.EndsWith('\') -or $OutputPath.EndsWith('/') -or (Test-Path -LiteralPath $outRaw -PathType Container))
    if ($inputIsDir -or $looksLikeDir) {
        $outputDirMode = $true
        $outputBase = $outRaw
    }
    else {
        $outExt = [System.IO.Path]::GetExtension($outRaw).TrimStart('.').ToLowerInvariant()
        if ($KnownFormats -contains $outExt) {
            $outputBase = $outRaw.Substring(0, $outRaw.Length - $outExt.Length - 1)
        }
        else {
            $outputBase = $outRaw
        }
    }
}
elseif (-not $inputIsDir) {
    $inputDir = Split-Path -Path $inputFull -Parent
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($inputFull)
    $outputBase = Join-Path $inputDir $inputBase
}

if ($outputDirMode) {
    if (-not (Test-Path -LiteralPath $outputBase)) {
        if ($WhatIfPreference) { Write-Info ("would create output directory: {0}" -f $outputBase) }
        else { New-Item -ItemType Directory -Path $outputBase -Force | Out-Null; Write-Info ("created output directory: {0}" -f $outputBase) }
    }
}
elseif ($outputBase) {
    $outParent = Split-Path -Path $outputBase -Parent
    if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
        if ($WhatIfPreference) { Write-Info ("would create output directory: {0}" -f $outParent) }
        else { New-Item -ItemType Directory -Path $outParent -Force | Out-Null; Write-Info ("created output directory: {0}" -f $outParent) }
    }
}

# Per-format output path (null means "let draw.io derive it next to the input").
function Get-OutputForFormat {
    param([string]$Fmt)
    if ($outputDirMode) { return $null }
    if (-not $outputBase) { return $null }
    return ($outputBase + '.' + $Fmt)
}

$runs = @()
foreach ($fmt in $formatsToRun) {
    $target = Get-OutputForFormat -Fmt $fmt

    $argParts = @('-x', '-f', $fmt)

    if ($Embed) {
        if (@('png', 'svg', 'pdf') -contains $fmt) { $argParts += '-e' }
        else { Write-Info ("-Embed skipped for '{0}' (only png/svg/pdf keep an editable copy)" -f $fmt) }
    }
    if ($Transparent) { $argParts += '-t' }
    if ($Border -ge 0) { $argParts += @('-b', [string]$Border) }
    if ($Quality -ge 0) { $argParts += @('-q', [string]$Quality) }
    if ($Scale -ge 1) { $argParts += @('-s', [string]$Scale) }
    if ($Recursive) { $argParts += '-r' }
    if ($outputDirMode) { $argParts += @('-o', (Quote-Arg $outputBase)) }
    elseif ($target) { $argParts += @('-o', (Quote-Arg $target)) }
    $argParts += (Quote-Arg $inputFull)

    $runs += @{
        Format  = $fmt
        Target  = $target
        Arguments = ($argParts -join ' ')
    }
}

Write-Info ("formats: {0}" -f ($formatsToRun -join ', '))
if ($formatsToRun.Count -gt 1) { Write-Info ('one export per format will run') }

$written = @()
$failed = @()

foreach ($run in $runs) {
    Write-Info ("command: `"{0}`" {1}" -f $exePath, $run.Arguments)

    if (-not $PSCmdlet.ShouldProcess($inputFull, ("export to {0}" -f $run.Format))) {
        continue
    }

    $result = Invoke-DrawioCli -Exe $exePath -Arguments $run.Arguments -Timeout $TimeoutSeconds

    if (-not $result.Started) {
        Write-Fail ("could not start draw.io.exe: {0}" -f $result.Error)
        Write-Host '  If this is "Access is denied", the shell is sandboxed; run the command from the user''s own terminal.'
        exit 2
    }

    if ($result.TimedOut) {
        Write-Fail ("timed out after {0}s" -f $TimeoutSeconds)
        exit 4
    }

    Write-Info ("[{0}] exit code {1} after {2:n1}s" -f $run.Format, $result.ExitCode, $result.Seconds)

    if ($result.ExitCode -ne 0) {
        if ($result.ExitCode -eq -2147483645) {
            Write-Fail 'draw.io exited with STATUS_BREAKPOINT (0x80000003) during startup - it never reached the exporter.'
            Write-Host '  Known cause: running inside a sandboxed shell. Chromium needs to create named pipes'
            Write-Host '  (mojo IPC) and the sandbox blocks that, e.g.:'
            Write-Host '    FATAL:mojo/public/cpp/platform/platform_channel.cc:108] Check failed: . : Access is denied. (0x5)'
            Write-Host '  Fix: run this command from the user''s own terminal, or allow this process to run unsandboxed.'
            Write-Host '  Retrying the same command inside the sandbox will keep failing.'
        }
        else {
            Write-Fail ("draw.io failed with exit code {0} for format {1}" -f $result.ExitCode, $run.Format)
        }
        if ($result.StdErr) { Write-Host '--- stderr ---'; Write-Host $result.StdErr.Trim() }
        if ($result.StdOut) { Write-Host '--- stdout ---'; Write-Host $result.StdOut.Trim() }
        $failed += $run.Format
        break
    }

    if ($run.Target) {
        if (-not (Test-Path -LiteralPath $run.Target)) {
            Write-Fail ("draw.io reported success but no output file was written: {0}" -f $run.Target)
            $failed += $run.Format
            break
        }
        $item = Get-Item -LiteralPath $run.Target
        if ($item.Length -le 0) {
            Write-Fail ("output file is empty: {0}" -f $run.Target)
            $failed += $run.Format
            break
        }
        Write-Info ("wrote {0} ({1:n0} bytes)" -f $run.Target, $item.Length)
        $written += $run.Target
    }
}

if ($WhatIfPreference) {
    Write-Info 'what-if only; no export performed'
    exit 0
}

if ($failed.Count -gt 0) {
    if ($written.Count -gt 0) { Write-Host ('  produced before the failure: ' + ($written -join ', ')) }
    exit 2
}

if ($outputDirMode) {
    $produced = @()
    foreach ($fmt in $formatsToRun) {
        $produced += Get-ChildItem -LiteralPath $outputBase -Filter ('*.' + $fmt) -File -Recurse:$Recursive -ErrorAction SilentlyContinue
    }
    if (-not $produced) {
        Write-Fail ("no output files found in {0}" -f $outputBase)
        exit 3
    }
    foreach ($p in $produced) { Write-Info ("wrote {0} ({1:n0} bytes)" -f $p.FullName, $p.Length); Write-Output $p.FullName }
    exit 0
}

if ($written.Count -eq 0) {
    Write-Fail 'no output file was produced'
    exit 3
}

foreach ($w in $written) { Write-Output $w }
exit 0
