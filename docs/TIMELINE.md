# Event Timeline

All times are Eastern Standard Time (EST).

## Feb 24, 2026

| Time | Event |
|------|-------|
| 18:55 | RuneLite 1.12.17 session starts |
| 21:54 | **Last successful write to `RunescapeUsername.json`** — file contains ~1,400 trade entries (~600KB) |
| 21:57 | Last log entry for this session — no graceful shutdown logged |

## Feb 25, 2026

| Time | Event |
|------|-------|
| 09:17 | RuneLite 1.12.18 starts — FU loads `RunescapeUsername.json` successfully (no errors logged). New FU plugin version writes backup file. |
| **09:38** | **VSS Shadow Copy 1 taken** — captures the last-known-good state of both main and backup files |
| 19:17 | FU reloads data for RunescapeUsername — successful, no errors |
| 22:48 | Last log entry — RuneLite is still running |
| ~22:49+ | **THE CRASH** — RuneLite/JVM crashes during a periodic FU save. Java's `BufferedWriter` had flushed only the first 8KB (one buffer) to disk before the process died. The remaining ~590KB of trade data existed only in Java heap memory and was lost. |

## Feb 26, 2026

| Time | Event |
|------|-------|
| 19:17 | RuneLite starts new session |
| 19:25 | **FU detects corruption**: `WARN c.f.db.TradePersister - Got exception com.google.gson.JsonSyntaxException: java.nio.charset.MalformedInputException: Input length = 1 while loading data for RunescapeUsername. Will try loading from backup` |
| 19:25 | FU falls back to backup file — backup contains stale data (~67 items, not recently checkpointed) |
| **19:42** | **VSS Shadow Copy 2 taken** — but main file is already corrupted at this point |
| 20:35 | FU migrates account data: `Migrating account data for RunescapeUsername (version=null, trades=1)` — only 1 trade survives from the stale backup |

## Mar 1, 2026

| Time | Event |
|------|-------|
| 19:50 | Backup checkpoint created — but now contains only the post-crash minimal data |
| **20:03** | **VSS Shadow Copy 3 taken** — too late, data already migrated to near-empty state |

## Mar 3, 2026 — Recovery begins

| Phase | Action | Result |
|-------|--------|--------|
| Phase 1 | Log analysis, crash identification | Identified exact crash time (Feb 25 ~22:49) and corruption detection (Feb 26 19:25) |
| Phase 2 | VSS shadow copy recovery | Retrieved 3 shadow copies of main + backup files |
| Phase 3 | Partial extraction from 8KB header | Recovered 20 complete trade items |
| Phase 4 | Full block scan of backup shadow copy | Found 6 data blocks, extracted **67 unique trade items** |
| Phase 5 | Merged with GE data from [RuneLite.net account profile](https://runelite.net/account/grand-exchange) | Combined to **482 items** with 1,108 slot offers |
| Final | PhotoRec raw disk scan | 0 results — SSD TRIM had already zeroed freed clusters |

## Feb 26 – Mar 14, 2026 — Silent trade recording failure

| Time | Event |
|------|-------|
| ~Feb 26 | Recovery file deployed with `"slotTimers": []` — plugin begins throwing `IndexOutOfBoundsException` on every GE offer event |
| Feb 26 – Mar 14 | All real-time GE trades silently dropped; GE History Tab imports (slot -1) continue working normally, masking the failure |
| Mar 14 01:03 | `client.log` shows 3 `IndexOutOfBoundsException` at `screenOfferEvent` lines 134, 152, 163 |
| Mar 14 14:53 | Same errors repeated on second session — confirmed systematic, not transient |
| Mar 14 17:07 | Root cause identified: `slotTimers` empty array causes `ArrayList.get(slot)` to fail for any GE slot index |
| Mar 14 17:15 | Fix applied: populated `slotTimers` with 8 default entries while RuneLite closed; backup created at `Knife Lord.json.pre-fix-backup` |

## Phase 6: slotTimers Fix

| Phase | Action | Result |
|-------|--------|--------|
| Phase 6 | Diagnosed `IndexOutOfBoundsException` in `screenOfferEvent()` | Empty `slotTimers[]` from recovery caused plugin to silently drop all real-time GE offers |
| Phase 6 | Populated `slotTimers` with 8 default slot entries | Real-time trade recording restored |

See: [SLOT_TIMER_BUG.md](SLOT_TIMER_BUG.md) for full technical analysis.
