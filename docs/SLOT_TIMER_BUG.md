# slotTimers Bug: Silent Trade Recording Failure

## Summary

An empty `slotTimers` array in the Flipping Utilities account JSON file causes the plugin to throw `IndexOutOfBoundsException` on every GE offer event, **silently dropping all real-time trades**. The plugin appears functional (UI loads, GE History imports work) but records zero live trades.

## Discovery

**Date:** March 14, 2026

**Symptom:** Only certain items appeared in FU history despite active trading. Investigation of `Knife Lord.json` revealed:
- Last real-time offer (slot >= 0): February 26, 2026
- GE History Tab imports (slot -1) continued working normally
- 9 `IndexOutOfBoundsException` errors in `client.log` per session

## Root Cause

### The Bug

`NewOfferEventPipelineHandler.screenOfferEvent()` (lines 134, 152, 163) calls:
```java
slotActivityTimers.get(newOfferEvent.getSlot())
```

This retrieves a `List<SlotActivityTimer>` from `AccountData.getSlotTimers()` and indexes into it using the GE slot number (0-7). If the list is empty, **any `.get()` call throws `IndexOutOfBoundsException`**, which is uncaught — the entire offer event is silently dropped by RuneLite's EventBus.

The same bug exists in `FlippingPlugin.setWidgetsOnSlotTimers()` (line 758), which loops `get(0)` through `get(7)` without checking list size.

### The Trigger

The data recovery process (Phase 5) produced a valid JSON file with `"slotTimers": []`. This is structurally valid JSON but semantically broken — the plugin expects exactly 8 entries. The plugin has no defensive initialization or size check for this field.

### Error Signature

```
WARN  n.runelite.client.eventbus.EventBus - Uncaught exception in event subscriber
java.lang.IndexOutOfBoundsException: Index 1 out of bounds for length 0
    at java.base/java.util.Objects.checkIndex(Unknown Source)
    at java.base/java.util.ArrayList.get(Unknown Source)
    at com.flippingutilities.controller.NewOfferEventPipelineHandler.screenOfferEvent(NewOfferEventPipelineHandler.java:163)
```

### Why Only Some Items Appeared

GE History Tab imports bypass `screenOfferEvent()` entirely — they use a separate code path that inserts offers with `slot = -1` directly into the history. These continued working, which masked the fact that real-time recording was completely broken.

## Affected Versions

- **Flipping Utilities v1.4.1** (confirmed)
- Likely all versions that use `slotTimers` without bounds checking

## Impact

- ~16 days of real-time trade data lost (Feb 26 - Mar 14, 2026)
- All GE slots affected (plugin-wide failure, not per-slot)
- No user-visible error in the plugin UI

## Fix

Populate `slotTimers` with 8 default `SlotActivityTimer` entries:

```json
"slotTimers": [
    {"slotIndex": 0, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 1, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 2, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 3, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 4, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 5, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 6, "offerOccurredAtUnknownTime": false},
    {"slotIndex": 7, "offerOccurredAtUnknownTime": false}
]
```

Fix script: [`scripts/phase6-slot-timer-fix/fix_slot_timers.ps1`](../scripts/phase6-slot-timer-fix/fix_slot_timers.ps1)

Applied manually on March 14, 2026 with RuneLite closed. Backup created at `Knife Lord.json.pre-fix-backup`.

## Upstream Vulnerability

This is a latent bug in the upstream Flipping Utilities plugin ([Flipping-Utilities/rl-plugin](https://github.com/Flipping-Utilities/rl-plugin)). Any scenario that produces an empty or undersized `slotTimers` list will trigger it:
- Data file corruption/recovery
- Manual JSON editing
- Downgrade from a version that changed the slotTimers schema
- Race condition during first-time account initialization

The fix should be a bounds check or defensive initialization in `screenOfferEvent()` and `setWidgetsOnSlotTimers()`.
