# Yiana Website

Public website for Yiana, hosted on GitHub Pages.

## Setup GitHub Pages

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Pages**
3. Under "Source", select **Deploy from a branch**
4. Select branch: `main` and folder: `/website`
5. Click **Save**

The site will be available at: `https://lh.github.io/Yiana/`

## Local Development (Optional)

To preview the site locally:

```bash
cd website
bundle install
bundle exec jekyll serve
```

Then open http://localhost:4000/Yiana/

## Structure

- `index.md` - Home page
- `guide.md` - Getting started guide
- `privacy.md` - Privacy policy (required for App Store)
- `support.md` - FAQ and contact info
- `_config.yml` - Jekyll configuration

## Updating

Edit the markdown files and commit. GitHub Pages will automatically rebuild the site.

## URLs for App Store Connect

- **Privacy Policy:** https://lh.github.io/Yiana/privacy/
- **Support:** https://lh.github.io/Yiana/support/
- **Marketing:** https://lh.github.io/Yiana/
