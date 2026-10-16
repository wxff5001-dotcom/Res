<# Restore the pinned Windows tools after git lfs pull. Requires PowerShell 5+. #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$treeRoot = Split-Path $PSScriptRoot -Parent
$archiveRoot = Join-Path $treeRoot 'toolchain'
$manifest = Get-Content (Join-Path $archiveRoot 'manifest.json') -Raw | ConvertFrom-Json

# Verify every archive before extracting any tools. LFS pointer files fail here
# with an actionable message, rather than an opaque unzip error.
foreach ($component in $manifest) {
    $archive = Join-Path $archiveRoot $component.archive
    if (-not (Test-Path -LiteralPath $archive)) {
        throw "Missing $archive. Run git lfs pull first."
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $component.sha256) {
        throw "Checksum mismatch: $archive. Run git lfs pull and retry."
    }
}
foreach ($component in $manifest) {
    Write-Host "Restoring $($component.destination)"
    # CIPD marks installed files read-only; clear that flag for repeat restores.
    $destination = Join-Path $treeRoot $component.destination
    if (Test-Path -LiteralPath $destination) {
        Get-ChildItem -LiteralPath $destination -Recurse -File -Force |
            ForEach-Object { $_.IsReadOnly = $false }
    }
    & tar.exe -xf (Join-Path $archiveRoot $component.archive) -C $treeRoot
    if ($LASTEXITCODE -ne 0) { throw "Extraction failed: $($component.archive)" }
}
Write-Host 'Toolchain restored. Use a fresh out directory when changing versions.'
