# DepthClockXI

Native iOS 12 lockscreen custom clock base tweak for iPhone 6 / iOS 12.5.x.

## What v0.1 does
- Loads into SpringBoard
- Hides likely stock lockscreen clock/date views
- Adds a custom native clock and date overlay
- Adds placeholder occlusion layer for the later depth/mask system

## Build with GitHub Actions
1. Upload this folder to a GitHub repo.
2. Go to **Actions**.
3. Run **Build DepthClockXI Deb and Repo**.
4. Download the artifact or use GitHub Pages as your Cydia repo.

## Repo generation only
Put `.deb` files inside:

```text
repo/debs/
```

Then run:

```bash
python3 scripts/create_packages.py repo
```

This creates:

```text
repo/Packages
repo/Packages.bz2
repo/Packages.gz
repo/Release
```

## Next step
After the base clock appears correctly, v0.2 should add real depth occlusion/masking logic.
