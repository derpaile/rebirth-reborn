#!/usr/bin/env python3
"""Check the exact Git index before publishing; CI checks the checked-out index.
Only the standalone remake, documentation and project-created artwork may ship.
"""
from pathlib import Path
import re,subprocess,sys,hashlib
root=Path(__file__).resolve().parents[1]
names=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
files=[name for name in names if name]
if not files:raise SystemExit('FAIL: no staged/tracked publication files')
root_files={'README.md','README.de.md','LICENSE','CONTRIBUTING.md','.gitignore'}
assets={'docs/assets/rack.png'}
blocked={'.iso','.dll','.exe','.dmg','.rbm','.rbs','.dat','.aif','.aiff','.wav','.f32','.i16','.gpr','.inc','.zip'}
for name in files:
    p=Path(name)
    allowed=(name in root_files or name in assets or name in {'docs/soundpacks.md','scripts/audit-public.py','.github/workflows/build.yml'} or name=='RebirthReborn/Package.swift' or name=='RebirthReborn/build-app.sh' or (name.startswith('RebirthReborn/Sources/') and p.suffix in {'.swift','.cpp','.hpp','.h'}))
    if not allowed or p.suffix.lower() in blocked or any(part in {'.build','dist','Resources','investigation','NativeRebirth'} for part in p.parts):raise SystemExit('FAIL: excluded path '+name)
    data=subprocess.check_output(['git','show',':'+name],cwd=root)
    if len(data)>4*1024*1024:raise SystemExit('FAIL: unexpected large file '+name)
    if name not in assets:
        try:text=data.decode('utf-8')
        except UnicodeDecodeError:raise SystemExit('FAIL: unexpected binary '+name)
        if re.search(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)',text):raise SystemExit('FAIL: credential-like content '+name)
        if re.search(r'/Users/[A-Za-z0-9_.-]+/',text):raise SystemExit('FAIL: personal absolute path '+name)
        if name.startswith('RebirthReborn/') and any(marker in text for marker in ['Recovered303.inc','Original303Coefficients.inc','OriginalWaveshaper.inc','OriginalPCFCoefficients.inc','ModData.dat','Ghidra','fVar27','DAT_101']):raise SystemExit('FAIL: recovered/extracted dependency '+name)
    elif name.endswith('.png') and not data.startswith(b'\x89PNG\r\n\x1a\n'):raise SystemExit('FAIL: invalid project preview')
# Ensure staged project artwork is not a byte-copy of a local original asset.
original=root/'NativeRebirth/Sources/RebirthApp/Resources/OriginalUI'
if original.exists():
    hashes={hashlib.sha256(p.read_bytes()).digest() for p in original.rglob('*') if p.is_file()}
    for name in assets & set(files):
        data=subprocess.check_output(['git','show',':'+name],cwd=root)
        if hashlib.sha256(data).digest() in hashes:raise SystemExit('FAIL: original artwork '+name)
print(f'PASS: {len(files)} indexed files; only remake source, docs and own artwork; no original assets, extracted tables, builds or credentials.')
