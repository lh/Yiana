# App Store Submission Checklist

This document outlines the steps to publish Yiana on the App Store. Complete TestFlight testing before proceeding.

---

## 1. Enable GitHub Pages Website

The website contains your privacy policy, support page, and marketing content.

1. Go to **https://github.com/lh/Yiana/settings/pages**
2. Under **Source**, select **Deploy from a branch**
3. Choose branch: **main** and folder: **/website**
4. Click **Save**
5. Wait a few minutes, then verify the site is live at: https://lh.github.io/Yiana/

### Website URLs

| Page | URL |
|------|-----|
| Home | https://lh.github.io/Yiana/ |
| Privacy Policy | https://lh.github.io/Yiana/privacy/ |
| Support | https://lh.github.io/Yiana/support/ |
| Getting Started | https://lh.github.io/Yiana/guide/ |

---

## 2. App Store Connect Setup

Go to [App Store Connect](https://appstoreconnect.apple.com) and select your app.

### App Information

- **Name:** Yiana
- **Subtitle:** (optional, up to 30 characters) e.g., "Document Scanner & Manager"
- **Primary Category:** Productivity
- **Secondary Category:** Business (optional)
- **Content Rights:** Declare you own or have rights to all content

### Pricing and Availability

- **Price:** Free (or choose a price tier)
- **Availability:** Select countries/regions

### App Privacy

In the **App Privacy** section, answer the questionnaire:

1. **Do you or your third-party partners collect data from this app?** → **No**
2. This will display "Data Not Collected" on your App Store listing

### Version Information

For your release version, provide:

#### Screenshots (Required)

You need screenshots for:
- **6.7" iPhone** (1290 x 2796 pixels) - iPhone 14/15/16 Pro Max
- **12.9" iPad Pro** (2048 x 2732 pixels) - 3rd gen or later

Optional but recommended:
- 6.5" iPhone (1242 x 2688 pixels)
- 11" iPad Pro

**Tip:** Use the Simulator to capture screenshots at the correct resolutions.

#### Description

```
Yiana is a simple, private document scanner for iPhone, iPad, and Mac.

SCAN & IMPORT
• Scan documents using your camera with automatic edge detection
• Import existing PDFs from your device or other apps
• Multi-page document support

ORGANISE
• Create folders to keep documents organised
• Search through document text to find what you need
• Quick access to recent documents

SYNC EVERYWHERE
• Automatic iCloud sync across all your Apple devices
• Start on iPhone, continue on iPad, review on Mac
• Works offline — syncs when you're back online

PRIVACY FIRST
• Your documents stay in your personal iCloud account
• We never see or access your data
• No analytics, no tracking, no ads

Yiana is designed for people who want a straightforward way to go paperless without compromising their privacy.
```

#### Keywords

```
scanner,document,pdf,scan,ocr,paperless,organise,icloud,notes,receipts
```

(100 characters max, comma-separated)

#### What's New

```
Initial release.
```

#### URLs

| Field | Value |
|-------|-------|
| Support URL | https://lh.github.io/Yiana/support/ |
| Marketing URL | https://lh.github.io/Yiana/ |
| Privacy Policy URL | https://lh.github.io/Yiana/privacy/ |

### Age Rating

Complete the questionnaire. For Yiana, answers should be "No" or "None" for all categories (no violence, gambling, mature content, etc.). This should result in a **4+** rating.

### Export Compliance

When asked about encryption:
- Yiana uses HTTPS (via iCloud) which uses encryption
- However, this qualifies for an **exemption** under Export Administration Regulations
- Select: "Yes, the app uses encryption but qualifies for an exemption"

---

## 3. Submit for Review

1. Ensure a build is uploaded and processed (visible in TestFlight)
2. Select the build for release
3. Fill in all required metadata
4. Click **Add for Review**
5. Submit

Apple typically reviews apps within 24-48 hours.

---

## 4. Post-Submission

### If Approved
- Choose to release manually or automatically
- Monitor for any user feedback via App Store reviews
- Check yiana@vitygas.com for support emails

### If Rejected
- Read the rejection reason carefully
- Make required changes
- Resubmit

Common rejection reasons:
- Missing privacy policy
- Incomplete metadata
- Crashes during review
- Guideline violations

---

## Quick Reference

| Item | Value |
|------|-------|
| Bundle ID | com.vitygas.Yiana |
| Team ID | GNC28XBQ2D |
| Support Email | yiana@vitygas.com |
| Privacy Policy | https://lh.github.io/Yiana/privacy/ |
| App Category | Productivity |
| Price | Free |
| Age Rating | 4+ |
