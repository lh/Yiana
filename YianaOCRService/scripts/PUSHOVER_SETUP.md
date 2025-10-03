# Pushover Monitoring Setup for Mac Mini

## 1. Get Pushover Credentials

1. Sign up at https://pushover.net/
2. Install Pushover app on your phone
3. From your Pushover dashboard:
   - Copy your **User Key** (top right)
   - Create a new Application/API Token:
     - Name: "Yiana OCR"
     - Copy the **API Token**

## 2. Deploy to Mac Mini

```bash
# From your development Mac:

# Copy the watchdog script
scp /Users/rose/Code/Yiana/YianaOCRService/scripts/ocr_watchdog_pushover.sh devon@Devon-6.local:~/ocr_watchdog.sh

# Make it executable
ssh devon@Devon-6.local "chmod +x ~/ocr_watchdog.sh"
```

## 3. Configure Pushover Credentials on Mac Mini

SSH into Mac mini and add credentials to your shell profile:

```bash
ssh devon@Devon-6.local

# Add to ~/.zshrc or ~/.bash_profile
echo 'export PUSHOVER_USER="your-user-key-here"' >> ~/.zshrc
echo 'export PUSHOVER_TOKEN="your-api-token-here"' >> ~/.zshrc

# Or for bash:
echo 'export PUSHOVER_USER="your-user-key-here"' >> ~/.bash_profile
echo 'export PUSHOVER_TOKEN="your-api-token-here"' >> ~/.bash_profile

# Reload
source ~/.zshrc  # or source ~/.bash_profile
```

## 4. Test the Watchdog

```bash
# Test it manually first
~/ocr_watchdog.sh

# You should see: "✅ OK - heartbeat age Xs"
# Check your phone for a test notification
```

## 5. Setup Cron Job

Add to crontab to run every 5 minutes:

```bash
# Edit crontab
env EDITOR=nano crontab -e

# Add this line (update paths to match your setup):
PUSHOVER_USER=your-user-key-here
PUSHOVER_TOKEN=your-api-token-here
*/5 * * * * $HOME/ocr_watchdog.sh --max-age-seconds 600 >> $HOME/ocr_watchdog.log 2>&1
```

**Note:** The cron job includes credentials directly because cron doesn't inherit shell environment variables.

## 6. Monitor Logs

```bash
# Check watchdog logs
tail -f ~/ocr_watchdog.log
```

## What You'll Get

- **Normal operation:** No notifications, silent monitoring
- **Service stalled:** High-priority push notification to your phone
- **Recent errors:** Normal priority notification with error details
- **Service not running:** High-priority notification

## Priority Levels

- **0 (Normal):** Recent errors, informational
- **1 (High):** Service stalled, needs attention (bypasses quiet hours)
- **2 (Emergency):** Not used yet (requires acknowledgment, repeats every 5 minutes)

## Troubleshooting

1. **Not receiving notifications?**
   - Check credentials: `echo $PUSHOVER_USER`
   - Test manually: `curl -s --form-string "token=YOUR_TOKEN" --form-string "user=YOUR_USER" --form-string "message=Test" https://api.pushover.net/1/messages.json`

2. **Cron not working?**
   - Check logs: `tail ~/ocr_watchdog.log`
   - Verify cron is running: `crontab -l`
   - Make sure paths are absolute in crontab

3. **False alarms?**
   - Increase `--max-age-seconds` if processing large documents takes longer
   - Default is 600 seconds (10 minutes)
