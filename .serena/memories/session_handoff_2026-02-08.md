# Session Handoff — 2026-02-08

## What We Accomplished

### Insights-Driven Improvements
- Added 7 new sections to CLAUDE.md from usage insights analysis: Bug Fix Protocol, Deployment, Code Navigation, Tool Usage Conventions, Style Preferences, expanded Project Overview, dual-platform build rule
- All committed and pushed

### Custom Skills Created
- `/deploy` — Mac mini server deployment protocol (.claude/skills/deploy/SKILL.md)
- `/testflight` — Build number bump, archive, upload to App Store Connect (.claude/skills/testflight/SKILL.md)
- `/check` — Build both iOS and macOS targets for verification (.claude/skills/check/SKILL.md)

### Hooks
- `postToolUse` on `TaskUpdate` — auto-builds both iOS and macOS when a task is marked completed (.claude/settings.json)
- Timed no-op builds: iOS ~27s, macOS ~8s — too slow per-edit, fine per-task

### Headless Health Check
- Created `~/scripts/server-health-check.sh` — runs Claude Code non-interactively to diagnose Mac mini issues
- First run immediately found the 14GB log problem

### Fixed: 14GB Runaway Error Log
- **Root cause:** swift-log's default StreamLogHandler writes ALL output to stderr. The `--logLevel` CLI option was declared but never wired up. Default was `info`, producing thousands of lines per scan with ~2900 documents.
- **Fix:** Bootstrapped `LoggingSystem` in `Watch.run()` with `StreamLogHandler.standardError`, default level `notice`. Commit: `30e78ce`
- **Also fixed:** Cleaned up Mercy-Duffy.yianazip (old format file, not ZIP). Deleted from phone, iCloud propagated instantly.

### Log Rotation
- Set up newsyslog at `/etc/newsyslog.d/yiana-ocr.conf` on Mac mini (10MB, 3 copies, bzip2, N flag)
- Rotated the 314MB stale stdout log
- Saved config in repo: `YianaOCRService/yiana-ocr.newsyslog.conf`

### Documentation Consolidation
- Replaced 4 fragmented docs (DEPLOYMENT.md, DEPLOYMENT-PERSONAL.md, LAUNCHDAEMON-SETUP.md, TROUBLESHOOTING.md) with single `YianaOCRService/SERVER-SETUP.md`
- Personal parameters in separate section with placeholders
- README.md kept as package-level quick reference

## What's Still Pending
- Open problems in Serena memory `ideas_and_problems`: sandbox extension batching (#1), iOS address display (#3)
- Ideas: sort by last accessed, info panel UX, keyboard shortcuts, @Observable migration

## What We Tried That Didn't Work
- Per-edit Xcode build hooks: 27s+ per build is too disruptive. Solved with per-task-completion hook instead.
- `sudo` over non-interactive SSH: not possible without password. Gave user commands to paste manually.

## Server State After Session
- Disk: 87% (was 94%), 28GB free (was 14GB)
- OCR service: running PID 98230, log level notice, error log 483 bytes
- newsyslog rotation active
- All commits pushed to main through `3e45f3b`
