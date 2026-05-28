#!/usr/bin/env python3
"""Create Cydia/Sileo repo Packages files from .deb files.

Usage:
  python scripts/create_packages.py repo

Expected:
  repo/debs/*.deb

Creates:
  repo/Packages
  repo/Packages.bz2
  repo/Packages.gz
  repo/Release
"""
from __future__ import annotations

import bz2
import gzip
import hashlib
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def control_text(deb: Path) -> str:
    # dpkg-deb is available on GitHub Actions Ubuntu and on most local Linux setups.
    try:
        out = subprocess.check_output(['dpkg-deb', '-f', str(deb)], text=True, stderr=subprocess.STDOUT)
        return out.strip()
    except Exception:
        # Fallback: minimal stanza from filename. Better than creating a broken repo.
        name = deb.stem.replace('_iphoneos-arm', '')
        return f"Package: {name}\nName: {name}\nVersion: 0.0.0\nArchitecture: iphoneos-arm\nDescription: Package metadata unavailable. Install dpkg-deb to generate full metadata."


def build(repo_dir: Path) -> None:
    deb_dir = repo_dir / 'debs'
    if not deb_dir.exists():
        raise SystemExit(f'Missing folder: {deb_dir}')

    debs = sorted(deb_dir.glob('*.deb'))
    if not debs:
        raise SystemExit(f'No .deb files found in {deb_dir}')

    stanzas = []
    for deb in debs:
        rel = deb.relative_to(repo_dir).as_posix()
        size = deb.stat().st_size
        stanza = control_text(deb)
        stanza += f"\nFilename: {rel}\nSize: {size}\nMD5sum: {md5(deb)}\nSHA256: {sha256(deb)}"
        stanzas.append(stanza.strip())

    packages = ('\n\n'.join(stanzas) + '\n').encode('utf-8')
    (repo_dir / 'Packages').write_bytes(packages)
    (repo_dir / 'Packages.bz2').write_bytes(bz2.compress(packages, compresslevel=9))
    with gzip.open(repo_dir / 'Packages.gz', 'wb', compresslevel=9) as f:
        f.write(packages)

    release = f"""Origin: GlitchLord Repo
Label: GlitchLord Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: GlitchLord iOS tweaks repo
Date: {datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S %z')}
"""
    (repo_dir / 'Release').write_text(release, encoding='utf-8')
    print(f'Created Packages, Packages.bz2, Packages.gz and Release for {len(debs)} deb(s).')


if __name__ == '__main__':
    root = Path(sys.argv[1] if len(sys.argv) > 1 else 'repo').resolve()
    build(root)
