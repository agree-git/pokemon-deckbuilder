from pathlib import Path
import json,csv,shutil,hashlib,subprocess,html,zipfile,re,ast
from PIL import Image,ImageDraw,ImageFont
import argparse
parser=argparse.ArgumentParser();parser.add_argument('--project-dir',type=Path,required=True);parser.add_argument('--capture-dir',type=Path,required=True);parser.add_argument('--output-dir',type=Path,required=True);parser.add_argument('--capture-commit',default='');args=parser.parse_args()
R=args.project_dir.resolve();D=args.capture_dir.resolve().parent;P=args.output_dir.resolve();P.mkdir(parents=True,exist_ok=True);(P/'screenshots').mkdir(exist_ok=True)
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();capture_commit=args.capture_commit or commit;c={p['id']:p for p in json.loads((R/'data/catalog.json').read_text())['pokemon']};stories=json.loads((R/'data/rare_stories.json').read_text());script=(R/'scripts/tactics/rare_encounter.gd').read_text()
def const(name):return ast.literal_eval(re.search(r'^const '+name+r' := (\[.*\])$',script,re.M).group(1))
ids=const('IDS');sup=const('SUPER_LEGENDARY');effects=[i for i in sup if i not in [789,790]];myth=const('MYTHICAL');manifest=json.loads((args.capture_dir/'manifest.json').read_text());assert len(manifest)==65,len(manifest)
for row in manifest:
 src=args.capture_dir/row['file'];im=Image.open(src);assert im.size==(1920,1080);shutil.copy2(src,P/'screenshots'/row['file']);row['sha256']=hashlib.sha256(src.read_bytes()).hexdigest();row['width']=1920;row['height']=1080;row['file']='screenshots/'+row['file']
