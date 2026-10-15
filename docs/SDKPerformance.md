# SDK performance and dependencies — iOS

This report records measured build artifacts and the runtime benchmark procedure for the current development snapshot. The customer-facing overview is [iOS SDK performance and dependencies](https://docs.userpilot.com/developer/installation/mobile/ios/sdk-performance).

Benchmark tools and detailed evidence are kept locally under `benchmarks/`, which is Git-ignored. This report preserves the measured results and methodology; the local files are not included in a fresh checkout.

## Measurement identity

- Date: October 14, 2026.
- Branch: `refactor/multi-instance-runtime`.
- SDK commit: `395957484e1d550f5d79f53c65c1359c3edc2ad0`.
- Declared SDK version: `1.4.1`; this development snapshot is **not** the published `1.4.1` release.
- Scope: Release artifacts and a small native host using initialization, identify, and custom events.
- Units: one MiB = 1,048,576 bytes; Android memory APIs report KiB = 1,024 bytes.
- Cross-platform scope: the Android snapshot includes the debugger; the iOS snapshot does not. These are separately identified builds, not an identical-feature size competition.

## Results and evidence

| Metric | Bytes | Size |
| --- | ---: | ---: |
| arm64 device framework | 2,718,228 | 2.59 MiB |
| arm64 Mach-O binary only | 2,368,640 | 2.26 MiB |
| Complete unpacked XCFramework | 8,033,859 | 7.66 MiB |
| XCFramework ZIP, no dSYMs | 2,951,127 | 2.81 MiB |
| Reference app without SDK | 168,478 | 0.16 MiB |
| Reference app with SDK | 3,308,450 | 3.15 MiB |
| Reference app bundle increase | 3,139,972 | 2.99 MiB |

Artifact sizes and SHA-256 (`benchmarks/results/2026-10-14/artifact-size.json`) and reference host sizes (`benchmarks/results/2026-10-14/host-size.json`) are the machine-readable evidence. Both SDK and reference-host Release builds succeeded. SDK source and public APIs were not changed.

Three warmed baseline/SDK pairs completed on **iPhone 14 Plus (iPhone14,8), iOS 26.6.2 (23G90)**. All measured samples stayed foreground with normal thermal status. A separate smoke run matched all 50 distinct event pushes to successful backend replies by Phoenix ref; identify also succeeded.

Evidence: runtime summary (`benchmarks/results/2026-10-14/runtime-summary.json`), device and workload metadata (`benchmarks/results/2026-10-14/runtime-metadata.json`), raw samples (`benchmarks/results/2026-10-14/runtime`), and ACK verification (`benchmarks/results/2026-10-14/smoke-verification.json`). The results are included inline below; these supporting files are available only in the local benchmark archive.

### CPU

Values are median (minimum–maximum) across three runs; differences use matched pairs.

| Window | Host without SDK (% of one CPU core) | Host with SDK (% of one CPU core) | Paired difference (% of one CPU core) |
| --- | ---: | ---: | ---: |
| Connected idle, 20–30 s | 0.03 (0.03–0.24) | 0.04 (0.03–0.05) | 0.01 (-0.21–0.03) |
| 50-event burst, 30–45 s | 0.03 (0.03–0.41) | 1.06 (1.04–1.06) | 1.01 (0.65–1.03) |
| After burst, 45–60 s | 0.02 (0.02–0.03) | 0.06 (0.05–0.06) | 0.03 (0.02–0.04) |

CPU differences are **percentage points**, not relative percentage increases. A paired difference is the median of `SDK_i - baseline_i`; it need not equal the difference of the two independently reported medians. Process CPU includes the benchmark sampler in both variants.

### RAM — physical footprint

Values are median (minimum–maximum) across three runs; differences use matched pairs.

| Window | Host without SDK (MiB) | Host with SDK (MiB) | Paired difference (MiB) |
| --- | ---: | ---: | ---: |
| Connected idle, 20–30 s | 5.63 (5.59–6.17) | 7.48 (7.34–7.59) | 1.71 (1.31–2.00) |
| 50-event burst, 30–45 s | 5.69 (5.64–5.89) | 7.45 (7.43–7.52) | 1.80 (1.55–1.82) |
| After burst, 45–60 s | 5.64 (5.64–5.69) | 7.43 (7.43–7.45) | 1.79 (1.76–1.79) |

The largest sampled SDK-host physical footprint during seconds 20–60 was **7.59 MiB**. One-second sampling can miss brief peaks. These are whole-process measurements and estimated integration differences, not allocations attributed exclusively to SDK objects.

The first batch was excluded as warm-up for both variants after the initial Android baseline showed substantially different memory use from later launches. Every run in the subsequent three-pair batch is included; negative or noisy paired differences are retained.

Distribution-specific store download/installed size and long-duration memory-retention testing remain outside this benchmark. The app-file and SDK-artifact sizes above are measured, but do not substitute for those results.

## Dependencies

The Swift package and CocoaPods spec declare **zero external package/pod dependencies**. Two third-party source libraries are compiled into the SDK: SwiftPhoenixClient (Phoenix/WebSocket transport) and BlurHashDecode (image placeholders), both with MIT notices. Their version boundary is the SDK commit; no upstream version was inferred.

Foundation, UIKit, SwiftUI, Network, StoreKit, UserNotifications, SafariServices, WebKit, ImageIO, UniformTypeIdentifiers, and SQLite are system frameworks/libraries. They are not extra third-party package downloads.

Sources: [Package.swift](../Package.swift), [Userpilot.podspec](../Userpilot.podspec), [vendored code](../Sources/Userpilot/Vendor).

## Reproduce the build measurements

Run from the SDK repository root:

```sh
scripts/build-xcframework.sh --zip
```

The existing script builds device and simulator Release slices, verifies their module interfaces, and restores its temporary `Package.swift` change. The measured toolchain was Xcode 26.6 (17F113), iPhoneOS SDK 26.5. Directory totals sum regular file lengths; ZIP size is the file length. dSYMs and simulator slices are not part of the reference device app.

The reference host uses the dynamic arm64 framework, Release `-O`, and development signing. Its app bundle totals are local file sizes, not a thinned App Store installation estimate.

To estimate customer download/install impact, build the same host with and without Userpilot using matching distribution settings. Compare the same thinned device variant on iOS or the same bundletool device specification on Android. Shared dependencies must not be counted twice.

## Runtime benchmark contract

Use two Release variants of the same native host: one without the SDK linked, and one with the SDK initialized. Keep UI, timers, sampling, signing style, and build optimization comparable. Capture logs in a separate smoke run. No SDK callback or production flag is added for measurement.

The host does the following:

1. Display a static native screen and prevent auto-lock.
2. Initialize the SDK only in the SDK variant. Disable diagnostic logging, screen/interaction autocapture, and automatic notification permission requests.
3. At one second, identify the dedicated QA user `sdk_performance_benchmark` in the SDK variant.
4. At 30 seconds, submit 50 distinct `sdk_performance_event_<index>` calls, 50 ms apart, with an integer `index` property.
5. Sample process CPU and memory approximately once per second for 60 seconds. Run the same timer callbacks in the baseline.
6. Warm both variants with three alternating pairs, then record three new alternating baseline/SDK pairs. End the previous process before starting the next. Preserve settings caches after the separate warm-up; this is not a first-install benchmark.

| Window | Purpose |
| --- | --- |
| 0–20 seconds | Initialization/connection warm-up; excluded from idle figures. |
| 20–30 seconds | Connected idle. |
| 30–45 seconds | Event submission and processing. This is not automatically proof all ACKs completed. |
| 45–60 seconds | Subsequent activity and memory. |

Process CPU seconds from `getrusage(RUSAGE_SELF)`; physical footprint bytes from `task_info(TASK_VM_INFO).phys_footprint`.

For each window, calculate CPU utilization as `100 × Δprocess_cpu_seconds / Δelapsed_seconds`; 100% means one occupied core. Report the median and range across runs. Compute additional overhead from each matched pair, retaining the baseline and SDK totals. Label CPU percentage differences as percentage points. Do not clamp negative/noisy deltas to zero. Report memory averages and the sampled peak; one-second sampling can miss short peaks. Three pairs do not justify p95 claims.

Reject a run when the host is not foreground, thermal status is elevated, the process changes, samples are incomplete, or the workload cannot be verified. Confirm identify and 50 event acknowledgments separately before calling the workload connected/online. Network wait time is not CPU time.

## Recorded profiling evidence

A separate 65-second Instruments recording captured **769 CPU samples** plus heap/VM allocation statistics. The whole host retained **2,465,104 bytes of heap allocations** at the end of that diagnostic recording. Those include live app and SDK services and are not a leak count.

See profiling-summary.json (`benchmarks/results/2026-10-14/profiling-summary.json`). The diagnostic runs stayed foreground with nominal thermal status. Profiling overhead is excluded from the CPU/RAM tables. Raw traces stay outside version control; the iOS trace contains local device/launch metadata. These short traces do not establish long-term retention, complete teardown, or absence of memory leaks.

## Profiling beyond this first case

| Scenario | Required checks before publishing a result |
| --- | --- |
| Startup | First install versus warm settings; synchronous initialization versus async readiness. |
| Autocapture | Disabled/enabled; native UIKit/View, SwiftUI/Compose, and hybrid paths. Android instrumentation must actually be enabled. |
| Experience display and dismissal | Fixed assets; peak memory; UI removal; fake reload; retained objects after repetitions. |
| Offline replay | Fixed event/payload count; offline queue/storage growth; recovery and ACKs. |
| Logout and user switching | Queue cleanup, reconnection, and retained memory. |
| Background/resume | Record interval and session boundary, with no unrelated app activity. |
| Multi-instance | Fixed instance count and routing; check duplicated work before interpreting CPU. |

Use Instruments Time Profiler/CPU Profiler and Allocations on iOS, or Android Studio/Perfetto with a profileable Release app on Android. Java/Kotlin heap dumps and allocation tracking need a separate debuggable run. Keep profiler overhead separate from the low-overhead summary run. iOS physical footprint and Android PSS have different accounting rules and must not be directly ranked.

## Benchmark sources and remaining work

The benchmark harness (`benchmarks/harness/2026-10-14/README.md`) preserves the exact host source and runner for review/reproduction. It is a measurement fixture, not SDK runtime code or a general performance guarantee. The runner stops when the foreground or thermal checks fail. No failed-run CPU/RAM figures are included as accepted evidence.

The accepted raw samples and deterministic summary script (`benchmarks/harness/2026-10-14/summarize.py`) are preserved in the local benchmark archive. Re-run the benchmark after SDK/dependency changes; these results are pinned to the recorded commit. Full rendering, autocapture, offline replay and prolonged retention scenarios still need their own workloads.

## Official references

- [Apple app-size reports](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size)
- [Apple CPU profiling](https://developer.apple.com/videos/play/wwdc2025/308/)
- [Apple memory profiling](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
- [Android bundletool](https://developer.android.com/tools/bundletool)
- [Android profiling](https://developer.android.com/studio/profile)
- [Gradle dependency reports](https://docs.gradle.org/current/userguide/viewing_debugging_dependencies.html)

## Documentation verification

The hosted Mintlify build, KB manifest validation, redirect validation, and SEO audit completed successfully. The new page has no SEO warnings and is linked from Mobile navigation. Navigation still reports the same 18 pre-existing orphan pages; this page adds none. Local relative links, JSON evidence, runner Python syntax, and recorded artifact hashes were verified. This documentation work does not claim a new full SDK test-suite run.
