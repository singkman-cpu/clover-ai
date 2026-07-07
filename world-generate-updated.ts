// Supabase Edge Function: world-generate
// 역할: 이미지를 받아서 World Labs(Marble) API로 3D World 생성을 요청하고,
//       진행상태를 polling할 수 있게 중계해주는 함수.
// 클라이언트(브라우저)는 WORLDLABS_API_KEY를 절대 직접 갖고 있지 않음 — 항상 이 서버를 거침.
//
// [업데이트] 이미지 1장짜리 단일 프롬프트 외에, 여러 각도 이미지를 azimuth(방향)와 함께
// 보내는 multi-image 방식을 추가함. World Labs 공식 문서 기준:
//   world_prompt.type = 'multi-image'
//   world_prompt.multi_image_prompt = [{ azimuth: 0, content: {source:'media_asset', media_asset_id} }, ...]
//   reconstruct_images: true  → "같은 공간을 여러 각도에서 찍은 사진들"을 복원 모드로 처리 (최대 8장)
// 이미지 1장만 오면 기존처럼 image_prompt(type:'image') 방식을 그대로 사용함 (하위 호환).

const BASE_URL = 'https://api.worldlabs.ai/marble/v1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonRes(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// 원본 이미지 URL 하나를 받아서, World Labs storage에 업로드하고 media_asset_id를 반환
async function uploadImageToWorldLabs(apiKey: string, imageUrl: string): Promise<string> {
  const imgRes = await fetch(imageUrl);
  if (!imgRes.ok) {
    throw new Error('원본 이미지를 가져오지 못했습니다: ' + imageUrl);
  }
  const imgBlob = await imgRes.blob();
  const contentType = imgRes.headers.get('content-type') || 'image/jpeg';
  const ext = contentType.includes('png') ? 'png' : 'jpg';

  const prepRes = await fetch(`${BASE_URL}/media-assets:prepare_upload`, {
    method: 'POST',
    headers: { 'WLT-Api-Key': apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ file_name: `cloverai.${ext}`, extension: ext, kind: 'image' }),
  });
  if (!prepRes.ok) {
    const t = await prepRes.text();
    throw new Error('업로드 준비 실패: ' + t);
  }
  const prepData = await prepRes.json();
  const mediaAssetId = prepData.media_asset.media_asset_id;
  const uploadUrl = prepData.upload_info.upload_url;
  const requiredHeaders = prepData.upload_info.required_headers || {};

  const putRes = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': contentType, ...requiredHeaders },
    body: imgBlob,
  });
  if (!putRes.ok) {
    const t = await putRes.text();
    throw new Error('이미지 업로드 실패: ' + t);
  }

  return mediaAssetId;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const apiKey = Deno.env.get('WORLDLABS_API_KEY') || '';
  if (!apiKey) {
    return jsonRes({ error: 'WORLDLABS_API_KEY가 서버에 설정되어 있지 않습니다.' }, 500);
  }

  try {
    const body = await req.json();
    const action = body.action;

    // ── 1) 이미지 업로드 + 월드 생성 요청 시작 ──────────────────────
    if (action === 'submit') {
      const { imageUrl, imageUrls, model, displayName, isPano, reconstructImages, textPrompt } = body;

      // imageUrls: [{ url, azimuth }, ...] 형태면 멀티 이미지(여러 각도) 모드
      const isMulti = Array.isArray(imageUrls) && imageUrls.length > 0;

      if (!isMulti && !imageUrl) {
        return jsonRes({ error: 'imageUrl 또는 imageUrls가 필요합니다.' }, 400);
      }

      let worldPrompt: Record<string, unknown>;

      if (isMulti) {
        if (imageUrls.length > 8) {
          return jsonRes({ error: '이미지는 최대 8장까지 지원됩니다.' }, 400);
        }
        // 이미지들을 순서대로(직렬로) 업로드 — 병렬로 하면 World Labs 쪽 rate limit에 걸릴 수 있어 안전하게 순차 처리
        const mediaAssetIds: string[] = [];
        for (const item of imageUrls) {
          const id = await uploadImageToWorldLabs(apiKey, item.url);
          mediaAssetIds.push(id);
        }
        worldPrompt = {
          type: 'multi-image',
          // reconstructImages: 같은 공간을 여러 각도에서 찍은/생성한 사진이면 true(복원 모드),
          // 서로 다른 실제 공간(거실/침실/주방 등)을 자연스럽게 이어붙이는 경우는 false(창의적 연결 모드).
          // 클라이언트가 명시하지 않으면 true를 기본값으로 둠(기존 좌/우/뒤 단일 공간 모드와의 하위 호환).
          reconstruct_images: reconstructImages !== false,
          multi_image_prompt: imageUrls.map((item: { url: string; azimuth?: number }, i: number) => ({
            azimuth: typeof item.azimuth === 'number' ? item.azimuth : 0,
            content: { source: 'media_asset', media_asset_id: mediaAssetIds[i] },
          })),
          ...(textPrompt ? { text_prompt: textPrompt } : {}),
        };
      } else {
        const mediaAssetId = await uploadImageToWorldLabs(apiKey, imageUrl);
        worldPrompt = {
          type: 'image',
          image_prompt: {
            source: 'media_asset',
            media_asset_id: mediaAssetId,
            ...(isPano ? { is_pano: true } : {}),
          },
        };
      }

      // 월드 생성 요청
      const genRes = await fetch(`${BASE_URL}/worlds:generate`, {
        method: 'POST',
        headers: { 'WLT-Api-Key': apiKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          display_name: displayName || 'CloverAI 3D Tour',
          model: model || 'marble-1.1', // 표준 모델 고정가(1,500 크레딧)
          world_prompt: worldPrompt,
          // public: true로 설정해야 로그인 없이 누구나(임베드 포함) 결과를 볼 수 있음
          permission: { public: true },
        }),
      });
      if (!genRes.ok) {
        const t = await genRes.text();
        return jsonRes({ error: '월드 생성 요청 실패: ' + t }, genRes.status);
      }
      const genData = await genRes.json();
      return jsonRes({ operation_id: genData.operation_id });
    }

    // ── 2) 진행상태 확인(polling) ────────────────────────────────
    if (action === 'status') {
      const { operationId } = body;
      if (!operationId) {
        return jsonRes({ error: 'operationId가 필요합니다.' }, 400);
      }
      const opRes = await fetch(`${BASE_URL}/operations/${operationId}`, {
        headers: { 'WLT-Api-Key': apiKey },
      });
      if (!opRes.ok) {
        const t = await opRes.text();
        return jsonRes({ error: '상태 조회 실패: ' + t }, opRes.status);
      }
      const opData = await opRes.json();
      return jsonRes(opData);
    }

    // ── 3) 남은 크레딧 확인 ──────────────────────────────────────
    if (action === 'credits') {
      const crRes = await fetch(`${BASE_URL}/credits`, { headers: { 'WLT-Api-Key': apiKey } });
      const crData = await crRes.json();
      return jsonRes(crData, crRes.status);
    }

    return jsonRes({ error: '알 수 없는 action 입니다. (submit / status / credits 중 하나여야 함)' }, 400);
  } catch (e) {
    return jsonRes({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
