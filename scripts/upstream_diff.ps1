<#
.SYNOPSIS
    Lists this tree's drift from a Chromium checkout.

.DESCRIPTION
    Compares every file this tree has against the same path upstream and reports
    the ones that differ. Use it when rolling to a new Chromium version: the
    "MODIFIED" list records the inherited port changes and any later drift.

    Only files present in both trees are compared. Files this tree does not have
    are not reported -- the point is to audit local edits, not to re-derive the
    dependency closure.

.PARAMETER ChromiumSrc
    Root of the Chromium checkout to compare against.

.PARAMETER Filter
    Which files to compare. Defaults to build files AND sources, because
    limiting it to build files once hid a real source edit
    (rlz/lib/machine_id.cc). Narrow it deliberately if a run is too slow.

.EXAMPLE
    .\scripts\upstream_diff.ps1
    .\scripts\upstream_diff.ps1 -ChromiumSrc D:\chromium\src -Filter *.gn,*.gni,*.py
#>
[CmdletBinding()]
param(
    [string]$ChromiumSrc = "E:\work\chromium\src",
    [string[]]$Filter = @("BUILD.gn", "*.gni", ".gn", "*.cc", "*.h", "*.mojom")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent

if (-not (Test-Path $ChromiumSrc)) {
    throw "Chromium checkout not found: $ChromiumSrc  (pass -ChromiumSrc <path>)"
}

# Directories that are ours, not upstream's, or that are not tracked at all.
$skip = @("\out\", "\.git\", "\depot_tools\", "\scripts\")

$modified = [System.Collections.Generic.List[string]]::new()
$localOnly = [System.Collections.Generic.List[string]]::new()
$compared = 0

Get-ChildItem $Root -Recurse -File -Include $Filter -ErrorAction SilentlyContinue |
    ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length)
        foreach ($s in $skip) { if ($rel -like "*$s*") { return } }

        $up = Join-Path $ChromiumSrc $rel.TrimStart('\')
        if (-not (Test-Path $up)) {
            $localOnly.Add($rel)
            return
        }
        $compared++
        $a = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        $b = (Get-FileHash $up -Algorithm SHA256).Hash
        if ($a -ne $b) { $modified.Add($rel) }
    }

Write-Host ""
Write-Host ("Compared {0} files against {1}" -f $compared, $ChromiumSrc)
Write-Host ""

Write-Host ("MODIFIED ({0}) -- review when updating the snapshot" -f $modified.Count) -ForegroundColor Yellow
$modified | Sort-Object | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host ("LOCAL ONLY ({0}) -- files this tree adds" -f $localOnly.Count) -ForegroundColor Cyan
$localOnly | Sort-Object | ForEach-Object { Write-Host "  $_" }
