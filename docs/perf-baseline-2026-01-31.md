# Performance Baseline — 2026-01-31

## Test conditions
- iPad with ~110 documents syncing via iCloud
- All documents deleted then re-added on Mac, iPad observed during sync
- Measured with SyncPerfLog instrumentation on `main` branch (pre-ValueObservation refactor)
- Note: `downloadState()` and placeholder counters read 0 due to a fileExists bug
  that was preventing iCloud placeholders from appearing (fixed in same session)

## Baseline log: perflog_2026-01-31_115920.txt (7-minute sync)

```
# SyncPerfLog — 2026-01-31 11:59:20 +0000

[PerfLog] Started
[PerfLog] 5s elapsed
  notifications received:  3
  refresh() calls:         3
  loadDocuments() calls:   3  avg 128.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 10s elapsed
  notifications received:  6
  refresh() calls:         6
  loadDocuments() calls:   6  avg 114.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 15s elapsed
  notifications received:  8
  refresh() calls:         8
  loadDocuments() calls:   8  avg 109.8ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 20s elapsed
  notifications received:  10
  refresh() calls:         10
  loadDocuments() calls:   10  avg 101.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 25s elapsed
  notifications received:  13
  refresh() calls:         13
  loadDocuments() calls:   13  avg 97.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 30s elapsed
  notifications received:  18
  refresh() calls:         18
  loadDocuments() calls:   18  avg 90.5ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 35s elapsed
  notifications received:  22
  refresh() calls:         22
  loadDocuments() calls:   22  avg 84.9ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 40s elapsed
  notifications received:  25
  refresh() calls:         25
  loadDocuments() calls:   25  avg 83.0ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 45s elapsed
  notifications received:  27
  refresh() calls:         27
  loadDocuments() calls:   27  avg 81.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 50s elapsed
  notifications received:  30
  refresh() calls:         30
  loadDocuments() calls:   30  avg 79.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 55s elapsed
  notifications received:  33
  refresh() calls:         33
  loadDocuments() calls:   33  avg 78.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 60s elapsed
  notifications received:  36
  refresh() calls:         36
  loadDocuments() calls:   36  avg 77.7ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 65s elapsed
  notifications received:  38
  refresh() calls:         38
  loadDocuments() calls:   38  avg 77.4ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 70s elapsed
  notifications received:  40
  refresh() calls:         40
  loadDocuments() calls:   40  avg 76.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 75s elapsed
  notifications received:  42
  refresh() calls:         42
  loadDocuments() calls:   42  avg 75.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 80s elapsed
  notifications received:  44
  refresh() calls:         44
  loadDocuments() calls:   44  avg 74.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 85s elapsed
  notifications received:  46
  refresh() calls:         46
  loadDocuments() calls:   46  avg 73.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 90s elapsed
  notifications received:  48
  refresh() calls:         48
  loadDocuments() calls:   48  avg 73.0ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 95s elapsed
  notifications received:  50
  refresh() calls:         50
  loadDocuments() calls:   50  avg 72.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 100s elapsed
  notifications received:  52
  refresh() calls:         52
  loadDocuments() calls:   52  avg 72.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 105s elapsed
  notifications received:  54
  refresh() calls:         54
  loadDocuments() calls:   54  avg 72.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 110s elapsed
  notifications received:  56
  refresh() calls:         56
  loadDocuments() calls:   56  avg 71.6ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 115s elapsed
  notifications received:  58
  refresh() calls:         58
  loadDocuments() calls:   58  avg 71.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 120s elapsed
  notifications received:  60
  refresh() calls:         60
  loadDocuments() calls:   60  avg 71.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 125s elapsed
  notifications received:  62
  refresh() calls:         62
  loadDocuments() calls:   62  avg 71.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 130s elapsed
  notifications received:  64
  refresh() calls:         64
  loadDocuments() calls:   64  avg 71.0ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 135s elapsed
  notifications received:  66
  refresh() calls:         66
  loadDocuments() calls:   66  avg 70.8ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 140s elapsed
  notifications received:  68
  refresh() calls:         68
  loadDocuments() calls:   68  avg 70.6ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 145s elapsed
  notifications received:  70
  refresh() calls:         70
  loadDocuments() calls:   70  avg 70.5ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 150s elapsed
  notifications received:  72
  refresh() calls:         72
  loadDocuments() calls:   72  avg 70.4ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 155s elapsed
  notifications received:  74
  refresh() calls:         74
  loadDocuments() calls:   74  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 160s elapsed
  notifications received:  76
  refresh() calls:         76
  loadDocuments() calls:   76  avg 70.4ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 165s elapsed
  notifications received:  78
  refresh() calls:         78
  loadDocuments() calls:   78  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 170s elapsed
  notifications received:  80
  refresh() calls:         80
  loadDocuments() calls:   80  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 175s elapsed
  notifications received:  82
  refresh() calls:         82
  loadDocuments() calls:   82  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 180s elapsed
  notifications received:  84
  refresh() calls:         84
  loadDocuments() calls:   84  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 185s elapsed
  notifications received:  85
  refresh() calls:         85
  loadDocuments() calls:   85  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 190s elapsed
  notifications received:  87
  refresh() calls:         87
  loadDocuments() calls:   87  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 195s elapsed
  notifications received:  88
  refresh() calls:         88
  loadDocuments() calls:   88  avg 70.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 200s elapsed
  notifications received:  90
  refresh() calls:         90
  loadDocuments() calls:   90  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 205s elapsed
  notifications received:  91
  refresh() calls:         91
  loadDocuments() calls:   91  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 210s elapsed
  notifications received:  92
  refresh() calls:         92
  loadDocuments() calls:   92  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 215s elapsed
  notifications received:  93
  refresh() calls:         93
  loadDocuments() calls:   93  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 220s elapsed
  notifications received:  94
  refresh() calls:         94
  loadDocuments() calls:   94  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 225s elapsed
  notifications received:  95
  refresh() calls:         95
  loadDocuments() calls:   95  avg 70.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 230s elapsed
  notifications received:  96
  refresh() calls:         96
  loadDocuments() calls:   96  avg 70.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 235s elapsed
  notifications received:  97
  refresh() calls:         97
  loadDocuments() calls:   97  avg 70.1ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 240s elapsed
  notifications received:  98
  refresh() calls:         98
  loadDocuments() calls:   98  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 245s elapsed
  notifications received:  99
  refresh() calls:         99
  loadDocuments() calls:   99  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 250s elapsed
  notifications received:  100
  refresh() calls:         100
  loadDocuments() calls:   100  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 255s elapsed
  notifications received:  101
  refresh() calls:         101
  loadDocuments() calls:   101  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 260s elapsed
  notifications received:  102
  refresh() calls:         102
  loadDocuments() calls:   102  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 265s elapsed
  notifications received:  103
  refresh() calls:         103
  loadDocuments() calls:   103  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 270s elapsed
  notifications received:  104
  refresh() calls:         104
  loadDocuments() calls:   104  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 275s elapsed
  notifications received:  105
  refresh() calls:         105
  loadDocuments() calls:   105  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 280s elapsed
  notifications received:  105
  refresh() calls:         105
  loadDocuments() calls:   105  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 285s elapsed
  notifications received:  106
  refresh() calls:         106
  loadDocuments() calls:   106  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 290s elapsed
  notifications received:  106
  refresh() calls:         106
  loadDocuments() calls:   106  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 295s elapsed
  notifications received:  107
  refresh() calls:         107
  loadDocuments() calls:   107  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 300s elapsed
  notifications received:  107
  refresh() calls:         107
  loadDocuments() calls:   107  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 305s elapsed
  notifications received:  108
  refresh() calls:         108
  loadDocuments() calls:   108  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 310s elapsed
  notifications received:  108
  refresh() calls:         108
  loadDocuments() calls:   108  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 315s elapsed
  notifications received:  109
  refresh() calls:         109
  loadDocuments() calls:   109  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 320s elapsed
  notifications received:  109
  refresh() calls:         109
  loadDocuments() calls:   109  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 325s elapsed
  notifications received:  110
  refresh() calls:         110
  loadDocuments() calls:   110  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 330s elapsed
  notifications received:  110
  refresh() calls:         110
  loadDocuments() calls:   110  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 335s elapsed
  notifications received:  111
  refresh() calls:         111
  loadDocuments() calls:   111  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 340s elapsed
  notifications received:  111
  refresh() calls:         111
  loadDocuments() calls:   111  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 345s elapsed
  notifications received:  112
  refresh() calls:         112
  loadDocuments() calls:   112  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 350s elapsed
  notifications received:  112
  refresh() calls:         112
  loadDocuments() calls:   112  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 355s elapsed
  notifications received:  112
  refresh() calls:         112
  loadDocuments() calls:   112  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 360s elapsed
  notifications received:  113
  refresh() calls:         113
  loadDocuments() calls:   113  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 365s elapsed
  notifications received:  113
  refresh() calls:         113
  loadDocuments() calls:   113  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 370s elapsed
  notifications received:  113
  refresh() calls:         113
  loadDocuments() calls:   113  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 375s elapsed
  notifications received:  113
  refresh() calls:         113
  loadDocuments() calls:   113  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 380s elapsed
  notifications received:  114
  refresh() calls:         114
  loadDocuments() calls:   114  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 385s elapsed
  notifications received:  114
  refresh() calls:         114
  loadDocuments() calls:   114  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 390s elapsed
  notifications received:  114
  refresh() calls:         114
  loadDocuments() calls:   114  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 395s elapsed
  notifications received:  114
  refresh() calls:         114
  loadDocuments() calls:   114  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 400s elapsed
  notifications received:  114
  refresh() calls:         114
  loadDocuments() calls:   114  avg 70.2ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 405s elapsed
  notifications received:  115
  refresh() calls:         115
  loadDocuments() calls:   115  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 410s elapsed
  notifications received:  115
  refresh() calls:         115
  loadDocuments() calls:   115  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 415s elapsed
  notifications received:  115
  refresh() calls:         115
  loadDocuments() calls:   115  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] 420s elapsed
  notifications received:  115
  refresh() calls:         115
  loadDocuments() calls:   115  avg 70.3ms
  observation callbacks:   0
  downloadState() checks:  0
  placeholder batches:     0
[PerfLog] Stopped
```

## Summary

| Metric | Value |
|---|---|
| Duration | ~420 seconds (7 minutes) |
| Notifications received | 115 |
| refresh() calls | 115 (1:1 with notifications, no throttling) |
| loadDocuments() calls | 115, avg 70.3ms each |
| Total main-thread DB query time | ~8.1 seconds |
| observation callbacks | 0 (not yet implemented) |
| downloadState() checks | 0 (fileExists bug prevented rows from rendering) |
| placeholder batches | 0 (fileExists bug prevented discovery) |

### Key observations
- Every notification triggers a full reload (no coalescing or throttling)
- Each loadDocuments() call takes ~70ms on main thread
- Notifications arrive steadily (~2/5s) for first 3 minutes, then taper to ~1/10s
- The fileExists bug meant no documents actually appeared in the list, so
  downloadState() was never called (would have been ~115 * N_visible_rows otherwise)
