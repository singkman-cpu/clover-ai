-- Clover AI for 3ds Max 1.1.0  (https://www.cloverai.kr)
-- 지금 보는 뷰포트 화면을 클로버 버튼 하나로 Clover AI 렌더 실사화에 보내요.
-- 설치: 이 파일을 3ds Max 화면에 끌어다 놓거나 [Scripting → Run Script]로 한 번 실행하세요.
--       Clover AI 창이 뜨고, 툴바에 두려면 Customize → Customize User Interface → 카테고리 "Clover AI"의 클로버 버튼을 끌어다 놓으세요.
-- 처음 한 번만: 버튼을 누르면 브라우저가 열리고, Clover AI에 로그인된 상태에서 [연결 허용]만 누르면 끝(코드 복사 없음).
-- Clover AI 창이 이미 열려 있으면 그 창에 바로 들어가요(새 창을 또 열지 않음).
-- 서버 비밀키는 이 파일에 없어요. 연결은 회원마다 따로이고 사이트에서 언제든 끊을 수 있어요.

global CloverAI_UploadUrl = "https://evyraulomxntyhxsivmo.supabase.co/functions/v1/plugin-upload"
global CloverAI_Ini = (getDir #plugcfg) + "\\CloverAI.ini"
global CloverAI_GetCode, CloverAI_Post, CloverAI_Send, CloverAI_Field, CloverAI_Pair, CloverAI_WriteB64
global CloverAI_Rollout, CloverAI_Wait, CloverAI_PairInfo, CloverAI_AfterPair

fn CloverAI_WriteB64 path b64 = (
	try ( (dotNetClass "System.IO.File").WriteAllBytes path ((dotNetClass "System.Convert").FromBase64String b64) ) catch ()
)

-- 클로버 아이콘 파일 쓰기 (툴바 버튼 아이콘)
(
	local d = getDir #userIcons
	try ( makeDir d all:true ) catch ()
	CloverAI_WriteB64 (d + "\\CloverAI_16i.bmp") "Qk02AwAAAAAAADYAAAAoAAAAEAAAABAAAAABABgAAAAAAAADAADEDgAAxA4AAAAAAAAAAAAAAAAAAAAAdHIGhoYGhIQGhYQGhIQGhIQGhIQGhYQGhYQGhIMGhYUHeHYGAAAAAAAAAAAAkI4ISkkEFRUBFBQBExMBExQBERECEBABFBMBExMBFBQBFRQBQ0IEk5AIAAAAdXMGQ0IEAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAANTQDgoAHiYcGDQwBAgIABQUCfnwFuroEcnEEAQEBAAABaGcFuroEiIYECQkCAwMABQUBjIsGhoUEEhIBAAAAcnEE//8B//8A//8CT04EPDwE//8C//8A//8BhoQEAAAACgkBiYgGh4UEEhEBAAAAq6oE/PwA7esA+PgAf34DbmwD+fkA7usA+/sAvr0EAAABCAgBiogFh4UEERABAAAATUwE//8D//8A//8AiIYDdXQD//8A//8A//8DXVwEAAAACAgBiogGh4UEDg4BAAAAAAABLSwDYWAEZWQDMTEEKyoEZWQDYmEENDMEAAABAAAABgYBiogGh4UEDg4BAAAAAAABREQEenkDfn0CPT0ENTQDfX0DenkDTEsEAAABAQEABgYBiogGh4YEEREBAAAAWVgE//8C//8A//8AiYcDdnQD//8B//8A//8CamkFAAAACQkBiokFh4YEEhIBAAAArqwD+/sA6+sA+PkAgH4DbWwD+foA7esA+foAwL8EAAAACAgBiokFhoUEEhEBAAAAamkE//8C//8A//8CTUwENjUD//8C//8A//8BfXsEAAAACQkBiYcGiokGDg0BAwMAAgICbWwEra0EaWcEAAABAAABWVgFq6sDd3YFBQUBAwMABQUBjIsGcnAGTUwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAOzoEfnwGAAAAkY8HU1IEGRkBGBgBFxcBFxcBFRUBFBQBFxcBFxcBGBgBGBgBSEgEkpAIAAAAAAAAAAAAcG4GhYQGg4IGg4MGg4MGg4MFg4MFhIMFhIQFg4IGhIQGc3IGAAAAAAAA"
	CloverAI_WriteB64 (d + "\\CloverAI_16a.bmp") "Qk02AwAAAAAAADYAAAAoAAAAEAAAABAAAAABABgAAAAAAAADAADEDgAAxA4AAAAAAAAAAAAAAAAAAAAA////////////////////////////////////////////////AAAAAAAAAAAA////////////////////////////////////////////////////////AAAA////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AAAA////////////////////////////////////////////////////////AAAAAAAAAAAA////////////////////////////////////////////////AAAAAAAA"
	CloverAI_WriteB64 (d + "\\CloverAI_24i.bmp") "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"
	CloverAI_WriteB64 (d + "\\CloverAI_24a.bmp") "Qk32BgAAAAAAADYAAAAoAAAAGAAAABgAAAABABgAAAAAAMAGAADEDgAAxA4AAAAAAAAAAAAAAAAAAAAAAAAA////////////////////////////////////////////////////////////////////////AAAAAAAAAAAAAAAAAAAA////////////////////////////////////////////////////////////////////////////////AAAAAAAAAAAA////////////////////////////////////////////////////////////////////////////////////////AAAA////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AAAA////////////////////////////////////////////////////////////////////////////////////////AAAAAAAAAAAA////////////////////////////////////////////////////////////////////////////////AAAAAAAAAAAAAAAAAAAA////////////////////////////////////////////////////////////////////////AAAAAAAAAAAA"
	CloverAI_WriteB64 (d + "\\CloverAI_logo48.png") "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"
	try ( colorMan.reInitIcons() ) catch ()
)

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
		else if (findString ex "410") != undefined then resTxt = "{\"error\":\"EXPIRED\"}"
		else if (findString ex "429") != undefined then resTxt = "{\"error\":\"LIMIT\"}"
		else resTxt = "{\"error\":\"NET\"}"
	)
	#(ok, resTxt)
)

