# CLAUDE.md 鈥?MEMO 椤圭洰鍗忎綔鎸囧崡

鏈枃浠朵负 AI 鍔╂墜锛圕laude 绛夛級缁存姢鏈」鐩彁渚涗笂涓嬫枃銆備慨鏀逛唬鐮佸墠鍏堣鏈枃浠躲€?

## 椤圭洰姒傝

**MEMO**锛歠lomo锛堟诞澧ㄧ瑪璁帮級鐨勬湰鍦扮鏈夊钩鏇裤€傚儚鍙戝井鍗氫竴鏍疯绗旇锛屾暟鎹?100% 瀛樻湰鏈?SQLite锛岄浂涓婁紶銆?
鏍稿績鐗规€э細蹇€熻褰曘€佸绾ф爣绛撅紙`#鐖?瀛恅锛夈€佹椂闂寸嚎銆佸叏鏂囨悳绱€佹瘡鏃ュ洖椤俱€佺粺璁＄儹鍔涘浘銆佸鍑?瀵煎叆銆佺紪杈?缃《銆佸叏灞€鐑敭蹇€熻褰曘€丮CP 渚?AI 鎸夋爣绛?鏃ユ湡鑼冨洿璇诲彇銆?*鏃犺闊宠緭鍏?*锛堟槑纭笉鍋氾級銆?

浜や粯褰㈡€侊紙涓夐€変竴/骞跺瓨锛夛細
1. **妗岄潰鐗堬紙鎺ㄨ崘锛?*锛欵lectron 澹?+ Python 鍚庣 exe + React 鍓嶇锛孨SIS 瀹夎鍖?
2. **缃戦〉鐗?*锛歅ython 鏈嶅姟 + 娴忚鍣?PWA
3. **MCP 鎺ュ彛**锛欰I Agent 璇诲彇/鍐欏叆

## 鎶€鏈爤涓庢灦鏋?

```
React 鍓嶇锛圲I 灞傦紝flomo/ 婧愮爜 鈫?鏋勫缓鍒?app/锛?
  鈹溾攢 妗岄潰绐楀彛锛圗lectron 澹?desktop/锛屽姞杞藉悗绔墭绠＄殑鍓嶇锛?
  鈹溾攢 缃戦〉 / PWA锛坔ttp://127.0.0.1:8899锛?
  鈹斺攢 鏈潵绉诲姩绔紙澶嶇敤 REST API锛屾灦鏋勫凡棰勭暀锛屾湭瀹炵幇锛?
        鈹?REST API
Python 鍚庣锛坰ervice.py 鈫?PyInstaller 鎵撳寘 dist/memo-backend/锛?
  鈹斺攢 SQLite锛坢emo.db锛夋湰鍦板瓨鍌?
MCP Server锛坢cp_server.py 鈫?PyInstaller 鎵撳寘 dist/memo-mcp/锛?
```

- 鍓嶇锛歊eact 19 + Vite 7 + Tailwind 3 + shadcn 椋庢牸锛圞imi 鐢熸垚鍚庨泦鎴愶級锛孴ypeScript
- 鍚庣锛歅ython 3.14锛坄C:\Python314\python.exe`锛?*PATH 閲岀殑 `python` 鏄?chrys venv锛屾棤 pip 鏃犱緷璧栵紝鍕跨敤**锛夛紝stdlib HTTP 鏈嶅姟
- 妗岄潰澹筹細Electron 33 + electron-builder 25锛圢SIS 瀹夎鍖咃級
- MCP锛歚mcp` Python SDK 1.x锛團astMCP锛夛紝娉ㄦ剰 mcp 2.x 閲嶆瀯鏃?fastmcp锛?*鍕垮崌绾?*

## 鐩綍缁撴瀯

| 璺緞 | 璇存槑 |
|---|---|
| `service.py` | 鍚庣涓绘湇鍔★細REST API + flomo 鍏煎鍐欏叆 + 闈欐€佹墭绠?+ (GUI: 鎵樼洏/鐑敭/鍥為【) |
| `mcp_server.py` | MCP Server锛? 涓伐鍏凤紙list_tags/count_memos/list_memos/get_memo/add_memo/get_stats锛?|
| `app/` | 鍓嶇**鏋勫缓浜х墿** + PWA锛坢anifest.json銆乻w.js銆乮con-*.png锛?|
| `flomo/` | 鍓嶇**婧愮爜**锛圧eact/Vite锛夛紝鏀硅繖閲屽悗 `npm run build` 杈撳嚭鍒?`flomo/dist/` |
| `desktop/` | Electron 澹筹紙main.js 涓昏繘绋嬨€乧apture.html 蹇€熻褰曠獥銆乥uild/icon.ico锛?|
| `dist/` | PyInstaller 浜х墿锛歚memo-backend/`锛坥nedir锛夈€乣memo-mcp/`锛坥nedir锛?|
| `memo.db*` | 缃戦〉鐗堟ā寮忔暟鎹紙椤圭洰鐩綍锛夛紱妗岄潰鐗堟暟鎹湪 `%APPDATA%\memo\data\` |
| `start.bat` / `install_service.bat` / `uninstall_service.bat` | 缃戦〉鐗堟湇鍔＄鐞?|
| `README.md` | 鐢ㄦ埛鏂囨。锛堝姛鑳?瀹夎/MCP 閰嶇疆/鏁版嵁杩佺Щ锛?|

## 鍏抽敭鍛戒护

```bat
REM 鐜锛歅ython 涓€寰嬬敤 C:\Python314\python.exe锛沺ip 鐢ㄦ竻鍗庨暅鍍?-i https://pypi.tuna.tsinghua.edu.cn/simple

