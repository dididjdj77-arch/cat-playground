param(
  [string[]]$Files = @("docs/DECISIONS.md","docs/OPEN.md","docs/TODO.md")
)

$ErrorActionPreference = "Stop"

function Get-Headings([string]$file) {
  $key = if ($file -like "*DECISIONS*") { "D" } elseif ($file -like "*OPEN*") { "O" } else { "T" }
  $content = Get-Content $file
  # 헤딩 라인만 추출 (번호+제목)
  return $content | Where-Object { $_ -match "^\s*##\s+$key-\d+\b" }
}

# 기본: git diff가 있는 경우에만 검사
$diff = git diff --name-only
$targets = $Files | Where-Object { $diff -contains $_ }

if ($targets.Count -eq 0) {
  Write-Host "No target docs changed. OK."
  exit 0
}

foreach ($f in $targets) {
  # 변경 전/후 헤딩 목록 비교
  $before = git show "HEAD:$f" 2>$null
  if (-not $before) { continue } # 새 파일이면 패스
  $tmp = New-TemporaryFile
  Set-Content -Encoding UTF8 $tmp $before

  $hBefore = Get-Content $tmp | Where-Object { $_ -match "^\s*##\s+[DOT]-\d+\b" }
  $hAfter  = Get-Content $f   | Where-Object { $_ -match "^\s*##\s+[DOT]-\d+\b" }

  # prefix 강제 (파일별 키 정확성까지는 다음 단계에서 강화 가능)
  $setBefore = [System.Collections.Generic.HashSet[string]]::new()
  foreach ($h in $hBefore) { $null = $setBefore.Add($h.Trim()) }

  $setAfter = [System.Collections.Generic.HashSet[string]]::new()
  foreach ($h in $hAfter) { $null = $setAfter.Add($h.Trim()) }

  # 삭제/변경 감지: before에 있었는데 after에 없으면 실패
  $missing = @()
  foreach ($h in $setBefore) {
    if (-not $setAfter.Contains($h)) { $missing += $h }
  }

  if ($missing.Count -gt 0) {
    Write-Error "Append-only violation in $f. Missing headings:`n - $($missing -join "`n - ")"
  } else {
    Write-Host "OK: $f (append-only headings preserved)"
  }
}

Write-Host "Append-only check passed."
