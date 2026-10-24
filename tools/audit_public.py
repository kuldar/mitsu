#!/usr/bin/env python3
"""Heuristic source/asset audit. Reports locations, never matching secret values."""
from pathlib import Path
import argparse,re,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
SKIP={'build','DerivedData','.git','.venv','__pycache__'}
BANNED_DIRS={'logs','reports','captures','private','Diagnostics','xcuserdata','assets/source'}
BANNED_EXT={'.p12','.p8','.pem','.key','.mobileprovision','.provisionprofile','.ipa','.xcuserstate','.exe','.dll','.exdf','.jsonl','.usdz'}
PATTERNS={
 'absolute user-home path':re.compile(rb'/Users/[A-Za-z0-9_.-]+/'),
 'personal Apple signing team':re.compile(rb'DEVELOPMENT_TEAM\s*(?:=|:)\s*["\']?[A-Z0-9]{10}'),
 'Apple device identifier':re.compile(rb'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b'),
 'private key':re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
 'provider credential':re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,})'),
 'assigned token/secret':re.compile(rb'(?:access_token|refresh_token|client_secret|api_key)["\']?\s*[:=]\s*["\'][A-Za-z0-9_./+\-=]{20,}["\']',re.I),
}
def audit(root=ROOT,release=False):
 issues=[]
 for p in sorted(root.rglob('*')):
  rel=p.relative_to(root);parts=set(rel.parts)
  if parts&SKIP:
   if release and p.is_dir() and p.parent==root and p.name in ['build','DerivedData','.venv']:issues.append((str(rel),'generated directory in release'))
   continue
  if p.is_symlink():issues.append((str(rel),'symlink not allowed in source release'));continue
  if not p.is_file():continue
  if parts&BANNED_DIRS or rel.parts[:2]==('assets','source') or p.suffix.lower() in BANNED_EXT or '.local.' in p.name or (p.name.startswith('.env') and p.name!='.env.example'):
   issues.append((str(rel),'local/private/restricted artifact'));continue
  data=p.read_bytes()
  for name,pattern in PATTERNS.items():
   if pattern.search(data):issues.append((str(rel),name))
  if zipfile.is_zipfile(p):issues.append((str(rel),'unexpected nested archive'))
 return issues
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--release',action='store_true',help='Also reject generated top-level output folders')
 args=parser.parse_args();issues=audit(release=args.release)
 for path,kind in issues:print(f'{path}: {kind}')
 print(f'Public source audit: {len(issues)} finding(s). Heuristic only; inspect staged files and binary metadata too.')
 sys.exit(bool(issues))
