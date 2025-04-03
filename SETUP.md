# Setup Instructions for TIL Hugo Blog

This document provides instructions for setting up this blog locally and deploying it to GitHub Pages.

## Local Setup

1. Install Hugo (extended version)
   ```bash
   # macOS with Homebrew
   brew install hugo
   
   # Windows with Chocolatey
   choco install hugo-extended
   
   # Linux
   snap install hugo --channel=extended
   ```

2. Clone this repository
   ```bash
   git clone https://github.com/l4l4dev/TIL.git
   cd TIL
   ```

3. Install the theme
   ```bash
   mkdir -p themes
   git clone https://github.com/nanxiaobei/hugo-paper themes/paper
   ```

4. Start the local development server
   ```bash
   hugo server -D
   ```

5. View your site at http://localhost:1313/TIL/

## Creating New Content

Create a new blog post:
```bash
hugo new posts/my-new-post.md
```

Edit the newly created file in `content/posts/my-new-post.md`.

## Deployment to GitHub Pages

To deploy this site to GitHub Pages, you'll need to set up GitHub Actions.

1. In your GitHub repository, go to Settings > Pages
2. Set the source to "GitHub Actions"

3. Create a `.github/workflows/hugo.yml` file with the following content:

```yaml
name: Deploy Hugo site to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

defaults:
  run:
    shell: bash

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      HUGO_VERSION: 0.123.6
    steps:
      - name: Install Hugo CLI
        run: |
          wget -O ${{ runner.temp }}/hugo.deb https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
          && sudo dpkg -i ${{ runner.temp }}/hugo.deb
      
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Setup Pages
        id: pages
        uses: actions/configure-pages@v4
      
      - name: Install Theme
        run: |
          mkdir -p themes
          git clone https://github.com/nanxiaobei/hugo-paper themes/paper
      
      - name: Build with Hugo
        env:
          HUGO_ENVIRONMENT: production
          HUGO_ENV: production
        run: |
          hugo \
            --gc \
            --minify \
            --baseURL "${{ steps.pages.outputs.base_url }}/"
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: ./public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v3
```

4. Commit and push this file to your repository. GitHub Actions will automatically build and deploy your site.

## Additional Configuration

Edit the `hugo.toml` file to customize your site's title, theme, and other settings.

## Integrating with l4l4dev.github.io

To integrate this TIL blog with your main portfolio site at l4l4dev.github.io:

1. In your main site's menu configuration, add a link to this TIL blog:
   ```toml
   # In your main site's hugo.toml or config file
   [[menu.main]]
   name = "TIL Blog"
   url = "https://l4l4dev.github.io/TIL/"
   weight = 4
   ```

2. This will add a navigation link to your TIL blog from your main portfolio site.
