# RuneLite Flipping Utilities — Data Recovery

Forensic recovery of ~1,400 lost Grand Exchange trade history entries after a RuneLite crash corrupted the [Flipping Utilities](https://github.com/Flipping-Utilities/flipping-utilities) plugin data file on an NVMe SSD.

> **Privacy note:** The RuneScape character name `RunescapeUsername` is a placeholder used throughout this repository. It replaces the original in-game username to protect account identity. All scripts and data files use this placeholder consistently.

---

## The Problem

On February 25, 2026, RuneLite crashed mid-save while the Flipping Utilities plugin was writing trade history to disk. Java's `BufferedWriter` had flushed only the first **8KB** (one buffer) of a ~600KB file before the process died. The remaining ~1,400 trade entries existed only in Java heap memory and were permanently lost.

The next day, FU detected the corruption (`MalformedInputException: Input length = 1`), fell back to a stale backup that hadn't been recently checkpointed (~67 items), and migrated — leaving virtually no trade history.

**Complicating factors:**
- Windows 11 NVMe SSD with inline TRIM enabled (freed clusters zeroed within seconds)
- No File History configured
- No cloud backup of `.runelite/` directory
- Only 3 VSS shadow copies available (one pre-crash, two post-crash)

## Recovery Approach

### [Phase 1: Diagnosis](scripts/phase1-diagnosis/)

Analyzed RuneLite logs to pinpoint the exact crash time (Feb 25, 22:48+ EST) and corruption detection (Feb 26, 19:25 EST). Hex-level analysis of the corrupted file confirmed the 8KB write boundary — a signature of Java's `BufferedWriter` crash behavior.

### [Phase 2: Repair Attempts](scripts/phase2-repair-attempts/)

Retrieved files from 3 Windows VSS shadow copies. The pre-crash shadow copy (Feb 25, 9:38 AM) preserved the file state, but the 1.5MB recovered files contained only sparse valid data surrounded by null bytes and reallocated cluster garbage (Spotify cache, browser extension data).

### [Phase 3: Partial Extraction](scripts/phase3-partial-extraction/)

Extracted 20 complete trade items from the 8KB valid header of the main file. Analyzed an external GE transaction export as a supplementary data source.

### [Phase 4: Block Analysis — Breakthrough](scripts/phase4-block-analysis/)

Full byte-level scan of the backup shadow copy revealed **6 data blocks** at NTFS cluster boundaries containing FU JSON fragments. Using brace-depth JSON parsing, extracted **67 unique trade items** with complete slot offer histories spanning March 2024 to February 2026.

See: [Block Map Diagram](docs/BLOCK_MAP.md)

### [Phase 5: Merge and Finalize](scripts/phase5-merge-finalize/)

Merged the 67 shadow-copy trades with 1,024 transactions (415 additional items) from the [RuneLite.net account profile](https://runelite.net/account/grand-exchange), which independently tracks GE activity server-side. Resolved all item names using the OSRS Wiki API and Jagex GE database. Produced a final FU-compatible JSON file.

### Failed: Raw Disk Recovery

As a last resort, attempted raw sector carving with PhotoRec using a custom signature matching the FU file header (`{"lastOffers`). **Zero files recovered** — confirming SSD TRIM had already zeroed all freed clusters, 6 days after the crash.

---

## Results

| Metric | Value |
|--------|-------|
| Original trades lost | ~1,400 items |
| Recovered from VSS shadow copies | 67 items |
| Added from external GE export | 415 items |
| **Total recovered** | **482 items (1,108 slot offers)** |
| Date range covered | March 2024 — February 2026 |
| Recovery tools that failed | Recuva, Disk Drill, PhotoRec |

---

## Why Full Recovery Was Impossible

```
The crash → NTFS freed old clusters → SSD TRIM zeroed them (seconds)
                                         ↓
                            Original data permanently erased
```

1. **Java's 8KB buffer**: The crash interrupted a periodic save after only one buffer flush (8,192 bytes), destroying the previous valid file
2. **NTFS cluster reallocation**: The new 8KB write used different clusters than the old 600KB file; the old clusters were freed
3. **NVMe inline TRIM**: Windows 11 immediately TRIMmed the freed clusters; the SSD controller zeroed them before any recovery could be attempted
4. **Stale backup**: FU's backup file hadn't been checkpointed since the account had ~67 items — the full 1,400-item history was never in the backup

---

## Repository Structure

```
RL_FU_DataRecovery/
├── README.md
├── LICENSE
├── .gitignore
├── scripts/
│   ├── phase1-diagnosis/           # Log analysis, hex inspection
│   ├── phase2-repair-attempts/     # VSS recovery, file repair
│   ├── phase3-partial-extraction/  # 8KB header extraction, GE analysis
│   ├── phase4-block-analysis/      # NTFS block scanning, 67-trade recovery
│   └── phase5-merge-finalize/      # GE merge, item name resolution, validation
├── data/
│   ├── samples/                    # Intermediate recovery outputs
│   ├── input/                      # External GE transaction data
│   ├── output/                     # Final merged FU-compatible JSON
│   └── reference/                  # Post-crash file state, PhotoRec sig
├── docs/
│   ├── TIMELINE.md                 # Chronological event sequence
│   ├── METHODOLOGY.md              # Technical deep-dive
│   └── BLOCK_MAP.md                # Backup file data block diagram
└── raw-recovery/                   # Large recovery files (gitignored)
    └── README.md                   # Explains excluded files
```

## Technologies Used

- **Windows Volume Shadow Copy Service (VSS)** — Retrieved pre-crash file snapshots using `vssadmin` and `\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy*` paths
- **NTFS cluster-level forensics** — Byte-by-byte scanning to locate data blocks at cluster boundaries in 1.5MB shadow copy files
- **PowerShell byte-level analysis** — Custom scripts using `[System.IO.File]::ReadAllBytes()` and regex-based JSON fragment parsing
- **JSON brace-depth extraction** — Recovered complete objects from corrupted fragments by tracking `{}`/`[]` nesting depth
- **OSRS Wiki API** — Resolved 431 item IDs to names via `prices.runescape.wiki/api/v1/osrs/mapping`
- **Jagex GE Database** — Manually resolved 15 items too new for the Wiki mapping
- **PhotoRec** — Raw sector carving with custom file signature (confirmed TRIM had already run)

## External Data Sources

- **grand-exchange.json**: GE transaction history exported from the [RuneLite Account Profile](https://runelite.net/account/grand-exchange). RuneLite.net tracks Grand Exchange activity server-side for logged-in users, providing a secondary source of trade data independent of the local FU plugin files.
- **osrs_mapping.json**: Item ID-to-name database from [OSRS Wiki Prices API](https://prices.runescape.wiki/api/v1/osrs/mapping) (excluded from repo, 837KB — freely downloadable)