-- 연결 기다리는 작은 창 (2초마다 확인 · 10분까지)
rollout CloverAI_Wait "Clover AI 연결" width:300 (
	label l1 "브라우저에서 Clover AI가 열렸어요." align:#left
	label l2 "로그인된 상태에서 [연결 허용]만 누르면 끝나요." align:#left
	label l3 "기다리는 중…" align:#left
	button btnCancel "취소" width:90 align:#right
	timer tk interval:2000 active:true
	local started = 0
	on CloverAI_Wait open do ( started = timeStamp() )
	on btnCancel pressed do destroyDialog CloverAI_Wait
	on tk tick do (
		if CloverAI_PairInfo == undefined then destroyDialog CloverAI_Wait
		else if (timeStamp() - started) > 600000 then ( destroyDialog CloverAI_Wait; messageBox "연결 시간이 지났어요. 버튼을 다시 눌러 주세요." title:"Clover AI" )
		else (
			local r = CloverAI_Post ("{\"action\":\"pair-poll\",\"pair\":\"" + CloverAI_PairInfo[1] + "\",\"secret\":\"" + CloverAI_PairInfo[2] + "\"}")
			local c = CloverAI_Field r[2] "code"
			if r[1] and c != "" then (
				setINISetting CloverAI_Ini "Clover" "code" c
				CloverAI_PairInfo = undefined
				destroyDialog CloverAI_Wait
				if CloverAI_AfterPair == true then CloverAI_Send() else messageBox "Clover AI에 연결됐어요.\n이제 Clover AI 버튼을 누르면 지금 뷰포트 화면이 렌더 실사화로 가요." title:"Clover AI"
			) else if (CloverAI_Field r[2] "error") == "EXPIRED" then (
				CloverAI_PairInfo = undefined
				destroyDialog CloverAI_Wait
				messageBox "연결 시간이 지났어요. 버튼을 다시 눌러 주세요." title:"Clover AI"
			)
		)
	)
)

