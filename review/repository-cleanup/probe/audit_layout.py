from pathlib import Path
import subprocess,json,hashlib,re
R=Path('/workspace/pokemon-deckbuilder')
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
archive='origin/development-materials';m=json.loads(git('show',archive+':docs/branch-archive.json'))
for b in m['branches']:
 assert subprocess.run(['git','merge-base','--is-ancestor',b['commit'],archive],cwd=R).returncode==0
 for f in b['material_files']:
  assert hashlib.sha256(git('show',archive+':'+f['path'])).hexdigest()==f['archived_sha256'],f['path']
  assert hashlib.sha256(git('show',b['commit']+':'+f['original_path'])).hexdigest()==f['sha256'],f['original_path']
files=[p for p in git('ls-files','-z').decode().split('\0') if p and (R/p).exists()]
missing=[];count=0
for name in files:
 p=R/name
 if p.suffix not in ['.gd','.tscn','.godot','.json']:continue
 for match in re.findall(r'res://([^\"\'\s]+)',p.read_text()):
  if any(ch in match for ch in ['%','{']):continue
  if not match:continue
  count+=1
  if not (R/match).exists():missing.append((name,match))
assert not missing,missing
for folder in ['docs','tests','tools','review']:
 assert not (R/folder).exists(),folder
for name in ['AGENTS.md','HANDOFF.md','assets/sources/csv','scenes/art_lab.tscn','scenes/battle_preview.tscn']:
 assert not (R/name).exists(),name
for p in (R/'data').glob('*.json'):assert p.read_bytes()==git('show','origin/main:'+str(p.relative_to(R))),str(p)
assets=[p for p in files if p.startswith('assets/') and Path(p).suffix in ['.png','.svg','.ogg','.wav','.ttf']]
for p in assets:assert (R/p).read_bytes()==git('show','origin/main:'+p),p
assert hashlib.sha256((R/'data/battlefield_layouts.json').read_bytes()).hexdigest()=='b0f2e796afbb02eb04bef728ae28cfd113b1b8a8d6939911d5d0371ba89724f3'
license=git('show','origin/main:assets/sources/SMOGON_SPRITES_README.md').decode().split('## License\n',1)[1]
assert (R/'assets/sources/SMOGON_SPRITES_LICENSE.txt').read_text().endswith(license)
report={'old_review_branches_preserved':len(m['branches']),'archived_material_files_verified':sum(len(b['material_files']) for b in m['branches']),'literal_runtime_paths_checked':count,'unchanged_runtime_assets':len(assets),'unchanged_data_files':len(list((R/'data').glob('*.json'))),'main_file_count':len(files)+1,'top_level':sorted(set(p.split('/')[0] for p in files))}
Path('/workspace/.repo-cleanup/layout-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
