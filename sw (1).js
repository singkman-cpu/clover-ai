// CLOVER AI 서비스워커 — 기본 캐싱(오프라인에서도 최소한의 화면이 보이게)
const CACHE_NAME = 'cloverai-v1';
const PRECACHE = ['/'];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// 네트워크 우선, 실패하면 캐시 (항상 최신 사이트를 보여주되, 오프라인일 때만 캐시 사용)
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;

  // ⚠️ 버그 수정("로드뷰가 방향으로 움직이다가 갑자기 더 안 간다"): 원인은 카카오 로드뷰가
  // map3.daumcdn.net에서 불러오는 큐브맵 타일/depthmap 이미지들(다른 도메인 리소스)까지 이
  // 서비스워커가 전부 가로채서 fetch(e.request)로 재요청하고 있었기 때문 — 콘솔에 "blocked by
  // CORS policy" 에러가 나면서 새 위치의 파노라마 타일 로딩이 실패해, panoId는 바뀌는데 화면은
  // 안 바뀌어 "더 이상 이동이 안 되는 것"처럼 보였음. 서비스워커는 우리 사이트(같은 origin) 파일만
  // 캐싱하면 되고, 카카오맵·fal.media 같은 다른 도메인 리소스는 서비스워커를 거치지 않고 브라우저가
  // 원래 하던 방식(예: crossOrigin 모드) 그대로 직접 요청하게 둬야 CORS가 안 깨짐 — 그래서 다른
  // 도메인 요청은 아래에서 그냥 return해서 이 서비스워커가 손대지 않고 지나가게 함.
  if (new URL(e.request.url).origin !== self.location.origin) return;

  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const resClone = res.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(e.request, resClone));
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
