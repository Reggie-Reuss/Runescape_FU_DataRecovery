# Raw Recovery Files (Excluded from Repository)

These large files are excluded via `.gitignore` because they are 1.5MB+ each and contain mostly null bytes or binary data with sparse JSON fragments.

## Files

| File | Size | Description |
|------|------|-------------|
| `RunescapeUsername.backup.recovered-feb25.json` | 1.5MB | VSS shadow copy of backup file (Feb 25 9:38 AM). Contains **6 data blocks** with FU JSON fragments at NTFS cluster boundaries. This is the primary recovery source. |
| `RunescapeUsername.recovered-feb25.json` | 1.5MB | VSS shadow copy of main file (modified Feb 24 21:54). Only 8KB of valid FU data at offset 0; remainder is Spotify cache and browser extension data from reallocated NTFS clusters. |
| `RunescapeUsername.recovered-feb25-fixed.json` | 1.4MB | Intermediate repair attempt - trimmed to last closing brace. |
| `RunescapeUsername.recovered-feb26.json` | 1.5MB | VSS shadow copy from Feb 26 7:42 PM. Starts with binary data `D9-D5-05-F9`, not recoverable as JSON. |
| `osrs_mapping.json` | 837KB | OSRS item ID-to-name mapping. Download from: https://prices.runescape.wiki/api/v1/osrs/mapping |

## How to regenerate (if VSS snapshots still exist)

```powershell
# List available shadow copies
vssadmin list shadows /for=C:

# Copy from shadow copy (replace ShadowCopyN with actual number)
copy "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyN\Users\Reggie\.runelite\flipping\RunescapeUsername.json" ".\RunescapeUsername.recovered.json"
copy "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyN\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.json" ".\RunescapeUsername.backup.recovered.json"
```
