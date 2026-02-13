---
name: deploy
description: Deploys the OCR service to the Mac mini server (Devon). Use when user says "deploy", "push to server", "update the Mac mini", or wants to ship a new build to the production server.
---

# Deploy to Mac mini
1. SSH to the Mac mini server
2. Stop the launchd service: `launchctl unload ~/Library/LaunchAgents/com.yiana.ocr.plist`
3. Wait 3 seconds for process to fully stop
4. Copy the new binary to the server
5. Start the service: `launchctl load ~/Library/LaunchAgents/com.yiana.ocr.plist`
6. Verify: check process is running and tail the last 20 lines of the log
7. Report status to user — do NOT proceed without confirmation
