param(
  [string[]]$Files = @("docs/DECISIONS.md","docs/OPEN.md","docs/TODO.md"),
  [string]$BaseRef = ""   # 비우면: CI에서는 GITHUB_BASE_REF 사용, 로컬은 origin/main
)

$ErrorActionPreference = "Stop"

function Resolve-BaseRef([string]$BaseRef) {
  if ($BaseRef) { return $BaseRef }
  if ($env:GITHUB_BASE_REF) { return "origin/$($env:GITHUB_BASE_REF)" }
  return "origin/main"
}

function Get-LineCount([string]$text) {
  if ($null -eq $text) { return 0 }
  $arr = [regex]::Split($text, "\r?\n")
  $count = $arr.Count
  # trailing newline로 split된 마지막 빈 라인 보정
  if ($text -match "\r?\n$") { $count -= 1 }
  return $count
}

$baseRefResolved = Resolve-BaseRef $BaseRef

# base ref 존재 확인 (없으면 fetch 필요)
git rev-parse --verify $baseRefResolved *> $null
if ($LASTEXITCODE -ne 0) {
  throw "Base ref '$baseRefResolved' not found. Run: git fetch origin $($baseRefResolved -replace '^origin/','')"
}

$baseCommit = (git merge-base HEAD $baseRefResolved).Trim()
if (-not $baseCommit) { throw "Failed to resolve merge-base for HEAD and $baseRefResolved" }

$changed = (git diff --name-only "$baseCommit..HEAD") | Where-Object { $_ }
$targets = $Files | Where-Object { $changed -contains $_ }

if ($targets.Count -eq 0) {
  Write-Host "No target docs changed vs $baseRefResolved. OK."
  exit 0
}

foreach ($f in $targets) {
  $baseText = git show "$($baseCommit):$f" 2>$null
  if (-not $baseText) {
    Write-Host "Skip (new file): $f"
    continue
  }

  $baseLines = Get-LineCount $baseText
  $patch = git diff --unified=0 "$baseCommit..HEAD" -- $f

  # 1) 삭제/수정 금지: diff에서 '-' 라인이 있으면 실패 (헤더 '---'는 제외)
  $removed = ($patch -split "\r?\n") | Where-Object { $_.StartsWith("-") -and -not $_.StartsWith("---") }
  if ($removed.Count -gt 0) {
    throw "Append-only violation in ${f}: removals/modifications detected. (Use supersede: add new entry at end.)"
  }

  # 2) 중간 삽입 금지: 모든 추가는 EOF(기존 라인수 이후)에서만 허용
  $hunks = [regex]::Matches($patch, '^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@', 'Multiline')
  foreach ($h in $hunks) {
    $plusStart = [int]$h.Groups[3].Value
    if ($plusStart -le $baseLines) {
      throw "Append-only violation in ${f}: insertion is not at EOF (baseLines=$baseLines, plusStart=$plusStart). Add only at the end."
    }
  }

  Write-Host "OK: $f (append-only vs $baseRefResolved)"
}

Write-Host "Append-only check passed."
