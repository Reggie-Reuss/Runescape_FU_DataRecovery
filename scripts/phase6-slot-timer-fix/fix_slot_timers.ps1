# fix_slot_timers.ps1
# Fixes empty slotTimers array in Flipping Utilities JSON data files.
#
# Bug: FU plugin v1.4.1 crashes with IndexOutOfBoundsException when slotTimers
# is an empty array (length 0) instead of containing 8 SlotActivityTimer entries.
# This silently drops ALL real-time GE offer events — no trades are recorded.
#
# Root cause: The recovery/migration process (Phase 5) produced a valid JSON file
# but with "slotTimers": [] instead of the required 8-element array. The plugin
# has no defensive check for undersized slotTimers lists.
#
# Usage: .\fix_slot_timers.ps1 [-Path <json_file>] [-DryRun]
#   -Path    Path to the FU account JSON file (default: all .json in ~/.runelite/flipping/)
#   -DryRun  Show what would be changed without modifying files

param(
    [string]$Path,
    [switch]$DryRun
)

$flippingDir = Join-Path $env:USERPROFILE ".runelite\flipping"

function Get-DefaultSlotTimers {
    return @(
        @{ slotIndex = 0; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 1; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 2; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 3; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 4; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 5; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 6; offerOccurredAtUnknownTime = $false },
        @{ slotIndex = 7; offerOccurredAtUnknownTime = $false }
    )
}

function Fix-SlotTimers {
    param([string]$FilePath)

    $fileName = Split-Path $FilePath -Leaf
    if ($fileName -match "backup|accountwide|checkpoint|\.pre-") {
        Write-Host "  Skipping non-account file: $fileName" -ForegroundColor DarkGray
        return
    }

    Write-Host "Checking: $fileName" -ForegroundColor Cyan
    $json = Get-Content $FilePath -Raw | ConvertFrom-Json

    if (-not ($json.PSObject.Properties.Name -contains "slotTimers")) {
        Write-Host "  No slotTimers field found — skipping" -ForegroundColor Yellow
        return
    }

    $timers = $json.slotTimers
    if ($timers.Count -eq 8) {
        Write-Host "  slotTimers OK (8 entries)" -ForegroundColor Green
        return
    }

    Write-Host "  slotTimers BROKEN: $($timers.Count) entries (expected 8)" -ForegroundColor Red

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would fix slotTimers to 8 default entries" -ForegroundColor Yellow
        return
    }

    # Create backup
    $backupPath = "$FilePath.pre-slottimer-fix"
    Copy-Item $FilePath $backupPath -Force
    Write-Host "  Backup: $backupPath" -ForegroundColor DarkGray

    # Fix the slotTimers
    $json.slotTimers = Get-DefaultSlotTimers

    # Write back (ConvertTo-Json with sufficient depth)
    $json | ConvertTo-Json -Depth 20 -Compress | Set-Content $FilePath -Encoding UTF8
    Write-Host "  FIXED: slotTimers populated with 8 default entries" -ForegroundColor Green
}

# Main
Write-Host ""
Write-Host "=== Flipping Utilities slotTimers Fix ===" -ForegroundColor White
Write-Host ""

if ($Path) {
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        exit 1
    }
    Fix-SlotTimers -FilePath $Path
} else {
    $files = Get-ChildItem $flippingDir -Filter "*.json" -File
    foreach ($file in $files) {
        Fix-SlotTimers -FilePath $file.FullName
    }
}

Write-Host ""
Write-Host "Done. Restart RuneLite to apply changes." -ForegroundColor White