fn CloverAI_Pair sendAfter = (
	local r = CloverAI_Post "{\"action\":\"pair-start\",\"src\":\"3dsmax\"}"
	local url = CloverAI_Field r[2] "url"
	if not r[1] or url == "" then ( messageBox "연결을 시작하지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요." title:"Clover AI"; return false )
	CloverAI_PairInfo = #(CloverAI_Field r[2] "pair", CloverAI_Field r[2] "secret")
	CloverAI_AfterPair = sendAfter
	shellLaunch url ""
	try (destroyDialog CloverAI_Wait) catch ()
	createDialog CloverAI_Wait
	true
)

fn CloverAI_Send = (
	local code = CloverAI_GetCode()
	if code == "" then ( CloverAI_Pair true; return false )
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
	local r = CloverAI_Post ("{\"code\":\"" + code + "\",\"src\":\"3dsmax\",\"wf\":\"render\",\"image_b64\":\"" + b64 + "\"}")
	popPrompt()
	if r[1] then (
		local url = CloverAI_Field r[2] "open"
		local picked = false
		if (findString r[2] "\"live\":true") != undefined then (
			-- 열려 있는 Clover AI 창이 받아 가면 새 창을 안 열어요 (6초까지 확인)
			local idTxt = ""
			local i = findString r[2] "\"id\":"
			if i != undefined then ( local s = i + 5; local e = s; while e <= r[2].count and (findString "0123456789" r[2][e]) != undefined do e += 1; idTxt = substring r[2] s (e - s) )
			if idTxt != "" then for k = 1 to 6 while not picked do (
				sleep 1
				local st = CloverAI_Post ("{\"action\":\"upload-status\",\"code\":\"" + code + "\",\"id\":" + idTxt + "}")
				picked = (findString st[2] "\"picked\":true") != undefined
			)
		)
		if picked then displayTempPrompt "열려 있는 Clover AI 창에 넣었어요. 브라우저를 확인하세요." 4000
		else if url != "" then shellLaunch url ""
		else messageBox "보내기는 됐는데 주소를 못 받았어요. 다시 눌러 주세요." title:"Clover AI"
	) else (
		local er = CloverAI_Field r[2] "error"
		if er == "BAD_CODE" then ( setINISetting CloverAI_Ini "Clover" "code" ""; CloverAI_Pair true )
		else if er == "LIMIT" then messageBox "오늘 보낼 수 있는 장수를 넘었어요. 내일 다시 해 주세요." title:"Clover AI"
		else messageBox "보내기에 실패했어요. 인터넷 연결을 확인하고 다시 눌러 주세요." title:"Clover AI"
	)
	r[1]
)

rollout CloverAI_Rollout "Clover AI" width:250 (
	imgTag logo "" bitmap:(try (openBitmap ((getDir #userIcons) + "\\CloverAI_logo48.png")) catch (undefined)) width:48 height:48 align:#center transparent:(color 0 0 0)
	button btnRender "렌더 실사화로 보내기" width:226 height:40
	label lb1 "지금 뷰포트 화면이 Clover AI로 가요" align:#center
	button btnRe "다시 연결" width:108 across:2
	button btnSite "사이트 열기" width:108
	on logo click do CloverAI_Send()
	on btnRender pressed do CloverAI_Send()
	on btnRe pressed do ( setINISetting CloverAI_Ini "Clover" "code" ""; CloverAI_Pair false )
	on btnSite pressed do shellLaunch "https://www.cloverai.kr" ""
)

macroScript CloverAI_Render category:"Clover AI" buttonText:"Clover AI 렌더" tooltip:"Clover AI 렌더 실사화로 보내기" icon:#("CloverAI", 1) (
	if CloverAI_Send == undefined then ( messageBox "Clover AI 스크립트를 한 번 다시 실행해 주세요." title:"Clover AI" ) else CloverAI_Send()
)
macroScript CloverAI_Window category:"Clover AI" buttonText:"Clover AI 창" tooltip:"Clover AI 창 열기" icon:#("CloverAI", 1) (
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
