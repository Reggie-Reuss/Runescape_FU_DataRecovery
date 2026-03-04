# Technical Methodology

## Flipping Utilities Data Format

The [Flipping Utilities](https://github.com/Flipping-Utilities/flipping-utilities) RuneLite plugin stores Grand Exchange trade history as JSON in `~/.runelite/flipping/<username>.json`.

### File Structure

```json
{
  "version": 1,
  "lastOffers": {
    "0": { "uuid": "...", "b": false, "id": 12321, "cQIT": 0, "p": 0, "t": 1771978472000, "s": 0, "st": "SELLING", ... },
    "1": { ... },
    ...
  },
  "trades": [
    {
      "id": 26245,
      "name": "Virtus robe bottom",
      "tGL": 8,
      "h": {
        "sO": [
          { "uuid": "...", "b": true, "id": 26245, "cQIT": 1, "p": 64175420, "t": 1727566846000, "s": 7, "st": "BOUGHT", "tAA": 1177, "tSFO": 280, "tQIT": 1, "tradeStartedAt": 1727566845000, "beforeLogin": false },
          ...
        ]
      }
    },
    ...
  ],
  "sessionStartTime": 0,
  "slotTimers": [],
  "recipeFlipGroups": [],
  "lastStoredAt": 1771988086233,
  "lastModifiedAt": 1708053179683
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `lastOffers` | Current state of GE slots 0-7 |
| `trades[]` | Array of tracked items, each with historical slot offers |
| `trades[].h.sO[]` | Slot offer history per item (individual buy/sell transactions) |
| `fB` | Account name (the "flipper bot" identifier) |
| `tGL` | GE buy limit for the item |
| `cQIT` | Quantity in trade |
| `tSFO` | Time since first offer |
| `st` | State: BOUGHT, SOLD, BUYING, SELLING, CANCELLED_BUY, CANCELLED_SELL |

### Backup Behavior

FU maintains `<username>.backup.json` as a fallback. On load failure (e.g., `MalformedInputException`), FU logs a warning and loads from backup instead. The backup is updated at periodic "checkpoint" intervals, not on every save.

---

## Phase 1: Crash Diagnosis

### Log Analysis

RuneLite stores logs in `~/.runelite/logs/client_YYYY-MM-DD.N.log`. Key log entries that identified the crash:

**Feb 25 log** — Last entry at 22:48, no shutdown message = process killed mid-execution:
```
[2026-02-25 22:48:00] [Client] INFO  ...
```

**Feb 26 log** — FU detects corruption on next startup:
```
WARN c.f.db.TradePersister - Got exception com.google.gson.JsonSyntaxException:
java.nio.charset.MalformedInputException: Input length = 1 while loading data for
RunescapeUsername. Will try loading from backup
```

The `MalformedInputException: Input length = 1` means Java's UTF-8 decoder hit a single invalid byte — the file was truncated mid-character during the crash.

### Java BufferedWriter and the 8KB Pattern

Java's `BufferedWriter` uses an 8,192-byte internal buffer. Data is only flushed to disk when:
1. The buffer fills up (every 8KB)
2. `flush()` is explicitly called
3. The writer is closed

A crash after the first buffer flush produces exactly **8,192 bytes** of valid data followed by whatever was previously on disk. This is precisely what we observed.

---

## Phase 2: VSS Shadow Copy Recovery

### Windows Volume Shadow Copy Service

VSS creates block-level copy-on-write snapshots. Three shadow copies existed:

```
ShadowCopy1: Feb 25 09:38 AM  ← Before the crash (best candidate)
ShadowCopy2: Feb 26 07:42 PM  ← After corruption detected
ShadowCopy3: Mar 01 08:03 PM  ← After migration (too late)
```

### Recovery Commands

```powershell
# List available shadow copies
vssadmin list shadows /for=C:

# Copy files from shadow copy (requires admin)
copy "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Users\Reggie\.runelite\flipping\RunescapeUsername.json" "RunescapeUsername.recovered-feb25.json"
copy "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.json" "RunescapeUsername.backup.recovered-feb25.json"
```

### What We Found

The recovered files were 1.5MB each but contained mostly null bytes or garbage data from reallocated NTFS clusters. Only sparse blocks contained valid FU JSON. See [BLOCK_MAP.md](BLOCK_MAP.md) for the full analysis.

---

## Phase 3: Byte-Level Block Scanning

### Approach

Rather than treating the files as text, we scanned them byte-by-byte to find all non-null ranges:

```powershell
# Scan for non-null data blocks
$bytes = [System.IO.File]::ReadAllBytes($path)
$inData = $false
for ($i = 0; $i -lt $bytes.Length; $i++) {
    $isNull = ($bytes[$i] -eq 0)
    if (-not $isNull -and -not $inData) {
        # Start of a data block
        $blockStart = $i; $inData = $true
    }
    if ($isNull -and $inData) {
        # End of a data block
        # Record: [$blockStart - $i]
        $inData = $false
    }
}
```

This revealed **6 data blocks** in the backup file at positions corresponding to NTFS cluster boundaries (multiples of 4,096 or 8,192 bytes).

### Extracting Complete Trade Items

From each data block, we extracted complete JSON objects using brace-depth tracking:

```powershell
# Find {"id":N,"name":"X"...} patterns and track brace depth to find closing }
$pattern = '\{"id":(\d+),"name":"([^"]+)"'
$matches = [regex]::Matches($text, $pattern)
foreach ($m in $matches) {
    $depth = 0
    for ($i = $m.Index; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '{') { $depth++ }
        if ($text[$i] -eq '}') { $depth--; if ($depth -eq 0) { break } }
    }
    # $text[$m.Index..$i] is a complete trade item
}
```

Blocks 5 and 6 started mid-item (inside slot offer arrays), so no complete items could be extracted from them — their item headers were in the missing gap data.

---

## Phase 4: Merging with External GE Data

### Grand Exchange Data from RuneLite.net

The GE transaction history was obtained from the [RuneLite.net account profile](https://runelite.net/account/grand-exchange). RuneLite.net independently tracks Grand Exchange activity server-side for users who log in to the RuneLite client with their RuneLite account. This provided a secondary data source completely independent of the corrupted local FU plugin files.

The export (`grand-exchange.json`) uses a simpler format than FU:

```json
[
  {"buy": false, "itemId": 6812, "quantity": 43, "price": 2344, "time": 1758806732023},
  ...
]
```

### Conversion to FU Format

Each GE transaction was converted to an FU slot offer:

| GE Field | FU Field | Transformation |
|----------|----------|---------------|
| `buy` | `b`, `st` | `true` → `b:true, st:"BOUGHT"`; `false` → `b:false, st:"SOLD"` |
| `itemId` | `id` | Direct mapping |
| `quantity` | `cQIT`, `tQIT` | Same value for both |
| `price` | `p` | Direct mapping |
| `time` | `t` | Direct mapping (both Unix ms) |
| — | `uuid` | Generated via `[guid]::NewGuid()` |
| — | `s` | Default to slot 0 |
| — | `tradeStartedAt` | `time - 1000` (1 second before completion) |

### Item Name Resolution

GE exports contain only `itemId`, not names. Item names and GE limits were resolved via the OSRS Wiki API:

```
https://prices.runescape.wiki/api/v1/osrs/mapping
```

15 items were too new for the mapping API. These were resolved individually via the Jagex GE database:

```
https://secure.runescape.com/m=itemdb_oldschool/viewitem?obj=<itemId>
```

### Merge Strategy

1. Group GE transactions by item ID
2. For items already in the recovered data: append new slot offers (deduplicate by timestamp)
3. For new items: create FU trade entries with proper structure
4. Add `"version": 1` to match current FU format

---

## Phase 5: Why Full Recovery Failed

### SSD TRIM

Windows 11 issues inline TRIM commands to NVMe drives immediately when clusters are freed. TRIM instructs the SSD controller to erase those physical NAND cells. On drives supporting DZAT (Deterministic Zeroes After TRIM), reading TRIMmed sectors returns all zeros.

The original ~600KB file's NTFS clusters were freed when the crash wrote a new 8KB file. TRIM ran within seconds. By the time recovery was attempted (6 days later), those sectors were permanently zeroed.

### Tools That Failed

| Tool | Type | Result |
|------|------|--------|
| Recuva | MFT-based recovery | No file found >8KB |
| Disk Drill | File carving + MFT | No file found >8KB |
| PhotoRec | Raw sector carving with custom JSON signature | 0 files recovered |

The custom PhotoRec signature (`photorec.sig`):
```
json 0 0x7b 0x22 0x6c 0x61 0x73 0x74 0x4f 0x66 0x66 0x65 0x72 0x73
```
This matches files starting with `{"lastOffers` — the exact FU file header. Zero results confirmed TRIM had fully processed all relevant sectors.
