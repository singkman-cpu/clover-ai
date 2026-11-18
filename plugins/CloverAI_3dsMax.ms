-- Clover AI for 3ds Max 1.0.0  (https://www.cloverai.kr)
-- 지금 보는 뷰포트 화면을 버튼 하나로 Clover AI 렌더 실사화에 보내요.
-- 설치: 이 파일을 3ds Max 화면에 끌어다 놓거나 [Scripting → Run Script]로 한 번 실행하세요.
--       실행하면 Clover AI 창이 뜨고, 다음부터는 [Customize → Customize User Interface → 카테고리 "Clover AI"]의
--       "Clover AI 렌더" 버튼을 툴바에 끌어다 두고 쓰면 돼요.
-- 서버 비밀키는 이 파일에 없어요. 연결 코드는 회원마다 다르고 사이트에서 언제든 끊을 수 있어요.

global CloverAI_UploadUrl = "https://evyraulomxntyhxsivmo.supabase.co/functions/v1/plugin-upload"
global CloverAI_Ini = (getDir #plugcfg) + "\\CloverAI.ini"
global CloverAI_GetCode
global CloverAI_Post
global CloverAI_Send
global CloverAI_AskCode
global CloverAI_Field
global CloverAI_Rollout

fn CloverAI_GetCode = (
	local c = getINISetting CloverAI_Ini "Clover" "code"
	trimLeft (trimRight c)
)

-- JSON 응답에서 "key":"value" 값 꺼내기 (간단한 응답이라 이걸로 충분)
fn CloverAI_Field txt key = (
	local pat = "\"" + key + "\":\""
	local i = findString txt pat
	if i == undefined then return ""
	local s = i + pat.count
	local e = s
	while e <= txt.count and txt[e] != "\"" do e += 1
	substring txt s (e - s)
)

-- 서버로 JSON POST → #(성공여부, 응답글자)
fn CloverAI_Post payload = (
	local resTxt = ""
	local ok = false
	try (
		(dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12
		local wc = dotNetObject "System.Net.WebClient"
		wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8
		wc.Headers.Add "Content-Type" "application/json"
		resTxt = wc.UploadString CloverAI_UploadUrl "POST" payload
		ok = (findString resTxt "\"ok\":true") != undefined
	) catch (
		local ex = getCurrentException()
		if (findString ex "401") != undefined then resTxt = "{\"error\":\"BAD_CODE\"}"
		else if (findString ex "429") != undefined then resTxt = "{\"error\":\"LIMIT\"}"
		else resTxt = "{\"error\":\"NET\"}"
	)
	#(ok, resTxt)
)

fn CloverAI_AskCode newCode = (
	local c = toUpper (trimLeft (trimRight newCode))
	if not (matchPattern c pattern:"CLV-????????????????????????") or c.count != 28 then (
		messageBox "연결 코드 모양이 달라요.\nClover AI 사이트 → 렌더 실사화 탭 → [스케치업·3ds Max에서 바로 보내기]에서 받은 코드를 그대로 붙여넣어 주세요." title:"Clover AI"
		return false
	)
	setINISetting CloverAI_Ini "Clover" "code" c
	local r = CloverAI_Post ("{\"action\":\"check\",\"code\":\"" + c + "\"}")
	if r[1] then messageBox "Clover AI에 연결됐어요.\n이제 [Clover AI 렌더] 버튼을 누르면 지금 뷰포트 화면이 렌더 실사화로 가요." title:"Clover AI"
	else messageBox "연결에 실패했어요. 코드가 끊겼거나 틀렸어요.\n사이트에서 새 연결 코드를 받아 다시 넣어 주세요." title:"Clover AI"
	r[1]
)

fn CloverAI_Send wf = (
	local code = CloverAI_GetCode()
	if code == "" then (
		messageBox "처음 한 번만 연결 코드가 필요해요.\nClover AI 창의 [연결 코드] 칸에 사이트에서 받은 코드를 넣어 주세요." title:"Clover AI"
		try (createDialog CloverAI_Rollout) catch ()
		return false
	)
	-- 지금 활성 뷰포트 화면 캡처 (툴바·메뉴 없이 뷰포트만)
	local bm = gw.getViewportDib()
	if bm == undefined then ( messageBox "화면 캡처에 실패했어요. 뷰포트를 한 번 클릭하고 다시 눌러 주세요." title:"Clover AI"; return false )
	local f = (getDir #temp) + "\\clover_ai_" + (timeStamp() as string) + ".jpg"
	bm.filename = f
	save bm
	close bm
	if not (doesFileExist f) then ( messageBox "화면 저장에 실패했어요." title:"Clover AI"; return false )
	local b64 = (dotNetClass "System.Convert").ToBase64String ((dotNetClass "System.IO.File").ReadAllBytes f)
	try (deleteFile f) catch ()
	pushPrompt "Clover AI로 화면을 보내는 중…"
	local r = CloverAI_Post ("{\"code\":\"" + code + "\",\"src\":\"3dsmax\",\"wf\":\"" + wf + "\",\"image_b64\":\"" + b64 + "\"}")
	popPrompt()
	if r[1] then (
		local url = CloverAI_Field r[2] "open"
		if url != "" then shellLaunch url "" else messageBox "보내기는 됐는데 주소를 못 받았어요. 다시 눌러 주세요." title:"Clover AI"
	) else (
		local er = CloverAI_Field r[2] "error"
		if er == "BAD_CODE" then messageBox "연결 코드가 끊겼거나 틀렸어요.\nClover AI 사이트에서 새 연결 코드를 받아 Clover AI 창에 넣어 주세요." title:"Clover AI"
		else if er == "LIMIT" then messageBox "오늘 보낼 수 있는 장수를 넘었어요. 내일 다시 해 주세요." title:"Clover AI"
		else messageBox "보내기에 실패했어요. 인터넷 연결을 확인하고 다시 눌러 주세요." title:"Clover AI"
	)
	r[1]
)

rollout CloverAI_Rollout "Clover AI" width:260 (
	label lb1 "지금 뷰포트 화면을 Clover AI로 보내요" align:#left
	button btnRender "▶ 렌더 실사화로 보내기" width:236 height:34
	button btnEdit "AI 편집으로 보내기" width:236 height:24
	group "연결 코드 (처음 한 번만)" (
		edittext etCode "" width:226 align:#left
		button btnSave "연결하기" width:110 across:2
		button btnSite "사이트 열기" width:110
	)
	label lb2 "툴바에 두려면: Customize → Customize User" align:#left
	label lb3 "Interface → 카테고리 Clover AI → 버튼 끌어놓기" align:#left
	on CloverAI_Rollout open do ( etCode.text = CloverAI_GetCode() )
	on btnRender pressed do CloverAI_Send "render"
	on btnEdit pressed do CloverAI_Send "edit"
	on btnSave pressed do CloverAI_AskCode etCode.text
	on btnSite pressed do shellLaunch "https://www.cloverai.kr" ""
)

macroScript CloverAI_Render category:"Clover AI" buttonText:"Clover AI 렌더" tooltip:"지금 뷰포트 화면을 Clover AI 렌더 실사화로 보내기" (
	if CloverAI_Send == undefined then ( messageBox "Clover AI 스크립트를 한 번 다시 실행해 주세요." title:"Clover AI" ) else CloverAI_Send "render"
)
macroScript CloverAI_Window category:"Clover AI" buttonText:"Clover AI 창" tooltip:"Clover AI 창 열기 (연결 코드·보내기)" (
	if CloverAI_Rollout == undefined then ( messageBox "Clover AI 스크립트를 한 번 다시 실행해 주세요." title:"Clover AI" ) else ( try (destroyDialog CloverAI_Rollout) catch (); createDialog CloverAI_Rollout )
)

-- 다음에 3ds Max를 켜도 함수가 살아 있게: 이 파일을 사용자 시작 스크립트 폴더에 복사(자동 실행되면 창은 안 띄움)
(
	local me = getSourceFileName()
	local dst = (getDir #userStartupScripts) + "\\CloverAI_3dsMax.ms"
	if me != undefined and (toLower me) != (toLower dst) then (
		try ( makeDir (getDir #userStartupScripts) all:true; if doesFileExist dst then deleteFile dst; copyFile me dst ) catch ()
		try (destroyDialog CloverAI_Rollout) catch ()
		createDialog CloverAI_Rollout
	)
)
