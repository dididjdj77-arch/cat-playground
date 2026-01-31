# scripts/check-append-only.ps1
$ErrorActionPreference = "Stop"

# base branch name in GitHub Actions PR context
$baseBranchName = if ($env:GITHUB_BASE_REF) { $env:GITHUB_BASE_REF } else { "main" }
$baseRef = "origin/$baseBranchName"

function Get-DecisionIds([string]$text) {
  $ids = New-Object System.Collections.Generic.List[int]
  $regex = [regex]'(?m)^\s*##\s+D-(\d{3})\b'
  foreach ($m in $regex.Matches($text)) {
    $ids.Add([int]$m.Groups[1].Value)
  }
  return $ids
}

# Load base DECISIONS.md from base ref
$baseText = (git show "$baseRef`:docs/DECISIONS.md") 2>$null
if (-not $baseText) {
  throw "Failed to load docs/DECISIONS.md from $baseRef. Ensure base ref is fetched."
}

$headText = Get-Content "docs/DECISIONS.md" -Raw

$baseIds = Get-DecisionIds $baseText
$headIds = Get-DecisionIds $headText

# 1) No duplicate IDs in head
$headUnique = $headIds | Sort-Object | Get-Unique
if ($headUnique.Count -ne $headIds.Count) {
  throw "DECISIONS violation: duplicate D-### ids detected in docs/DECISIONS.md"
}

# 2) No deletions: all base IDs must still exist
$missing = @()
foreach ($id in ($baseIds | Sort-Object -Unique)) {
  if (-not ($headIds -contains $id)) { $missing += $id }
}
if ($missing.Count -gt 0) {
  throw "DECISIONS violation: removed D-### entries detected: $($missing -join ', ')"
}

# 3) No number reuse: any new IDs must be greater than max base ID
$maxBase = ($baseIds | Measure-Object -Maximum).Maximum
$newIds = @()
foreach ($id in ($headIds | Sort-Object -Unique)) {
  if (-not ($baseIds -contains $id)) { $newIds += $id }
}
$badNew = $newIds | Where-Object { $_ -le $maxBase }
if ($badNew.Count -gt 0) {
  throw "DECISIONS violation: new D-### ids must be > D-$("{0:D3}" -f $maxBase). Bad: $($badNew -join ', ')"
}

Write-Host "DECISIONS guard OK: edits allowed, deletions forbidden, id reuse forbidden."