with (P/'rare_roster.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f,lineterminator="\n");w.writerow(['runtime_id','dex_id','name','generation','region','tier','types','site','clues','balls','energy','hp_percent','unique_entrance'])
 for i in ids:
  tier='초전설' if i in sup else '환상' if i in myth else '준전설';n=7 if i in sup else 5 if i in myth else 3
  w.writerow([i,c[i].get('dex_id',i),c[i]['name'],c[i]['generation'],c[i]['region'],tier,'/'.join(c[i]['types']),stories[str(i)]['site'],n,5 if i in sup else 3,3 if i in sup else 2,10,'yes' if i in effects else 'no'])
with (P/'clues.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f,lineterminator="\n");w.writerow(['runtime_id','name','step','text'])
 for i in ids:
  for n,line in enumerate(stories[str(i)]['clues'],1):w.writerow([i,c[i]['name'],n,line])
font=ImageFont.truetype(str(R/'assets/fonts/NotoSansKR.ttf'),21);contact=Image.new('RGB',(1800,1350),'#14282f');draw=ImageDraw.Draw(contact)
for n,i in enumerate(effects):
 im=Image.open(P/'screenshots'/f'{i}-reveal.png').crop((1100,72,1810,578));im.thumbnail((352,248));x=n%5*360;y=n//5*270;contact.paste(im,(x,y));draw.text((x+5,y+246),f'{i} {c[i]["name"]}',font=font,fill='white')
contact.save(P/'effects-contact.jpg',quality=92);new_ids=[i for i in ids if i>386]
sprite_contact=Image.new('RGB',(1000,((len(new_ids)+9)//10)*145),'#203840');sprite_draw=ImageDraw.Draw(sprite_contact)
for n,i in enumerate(new_ids):
 im=Image.open(R/f'assets/pokemon/front/{i:03d}.png').convert('RGBA');im.thumbnail((96,112));x=n%10*100;y=n//10*145;sprite_contact.paste(im,(x+(100-im.width)//2,y),im);sprite_draw.text((x+10,y+120),str(i),fill='white')
sprite_contact.save(P/'new-sprites-contact.png')
info={'game_commit':capture_commit,'runtime_commit':commit,'engine':'Godot 4.7.2','platform':'Linux / X11 / llvmpipe','scope':{'rare_base_species':100,'regional_forms':3,'rare_entries':103,'all_runtime_entries':468,'new_entries':82,'unique_arrivals':25,'clues':463},'calibration_sha256':hashlib.sha256((R/'data/battlefield_layouts.json').read_bytes()).hexdigest(),'note':'Seeded mid-campaign boundary fixtures, not a played full expedition. Anticipation/reveal shots freeze the real tween at documented effect progress 0.40/0.67. Natural playback and OS interaction separately checked for 3 species.','screenshots':manifest}
(P/'manifest.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
intro=f'''# 희귀 9세대 · 등장 연출 검토

촬영 코드 [{capture_commit[:7]}](https://github.com/agree-git/pokemon-deckbuilder/commit/{capture_commit}) · 최종 게임 [main `{commit[:7]}`](https://github.com/agree-git/pokemon-deckbuilder/commit/{commit}). **실제 1920×1080 화면 65장**입니다. 개발 검토용 전체 목록에는 희귀 포켓몬의 정체가 나옵니다. 촬영 후 변경은 무쇠감투 PNG의 원본 바이트 보존이며 RGBA 픽셀은 일치합니다.

- [전체 103종 CSV](rare_roster.csv) · [단서 463개 CSV](clues.csv) · [촬영 정보](manifest.json) · [독립 HTML 갤러리](index.html)
- [전체 화면 ZIP](rare-gen9-review-2026-10-17.zip) (다운로드 후 HTML을 열면 오프라인으로 볼 수 있습니다.)
- 일반 포켓몬은 1~3세대, 희귀는 1~9세대 기본 종 100 + 가라르 새 3폼. 일반 울트라비스트·패러독스 제외, 준전설 기반 패러독스 6종 포함.
- 준전설 53 · 환상 23 · 초전설 계열 27 (최종 25 + 코스모그·코스모움). 모두 포획 HP **10% 이하**. 단서/배지는 3/5/7개, 볼은 3/3/5개, 에너지는 2/2/3을 유지합니다.
- 코라이돈: 태고의 지층·거꾸로 흐르는 붉은 흙먼지. 미라이돈: 보라/청록 격자·입자 전송.

![25종 등장 효과](effects-contact.jpg)

## 발견 전 표시

![희귀 조사](screenshots/1025-hidden.png)
![도감 물음표](screenshots/collection-hidden.png)

조사·예약·지도·준비·이동은 정체를 숨깁니다. 도감에서 미발견 희귀의 실루엣·타입·번호와 검색 이름도 숨깁니다. 현재 원정에서 조우했거나 포획한 희귀는 표시합니다. 포획 도감은 포획 기록만 영구 보관하며 미포획 조우 이력을 새 영구 수집 시스템으로 추가하지는 않았습니다.

## 초전설 25종

예고는 progress 0.40, 등장은 0.67의 정지 프레임입니다. 효과는 1.0에서 정리되고 포켓몬과 조작이 완전히 드러납니다. 화면을 누르면 원본 크기로 볼 수 있습니다.

'''
rows=[]
for i in effects:
 name=c[i]['name'];rows.append(f'### {name}\n\n[예고](screenshots/{i}-anticipation.png) · [등장](screenshots/{i}-reveal.png)\n\n![{name}](screenshots/{i}-reveal.png)\n')
validation='''
## 확인한 범위

Linux/Godot **4.7.2** import 오류 0. 콘텐츠 보존/지문 3,293개, 신규 범위·103종 포획/스타팅/저장 5,660개, 희귀 전 과정 대표 20종/시드 추첨 5,886개, 종별 이야기/UI 3,593개 + 코스모그/코스모움 변경 85개, 기존 저장 1,759개, 역사 fingerprint/추첨 호환 93개, 초전설 계열 문턱 전 과정 5,112개, 도감 숨김 210개, 희귀 진화 56개, 울음소리 실제 디코딩 103개를 통과했습니다. 최종 실제 X11은 223개 검사·OS 클릭 26회, 65 PNG 촬영 실패 0개입니다. 배경 위치 JSON은 사용자 보정 hash를 유지합니다.

중간 원정 경계 검체에서 조사·포획을 검사한 결과입니다. 새 콘텐츠로 전체 69전투를 사람이나 자동 정책이 완주했다는 뜻은 아닙니다. 25종 모두 실제 렌더링과 상태/난수 무변경·정리를 검사했고, 3종은 실제 입력과 자연 재생을 검사했습니다. 전체 모음과 대표 원본을 육안 확인했습니다. Windows 실행과 사람 밸런스 평가는 별도 미완료입니다.

## 추가된 도트

코스모그·코스모움도 조사/배지 7개가 필요하므로 초전설 조건을 진화로 우회할 수 없습니다.

기존 21종 외 82개 항목의 앞/뒤 스프라이트와 울음소리를 연결했습니다. 아래는 새 앞모습 모음입니다.

![추가 82종/폼](new-sprites-contact.png)

원본/변환 고지는 [main/ASSET_SOURCES.md](https://github.com/agree-git/pokemon-deckbuilder/blob/main/ASSET_SOURCES.md)를 따릅니다.
'''
(P/'README.md').write_text(intro+'\n'.join(rows)+validation)
body=''.join(f'<details><summary>{html.escape(c[i]["name"])}</summary><div class="pair"><figure><a href="screenshots/{i}-anticipation.png"><img loading="lazy" src="screenshots/{i}-anticipation.png" alt="예고"></a><figcaption>예고</figcaption></figure><figure><a href="screenshots/{i}-reveal.png"><img loading="lazy" src="screenshots/{i}-reveal.png" alt="등장"></a><figcaption>등장</figcaption></figure></div></details>' for i in effects)
(P/'index.html').write_text('''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>희귀 포켓몬 등장 연출</title><style>body{margin:24px auto;max-width:1280px;padding:0 16px;background:#10252c;color:#eee5cd;font-family:system-ui}a{color:#a5dbef}img{max-width:100%;height:auto}details{padding:16px;border:1px solid #405960;margin:12px 0;border-radius:8px}summary{cursor:pointer;font-size:24px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:16px 0}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><h1>희귀 포켓몬 등장 연출</h1><p>103종 희귀 확장 · 초전설 25종. 개발 검토용으로 정체가 공개됩니다.</p><p><a href="rare_roster.csv">전체 목록 CSV</a> · <a href="clues.csv">단서 CSV</a> · <a href="README.md">구현·검증 기록</a></p><img src="effects-contact.jpg" alt="25종 효과 모음"><h2>종별 원본</h2>'''+body+'</html>')
zip_path=P/'rare-gen9-review-2026-10-17.zip'
with zipfile.ZipFile(zip_path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for path in sorted(P.rglob('*')):
  if path.is_file() and path != zip_path:z.write(path,path.relative_to(P))
with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
print('Review',len(manifest),'screenshots;',zip_path.stat().st_size,'zip bytes; game',commit)
