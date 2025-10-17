# enviroInstaller.ps1
# Searches child folders for environment / requirements yaml files
# Uses conda to install these environments
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Error "conda not found in PATH. Run this in a shell where conda is available (Anaconda/Miniconda prompt) or add conda to PATH."
    exit 1
}

Write-Host "Searching for environment.y(a)ml / requirements.y(a)ml under: $scriptRoot"

$files = Get-ChildItem -Path $scriptRoot -Recurse -File -Include 'environment.yml','environment.yaml', 'requirements.yml', 'requirements.yaml' -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Host "No environment.yml/yaml files found."
    exit 0
}

# try to get existing env names via JSON output, fallback to plain text parsing
$existingNames = @()
try {
    $jsonOut = & conda env list --json 2>$null
    if ($LASTEXITCODE -eq 0 -and $jsonOut) {
        $obj = $jsonOut | ConvertFrom-Json
        $existingNames = $obj.envs | ForEach-Object { Split-Path -Leaf $_ }
    }
} catch {
    # ignore
}
if (-not $existingNames) {
    $plain = & conda env list 2>$null
    if ($plain) {
        # split on any newline, take first token, trim CR/WS
        $existingNames = ($plain -split "\r?\n") |
            ForEach-Object {
                ($_ -replace '\s+conda.*$','') -split '\s+' | Select-Object -First 1
            } | Where-Object { $_ }
    }
}

# normalize names (trim whitespace/CR and dedupe, case-insensitive comparison later)
$existingNames = $existingNames | ForEach-Object { ($_ -as [string]).Trim() } | Where-Object { $_ } | Select-Object -Unique

foreach ($file in $files) {
    Write-Host "Found: $($file.FullName)"
    $dir = $file.DirectoryName

    $content = Get-Content -Raw -Path $file.FullName -ErrorAction SilentlyContinue
    $envName = $null
    if ($content) {
        $m = [regex]::Match($content, '^\s*name\s*:\s*(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($m.Success) { $envName = $m.Groups[1].Value.Trim(" `"'") }
    }

    if ($envName) {
        # normalize envName for reliable comparison
        $envName = ($envName -as [string]).Trim()
        Write-Host "Looking for '$envName' in $($existingNames -join ', ')"
        if ($existingNames -contains $envName) {
            Write-Host "Conda environment '$envName' already exists — skipping."
            continue
        } else {
            Write-Host "Conda environment '$envName' does not exist."
        }
    }

    Write-Host "Creating environment from $($file.Name) (cwd: $dir)"
    Push-Location $dir
    try {
        & conda env create -f $file.Name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Created environment from $($file.Name)"
        } else {
            Write-Error "Failed to create environment from $($file.Name)"
        }
    } catch {
        Write-Error "Exception while creating environment from $($file.Name): $_"
    } finally {
        Pop-Location
    }
}