REM 缃戦〉鐗堬紙婧愮爜妯″紡锛?
C:\Python314\python.exe service.py --no-gui --port 8899   REM 鏃?GUI锛涢粯璁?8899 鍚墭鐩?鐑敭

REM 鍓嶇鏋勫缓锛堟敼 flomo/ 婧愮爜鍚庯級鈫?閮ㄧ讲鍒?app/
cd flomo && npm ci && npm run build
REM 鐒跺悗澶嶅埗 dist/index.html + dist/assets/ 鍒?app/锛屽苟鏇存柊 app/sw.js 鐨?CACHE 鐗堟湰鍙蜂笌 ASSETS 鏂囦欢鍚?

REM 鍚庣鎵撳寘锛圥yInstaller锛屽繀椤?--onedir 涓嶈兘鐢?--onefile锛侊級
C:\Python314\python.exe -m PyInstaller --noconfirm --onedir --name memo-backend ^
  --exclude-module tkinter --exclude-module pystray --exclude-module keyboard --exclude-module PIL ^
  --add-data "app;app" service.py

REM MCP 鎵撳寘锛堜繚鐣?console 瀛愮郴缁熶互鏀寔 stdio 绠￠亾锛?
C:\Python314\python.exe -m PyInstaller --noconfirm --onedir --name memo-mcp ^
  --exclude-module tkinter --exclude-module pystray --exclude-module keyboard --exclude-module PIL ^
  --hidden-import uvicorn --hidden-import uvicorn.loops.auto --hidden-import uvicorn.loops.asyncio ^
  --hidden-import uvicorn.protocols.http.auto --hidden-import uvicorn.protocols.http.h11_impl ^
  --hidden-import uvicorn.lifespan.on mcp_server.py

REM 妗岄潰鐗堟墦鍖咃紙闇€鍏堝畬鎴愬墠绔瀯寤?鍚庣鎵撳寘锛涘浗鍐呯綉缁滈渶闀滃儚锛?
cd desktop
set ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
set ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/
npx electron-builder --win        REM 杈撳嚭 desktop/release/MEMO-绗旇-Setup-1.1.0.exe

REM MCP 杩愯
dist\memo-mcp\memo-mcp.exe                        REM stdio
dist\memo-mcp\memo-mcp.exe --http --port 8898     REM Streamable HTTP
```

## 绔彛涓庢暟鎹害瀹?

| 绔彛 | 鐢ㄩ€?|
|---|---|
| 8899 | 缃戦〉鐗堝悗绔紙service.py 婧愮爜妯″紡锛屾暟鎹湪椤圭洰鐩綍 memo.db锛?|
| 8900 | 妗岄潰鐗堝悗绔紙Electron 鎷夎捣 memo-backend.exe锛屾暟鎹湪 `%APPDATA%\memo\data\memo.db`锛?|
| 8901 | 灞€鍩熺綉璁块棶锛坰tart_lan.bat 鍚姩锛宍--host 0.0.0.0`锛屼笌妗岄潰鐗堝悓鏁版嵁鐩綍锛?|
| 8898 | MCP HTTP 妯″紡 |

## 閴存潈鏈哄埗锛堝眬鍩熺綉妯″紡锛?

