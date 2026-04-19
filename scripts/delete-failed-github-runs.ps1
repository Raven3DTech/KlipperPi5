#Requires -Version 5.1
<#
.SYNOPSIS
  Delete failed GitHub Actions workflow runs (keeps successful / green runs).

.DESCRIPTION
  Uses GitHub CLI. Run once: gh auth login
  Default repo: Raven3DTech/R3DTOS-PI5
  Deletes runs with status filter: failure, startup_failure, timed_out
#>
param(
  [string]$Repo = "Raven3DTech/R3DTOS-PI5",
  [int]$Limit = 500,
  [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$GH = Join-Path ${env:ProgramFiles} "GitHub CLI\gh.exe"
if (-not (Test-Path $GH)) {
  $GH = "gh"
}

$env:GH_PROMPT_DISABLED = "1"

& $GH auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Error "Not logged in. Run: & '$GH' auth login"
  exit 1
}

$bad = @("failure", "startup_failure", "timed_out")
$idSet = [System.Collections.Generic.HashSet[string]]::new()

foreach ($s in $bad) {
  $lines = & $GH run list -R $Repo -L $Limit -s $s --json databaseId --jq '.[].databaseId'
  if ($LASTEXITCODE -ne 0) { continue }
  foreach ($line in $lines) {
    $t = $line.Trim()
    if ($t) { [void]$idSet.Add($t) }
  }
}

if ($idSet.Count -eq 0) {
  Write-Host "No failed runs found (failure / startup_failure / timed_out) in last $Limit per status."
  exit 0
}

Write-Host "Found $($idSet.Count) failed run(s) to remove."
$blocked = $false
foreach ($id in $idSet) {
  if ($WhatIf) {
    Write-Host "[WhatIf] Would delete run $id"
    continue
  }
  Write-Host "Deleting run $id"
  $out = & $GH run delete $id -R $Repo 2>&1
  if ($out) { Write-Host $out }
  if ($LASTEXITCODE -ne 0 -or "$out" -match '\b403\b') {
    if (-not $blocked) {
      Write-Warning "Delete blocked (HTTP 403 = need **admin** on the repo). Run ``gh auth login`` as the org/repo owner, then re-run this script."
      $blocked = $true
    }
    break
  }
}
if ($blocked) {
  exit 1
}
Write-Host "Done."
