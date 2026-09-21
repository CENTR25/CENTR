# Deploy

Production web app: **https://prgs.pages.dev** (Cloudflare Pages, project `prgs`).

## How it deploys
- The Pages project is **git-connected to `CENTR25/CENTR`** with **automatic deployments on `main`**.
  Every push to `main` triggers a Cloudflare build — no manual step needed.
- The Pages project lives on the **client's Cloudflare account** ("Alangabrielepelbau…"),
  not Xavier's. So `wrangler pages deploy` from Xavier's CLI can't target it; deploys go
  through the git integration (or the client's own dashboard / API token).

## Pages build configuration (Settings → Build)
- **Framework preset:** None
- **Build command:**
  ```
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter && export PATH="$HOME/flutter/bin:$PATH" && flutter build web --release
  ```
  (Cloudflare's build image has no Flutter, so we clone the SDK, put it on PATH, then build.)
- **Build output directory:** `build/web`
- **Root directory:** empty (`/`)
- **Build system version:** 3
- First build ~5–10 min (downloads the Flutter SDK). Build cache is off; fine to leave off.
- If a build fails on the Dart SDK version, pin Flutter: change `-b stable` to a tag, e.g. `-b 3.35.0`
  (pubspec needs `sdk: ^3.9.0`).

## SPA routing
- `web/_redirects` (`/* /index.html 200`) makes client-side routes fall back to `index.html`.
  Flutter copies `web/` into `build/web` on build.

## After a deploy
- Users on the PWA must fully close & reopen the app once to drop the old cached service-worker bundle.
- Verify live == build: `curl -s https://prgs.pages.dev/main.dart.js | md5` should match
  `md5 build/web/main.dart.js` after a local `flutter build web --release`.

## Old target (deprecated / removed)
- `centr.xavierbenavidesm.workers.dev` (Workers Assets, `wrangler.jsonc`) was the previous host on
  Xavier's account, deployed by the `.github/workflows/deploy-web.yml` Action (`wrangler deploy`).
  Superseded by `prgs.pages.dev`. That Action was **removed** because it deployed to the deprecated
  Worker AND failed on `web/_redirects`: Workers Assets rejects `/* /index.html 200` as an infinite
  loop, while Pages requires it for SPA deep-links (e.g. `/login`). `wrangler.jsonc` is kept only so a
  manual `wrangler deploy` still works if ever needed.
