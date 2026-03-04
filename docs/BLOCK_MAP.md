# Backup File Block Map

The VSS shadow copy of `RunescapeUsername.backup.json` (recovered Feb 25 9:38 AM) is 1,532,613 bytes. Only **45,765 bytes** (3%) contain valid Flipping Utilities JSON data, scattered across 6 non-contiguous blocks at NTFS cluster boundaries.

## Visual Layout

```
Offset (bytes)    Content
─────────────────────────────────────────────────────────────
0         ┌─────────────────────────────────┐
          │  BLOCK 1 (8,192 bytes)          │  FU JSON: lastOffers + 20 trade items
          │  Timestamps: Feb 2026–Dec 2025  │  Ends mid-field: "tSFO":
8,192     └─────────────────────────────────┘
          ┊                                 ┊
          ┊  GAP: 49,152 bytes (null/junk)  ┊
          ┊                                 ┊
57,344    ┌─────────────────────────────────┐
          │  BLOCK 2 (8,192 bytes)          │  Continues from Block 1: 89929,"beforeLogin"...
          │  Timestamps: Jul 2025–Jun 2025  │  15 complete trade items
          │  Items: Civitas illa fortis tp,  │
          │    Magic shield, Adamant dart,  │
65,536    └─────────────────────────────────┘
          ┊                                 ┊
          ┊  GAP: 188,416 bytes (184 KB)    ┊
          ┊                                 ┊
253,952   ┌─────────────────────────────────┐
          │  BLOCK 3 (12,288 bytes)         │  25 complete trade items — largest block
          │  Timestamps: Oct 2024–Sep 2024  │  Items: Mithril knife, Ruby amulet,
          │  Starts mid-item: iteCode":"1"  │    Masori mask, SGS, Virtus robe bottom
266,240   └─────────────────────────────────┘
          ┊                                 ┊
          ┊  GAP: 258,048 bytes (252 KB)    ┊
          ┊                                 ┊
524,288   ┌─────────────────────────────────┐
          │  BLOCK 4 (4,096 bytes)          │  7 complete trade items
          │  Timestamps: Aug 2024           │  Items: Mithril platebody, Verac's brassard
528,384   └─────────────────────────────────┘
          ┊                                 ┊
          ┊  GAP: 651,264 bytes (636 KB)    ┊  ← LARGEST GAP
          ┊                                 ┊
1,179,648 ┌─────────────────────────────────┐
          │  BLOCK 5 (8,192 bytes)          │  NO complete trade items extractable
          │  Timestamps: Mar 2024–Jul 2024  │  Contains only mid-item slot offer arrays
          │  All offers for item id=19617   │  (item headers are in the gap above)
1,187,840 └─────────────────────────────────┘
          ┊                                 ┊
          ┊  GAP: 339,968 bytes (332 KB)    ┊
          ┊                                 ┊
1,527,808 ┌─────────────────────────────────┐
          │  BLOCK 6 (4,805 bytes)          │  NO complete trade items extractable
          │  Timestamps: Aug 2025–Feb 2026  │  Contains file footer:
          │  Ends: ...recipeFlipGroups:[],  │    lastStoredAt, lastModifiedAt
          │    lastStoredAt:1771988086233}   │  ← END OF ORIGINAL FILE
1,532,613 └─────────────────────────────────┘
```

## Block Connection Analysis

Some blocks are **direct continuations** of the previous block (the data was contiguous in the original file):

| Transition | Connection? | Evidence |
|------------|-------------|----------|
| Block 1 → 2 | **YES** | Block 1 ends `"tSFO":` → Block 2 starts `89929,"beforeLogin":false}` |
| Block 2 → 3 | No (gap) | Different item contexts; 184KB missing between them |
| Block 3 → 4 | **YES** | Block 3 ends `"tradeSt` → Block 4 starts `artedAt":1721867528994` |
| Block 4 → 5 | No (gap) | `"bef` + `00,` doesn't form valid JSON; 636KB missing |
| Block 5 → 6 | No (gap) | Different time periods; 332KB missing |

## Recovery Results by Block

| Block | Valid Bytes | Complete Items | Slot Offers | Date Range |
|-------|------------|----------------|-------------|------------|
| 1 | 8,192 | 20 | 26 | Dec 2025 – Feb 2026 |
| 2 | 8,192 | 15 | 28 | Jun – Jul 2025 |
| 3 | 12,288 | 25 | 42 | Sep – Oct 2024 |
| 4 | 4,096 | 7 | 14 | Aug 2024 |
| 5 | 8,192 | 0 | 41 | Mar – Jul 2024 |
| 6 | 4,805 | 0 | 20 | Aug 2025 – Feb 2026 |
| **Total** | **45,765** | **67** | **171** | **Mar 2024 – Feb 2026** |

## Why 1,452 KB is Missing

The gaps between blocks (totaling 1,486,848 bytes) represent NTFS clusters that were:

1. **Allocated to the original large backup file** when it was ~600KB of valid FU JSON
2. **Freed when FU wrote a new smaller backup** at Feb 25 09:17
3. **Reallocated by NTFS** to other files (Spotify cache, browser extensions, etc.)
4. The VSS shadow copy captured the full cluster extent but the gap clusters had already been overwritten with unrelated data
