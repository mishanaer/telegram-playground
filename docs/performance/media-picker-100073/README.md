# Media picker scroll with warp — September 10, 2026

**58.28 presented FPS across the full recording:** 1,317 frames in 22.598117 seconds. This is a manual scroll with warp enabled, including pauses between gestures; it is not a claim of stable 60 FPS.

## Conditions

- Physical iPhone 15 Pro Max, iOS 27.0 (24A5418b), Release arm64 build 100073.
- Application source at `4e604924ad406d97058348fcd167e952701f4bbc`; functional warp fix in `c58ffa0c077fd06e19e364a6b2ab22769d0659ea`.
- The user confirmed scrolling before capture and stopped after recording ended. The camera tile stayed outside the viewport. The implementation pauses camera capture when its tile is offscreen; the trace contains RGB0 programming and no RGB1/YUV programming, consistent with excluding its preview.
- Thermal state was nominal throughout; Low Power Mode was off at preflight.
- Instruments: Blank template with Display, Core Animation FPS, and Thermal State. Requested duration 20 seconds; the trace's actual duration was 22.598117 seconds. The full trace window is included.
- LLDB was detached before recording. A temporary A/B helper had been loaded during preparation, but its arm call failed before making changes or creating a timer. Automatic scrolling and warp-off comparison never ran. The helper has no constructor or active observer in that state; the app's source and build were unchanged.

## Results

| Metric | Result |
| --- | ---: |
| New presented frames | 1,317 |
| Full recording | 22.598117 s |
| Frames / full recording duration | **58.28 FPS** |
| Interframe rate, first to last presentation | 59.19 FPS |
| Median interframe interval | 12.50 ms |
| P95 interframe interval | 26.05 ms |
| P99 interframe interval | 113.57 ms |
| Longest interframe gap | 1,133.59 ms |

The longest gap occurred at 16.179–17.312 seconds. There were no new recorded HID timestamps in that gap until approximately 54 ms before the next presentation. This is consistent with a pause between gestures; it does not establish that warp stalled. The gap remains included in the average. Adaptive refresh and manual gesture pauses mean that interframe gaps cannot automatically be classified as dropped frames.

## Validation and scope

All 1,317 in-window presentation times and swap IDs match between raw IOMFB `ON_GLASS` events and Core Animation `FrameInfo`, after converting their clock domains. Explicit `SWAP_REPEAT` events are excluded. Reused surface IDs do not imply identical pixels, so they are not used to discard frames. Core Animation contains 13 additional events beyond the end of the recording window; those do not enter the result.

The measured quantity is display presentation cadence during the confirmed grid-scroll scenario with warp. It is not callback cadence, isolated GPU execution time, or a measurement of warp's incremental cost. No warp-off, emoji-picker, or Claude-version baseline was captured, so no comparative speedup is claimed. The earlier simulator callback measurements and the earlier recording containing camera activity are not comparable baselines.

## Data

- [Summary, validation counts, and all one-second bins](summary.json)
- [All in-window presentation timestamps](presentations.csv), relative to the trace start

These compact exports preserve every in-window frame and permit recomputing the reported FPS and intervals. Raw Instruments traces and full event exports are retained locally, outside Git; reproducing the cross-source validation requires those original exports. Device identifiers, personal device names, media, compiled diagnostic libraries, and unrelated recordings are not included.
