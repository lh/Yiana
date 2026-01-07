---
layout: page
title: Your Data
permalink: /your-data/
---

# Your Documents Are Always Yours

Yiana is designed with **no vendor lock-in**. Your documents are stored in a simple, open format that you can access anytime — with or without Yiana.

## The .yianazip Format

Yiana documents use the `.yianazip` format. Despite the custom extension, it's just a **standard ZIP file** containing:

```
document.yianazip
├── content.pdf      ← Your actual PDF
└── metadata.json    ← Title, dates, tags (plain text)
```

## How to Extract Your PDF

If you ever need to access your documents outside of Yiana, it takes just a few seconds:

### On Mac

1. Find your document in **Finder** (iCloud Drive → Yiana)
2. **Right-click** the `.yianazip` file
3. Select **Rename** and change the extension from `.yianazip` to `.zip`
4. **Double-click** the `.zip` file to extract
5. Open the folder and find your **`content.pdf`**

### On iPhone/iPad

1. Open the **Files** app
2. Navigate to iCloud Drive → Yiana
3. **Long-press** the `.yianazip` file
4. Tap **Rename** and change `.yianazip` to `.zip`
5. Tap the `.zip` file to extract
6. Open the extracted folder to find **`content.pdf`**

### On Windows

1. Find your document in File Explorer (iCloud Drive → Yiana)
2. **Right-click** the `.yianazip` file
3. Select **Rename** and change the extension to `.zip`
4. **Right-click** the `.zip` file and select **Extract All**
5. Find your **`content.pdf`** in the extracted folder

## Where Are My Documents Stored?

All your documents are stored in your personal iCloud Drive:

```
iCloud Drive
└── Yiana
    ├── Document 1.yianazip
    ├── Document 2.yianazip
    └── My Folder
        └── Document 3.yianazip
```

You can browse this folder anytime using the Files app (iOS/iPadOS) or Finder (Mac).

## Bulk Export

Yiana also includes a bulk export feature (Mac only) that lets you export all your documents as standard PDFs at once:

1. Open Yiana on your Mac
2. Go to **File → Export All Documents as PDFs**
3. Choose a destination folder
4. All documents will be exported as regular PDF files

## What If Yiana Disappears?

We hope you'll use Yiana for years to come. But if the app ever becomes unavailable — whether we stop development, Apple changes their policies, or you simply decide to move on — **your documents remain fully accessible**.

Everything you need is already on your device:

- Your PDFs are in standard ZIP files in your iCloud Drive
- No server connection required to access them
- No account to log into
- No subscription to maintain

Just rename, extract, and your PDFs are there. Always.

## Optional: Advanced Features

Yiana works great on its own, but power users can extend it with optional components:

### Mac App

Yiana for Mac is available on the Mac App Store, giving you the same document management experience on your desktop. Your documents sync seamlessly between all your devices via iCloud.

### OCR Processing Backend

For users who want searchable text in their scanned documents, we offer an open-source backend service that runs on your own Mac. It:

- Processes documents entirely on your hardware
- Adds searchable text to your scans
- Runs automatically in the background
- Keeps everything private — no cloud processing

### Address Extraction

An optional open-source tool can extract address information from your documents into a local database. Useful for medical practices, legal offices, or anyone who regularly processes correspondence.

Both backend components are available as open-source projects for technically-minded users who want to self-host these capabilities.

## Our Promise

- **No lock-in** — Your PDFs are always accessible, with or without Yiana
- **Standard formats** — ZIP and PDF, nothing proprietary
- **Your iCloud** — We never have access to your files
- **Export anytime** — Bulk export to standard PDFs whenever you want
- **Future-proof** — Your data survives even if the app doesn't

We believe your documents belong to you, and you should never be trapped by the software you use.