- `service.py --host 0.0.0.0` 鏃讹細闈炴湰鏈烘潵婧愶紙client IP 鈮?127.0.0.1/::1锛夎闂?`/api/*`銆乣/v1/*` 涓€寰嬭姹備护鐗岋紱鏈満鍏嶄护鐗?
- 浠ょ墝鑷姩鐢熸垚瀛樹簬 `config.json`锛坄token` 瀛楁锛夛紝`ensure_token()` / `reset_token()` 绠＄悊锛涙牎楠岀敤 `hmac.compare_digest`
- 浠ょ墝浼犻€掞細`Authorization: Bearer <t>` / `X-Memo-Token` / `?token=` 鍧囧彲
- 鍓嶇锛歚api.ts` 璇锋眰鑷姩甯?`Authorization`锛坙ocalStorage `memo-token`锛夛紱401 瑙﹀彂 `memo:unauthorized` 浜嬩欢 鈫?index.html 寮?prompt 杈撳叆 鈫?淇濆瓨骞?reload
- 妗岄潰鐗堬紙Electron spawn 鍚庣榛樿 127.0.0.1锛変笌婧愮爜缃戦〉鐗堥粯璁や笉鍙楀奖鍝嶏紙鍏嶄护鐗岋級
- 鎵撳寘鐗?exe 鏁版嵁鐩綍榛樿 `%APPDATA%\memo\data`锛堟棤闇€ MEMO_DATA_DIR锛夛紱MCP 鐩存帴璇?SQLite 涓嶈蛋 HTTP 閴存潈锛堟湰鍦板伐鍏凤級

## 鏁版嵁绾﹀畾

- 鏁版嵁鐩綍缁熶竴鐢?`MEMO_DATA_DIR` 鐜鍙橀噺瑕嗙洊锛涙墦鍖呯増榛樿 `%APPDATA%\memo\data`
- 鍓嶇鎵€鏈夋暟鎹粡 REST API锛堜笉鐩存帴璇诲啓 SQLite锛夛紱MCP 鐩存帴璇?SQLite锛堜笌鍚庣鍚屽簱锛學AL 骞跺彂瀹夊叏锛?
- **鏃х綉椤电増鏈嶅姟锛坧ythonw 8899锛夊彈淇濇姢鏉€涓嶆帀锛屾闈㈢増鐢?8900 瑙勯伩锛涗袱鑰呮暟鎹垎瀹讹紝杩佺Щ鐢?SQLite backup API锛堝嬁鐩存帴澶嶅埗鏂囦欢锛屼細涓?WAL锛?*

## 鐗堟湰杩唬瑙勮寖锛堟瘡娆¤凯浠ｅ繀椤绘墽琛岋級

褰撳墠鐗堟湰锛?*1.1.0**锛堜簯鍚屾 + 绔埌绔姞瀵?+ 鎵嬫満绔?S2锛夈€傝涔夊寲鐗堟湰 `x.y.z`锛屽姛鑳借凯浠ｅ崌 `y`銆佷慨澶嶅崌 `z`銆?

姣忔杩唬鍙戝竷鍓嶏紝**蹇呴』鍚屾鏇存柊浠ヤ笅鐗堟湰鍙?*锛堢己涓€涓嶅彲锛夛細

| 浣嶇疆 | 鏂囦欢 | 浣滅敤 |
|---|---|---|
| 妗岄潰鐗?| `desktop/package.json` 鈫?`"version"` | 鍐冲畾瀹夎鍖呭悕 `MEMO-绗旇-Setup-{version}.exe` |
| 鎵嬫満绔?| `mobile/pubspec.yaml` 鈫?`version: x.y.z+n` | Android/iOS 鐗堟湰鍙凤紙n 涓烘瀯寤哄彿锛?|
| 鍚庣 | `service.py` 鈫?`APP_VERSION` | `/api/health` 杩斿洖锛屽彲鏌ヨ繍琛屾椂鐗堟湰 |

鐒跺悗閲嶆柊鏋勫缓骞跺洖褰掞細
1. 鍓嶇 `cd flomo && npm run build` 鈫?閮ㄧ讲 `app/` + 鏇存柊 `sw.js` 缂撳瓨鐗堟湰
2. 鍚庣 `PyInstaller` 閲嶆墦 鈫?`desktop` 閲?`npx electron-builder --win`
3. 鎵嬫満绔?`flutter build windows`锛堝闇€鍙戝竷 Android锛歚flutter build apk`锛?
4. 鍥炲綊锛歚_run_api_tests.py` / `_run_sync_tests.py` / `_run_sync_e2e.py` / `_run_desktop_tests.ps1` / `flutter test`

妫€鏌ュ綋鍓嶅悇绔増鏈彿锛?
```
grep '"version"' desktop/package.json
grep '^version:' mobile/pubspec.yaml
grep 'APP_VERSION' service.py
```

## 浜戝悓姝ュ紩鎿庯紙鍧氭灉浜?路 鍙樻洿鏃ュ織锛?

- 璁捐鏂囨。锛歚SYNC-DESIGN.md`锛涘疄鐜帮細`sync.py`锛圫yncEngine锛?
- 鍐欐搷浣滐紙create/update/pin/delete/clear/import/flomo 鍐欏叆锛夌粡 `SYNC.log_op` 杩藉姞鍒?`{sync.dir}/{device}.jsonl`
- `pull_and_merge()` 鎵弿 `{sync.dir}` 涓?*闄よ嚜宸辫澶囧**鎵€鏈?`.jsonl`锛屾寜 `id+ts` 鍚堝苟锛坙ast-write-wins锛夛紝骞傜瓑鍙噸鏀撅紱鏂偣瀛?`{data_dir}/sync-state.json`
- 璁惧鍚嶏細`--device` 鍙傛暟锛堥粯璁?desktop锛屽绔繀椤讳笉鍚岋級锛涙棩蹇楁枃浠跺悕 = `{device}.jsonl`
- 鍚堝苟鍐欏簱鐩存帴鐢?`sqlite3`锛堥潪 WAL锛夛紝浜嬪姟鍐呮壒閲忓簲鐢紱`set_memo_tags` 浼氶噸绠楁爣绛捐鏁?
- 棣栨鍚敤锛歚ensure_full_dump()` 鎶婂瓨閲忔暟鎹?dump 涓?add 鏃ュ織锛堟枃浠堕潪绌哄垯璺宠繃锛?
- 瀹氭椂锛歮ain() 鍚姩 `SYNC.loop(15s)` 鍚庡彴绾跨▼锛沗POST /api/sync/now` 鎵嬪姩瑙﹀彂
- 鏁版嵁妯″瀷锛歚memos.uuid`锛堝叏灞€鍞竴锛屽绔搴斿悓涓€绗旇锛夛紱瀛橀噺搴?init_db 鑷姩杩佺Щ琛?uuid
- **娉ㄦ剰**锛歚api_list_memos` 鐨?SELECT 蹇呴』鍖呭惈 `m.uuid`锛坢emo_row_to_dict 渚濊禆锛夛紱浠讳綍杩斿洖 memo dict 鐨勬煡璇㈠悓鐞?
- **绔埌绔姞瀵?*锛歚sync.SyncCrypto`锛圓ES-256-GCM + PBKDF2 200k 杩唬锛夛紱鍙ｄ护/鐩愬瓨 `config.json sync.passphrase/salt`锛堟湰鍦帮級锛屾棩蹇楁枃浠跺叏瀵嗘枃锛涜琛屽厛瑙ｅ瘑銆佸け璐ユ寜鏄庢枃鍏煎锛沗log_op` 妫€娴嬫槑鏂囨棩蹇楄嚜鍔ㄦ棤鎹熻浆鎹紱`pull_and_merge` 杩斿洖瑙ｅ瘑澶辫触鏁帮紙鍙ｄ护閿欒鏃跺悓姝ラ潤榛樺け鏁堬紝UI 鐘舵€佸彲鏌ワ級锛涗緷璧?`cryptography`锛圥yInstaller 鍐呯疆 hook 宸叉敹闆嗭級

## 宸茬煡鍧戜笌娉ㄦ剰浜嬮」

1. **`python` 鍛戒护**瑙ｆ瀽鍒?chrys venv锛堟棤 pip/渚濊禆锛夆€斺€旀墍鏈?Python 鎿嶄綔蹇呴』鐢?`C:\Python314\python.exe`
2. **PowerShell 5.1 璇?UTF-8 鏂囦欢**瑕?`Get-Content -Raw -Encoding UTF8`锛屽惁鍒欎腑鏂囦贡鐮?
3. **PyInstaller 蹇呴』 onedir**锛歰nefile 鐨勫紩瀵艰繘绋嬩細 spawn 瀛愯繘绋嬪悗閫€鍑猴紝Electron 璇垽鍚庣姝讳骸鑰岃嚜鏉€
4. **service.py 鐨?`import keyboard/pystray` 蹇呴』鐣欏湪 main() 鐨?GUI 鍒嗘敮**锛堟墦鍖呮椂宸?exclude锛宧eadless 妯″紡 import 浼氬穿锛夛紱鍚岀悊 tkinter/PIL 浠呭湪 GUI 璺緞浣跨敤
5. **Electron 涓昏繘绋?*锛歴pawn 鍚庣 exe 浼?`--no-gui --port 8900` + `env.MEMO_DATA_DIR`锛涘悗绔?exit 鍚庢湁 2s 寤惰繜纭锛堥槻璇垽锛夛紱绐楀彛鍏抽棴=闅愯棌鍒版墭鐩橈紱閫€鍑烘椂 kill 鍚庣
6. **鍓嶇鍙戝竷鍚庡繀椤诲悓姝ユ洿鏂?`app/sw.js`**锛欳ACHE 鐗堟湰鍙?+1銆丄SSETS 鎹㈡垚鏂?hash 鏂囦欢鍚嶏紝鍚﹀垯 PWA 缂撳瓨鏃х増
7. **mcp SDK 宸查攣瀹?1.x**锛團astMCP锛夛紱2.x 閲嶆瀯鍒犻櫎浜?fastmcp
8. npm 瀹夎/鎵撳寘鎱㈡椂鐢?`ELECTRON_MIRROR`銆乣ELECTRON_BUILDER_BINARIES_MIRROR`锛坣pmmirror锛夛紱npm ci 鍓嶇‘璁ゆ棤 vite dev server 鍗犵敤 esbuild锛坄Get-Process esbuild`锛?
9. **娴嬭瘯鏂规硶**锛氬悗绔?`--no-gui` 鍚姩鍚?curl `/api/health`銆乣/api/memos`锛汳CP 鐢?`mcp.client.stdio` / `streamablehttp_client`锛堟敞鎰忚 client 杩斿洖涓夊厓缁?`(read, write, get_session_id)`锛夊啓鑴氭湰楠岃瘉锛汦lectron 鐢?`desktop\release\win-unpacked\MEMO 绗旇.exe`锛堢瓑浠峰畨瑁呯幆澧冿級楠岃瘉
10. React 19锛歚useRef<T>()` 鏃犲弬璋冪敤鎶?TS 閿欙紝闇€ `useRef<T | undefined>(undefined)`

## 绉诲姩绔鐣欙紙鏈疄鐜帮級

- 鍓嶇 React 缁勪欢鍙鐢紙React Native/WebView锛夛紱鍚庣 REST API 閮ㄧ讲鍒版湇鍔″櫒鍗冲彲杩滅▼璁块棶
- MCP 鍚屾牱鍙縼鏈嶅姟鍣ㄤ緵浜戠 Agent 浣跨敤
- 鐩墠鏃犻壌鏉冿紙浠呯洃鍚?127.0.0.1锛夛紝鍏綉閮ㄧ讲鍓嶅繀椤诲姞鐧诲綍/Token




## 后端重构记录（2026-09，v1.3.0）

### 公共模块 memo_common.py（唯一来源，勿再复制）
标签解析 parse_tags / rebuild_tag_counts / set_memo_tags；时间 now_ms / normalize_ts；
路径 is_frozen / resolve_data_dir；数据库 connect / db_session / init_schema / insert_memo /
fetch_memo / memo_row_to_dict / compute_stats。service.py、sync.py、mcp_server.py 全部改为导入此模块。

### 数据目录统一约定（重要）
桌面版固定 userData = %APPDATA%\\memo（main.js 显式 app.setPath，不再随 app name 漂移），
数据在 %APPDATA%\\memo\\data\\memo.db；MCP 独立运行、_run_desktop_tests.ps1、start_lan.bat 均回退同一路径。
首次启动会自动从旧的 %APPDATA%\\memo-desktop\\data 迁移数据。

### 测试环境
requirements.txt 已补全（cryptography / mcp 为必需依赖）；统一用项目 .venv：
  uv venv .venv --python 3.12 ; uv pip install -r requirements.txt
测试脚本用环境变量 MEMO_PYTHON 或默认 .venv\\Scripts\\python.exe 定位解释器（不再硬编码 C:\\Python3xx）。

### 统计字段统一
compute_stats 返回 thisWeek / streak / total / today（REST 与 MCP 共用，前端字段名不变）。

### 前端重构
标签规则唯一来源 lib/tags.ts（与后端 parse_tags 对齐）；时间格式化 lib/time.ts；
新增 hooks/useToast.ts、components/Toast.tsx、components/EditMemoDialog.tsx；删除死代码
（rich.ts applyFormat、App.css、api.ts setToken、useMemos ready）。
