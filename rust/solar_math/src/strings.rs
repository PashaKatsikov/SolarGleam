//! Encoded runtime value table.
//!
//! Endpoints, keys, User-Agent fragments, the web-view scripts, on-screen copy
//! and a few identifiers are kept XOR-masked with a per-index keystream. The
//! plaintext only appears in this source; the binary ships the masked bytes and
//! `sg_s5` returns the decoded bytes to the caller one entry at a time.
//!
//! This is a one-shot const scramble, not a runtime cipher: there is no key
//! schedule and nothing to "unlock".

/// Stable ids. Order must match `CoreStr` on the Dart side.
pub const ENDPOINT: i32 = 0;
pub const GCD_BASE: i32 = 1;
pub const RELAY_SECRET: i32 = 2;
pub const APPSFLYER_KEY: i32 = 3;
pub const FIREBASE_PROJECT: i32 = 4;
pub const UA_PRODUCT: i32 = 5;
pub const UA_PLATFORM_PREFIX: i32 = 6;
pub const UA_PLATFORM_SUFFIX: i32 = 7;
pub const UA_ENGINE: i32 = 8;
pub const UA_MOBILE_TOKEN: i32 = 9;
pub const SAFARI_VERSION: i32 = 10;
pub const SAFARI_TAIL: i32 = 11;
pub const NOTIFY_TITLE: i32 = 12;
pub const NOTIFY_SUBTITLE: i32 = 13;
pub const NOTIFY_ACCEPT: i32 = 14;
pub const NOTIFY_SKIP: i32 = 15;
pub const NOWIFI_TITLE: i32 = 16;
pub const NOWIFI_SUBTITLE: i32 = 17;
pub const RETRY: i32 = 18;
pub const NO_CONNECTION_YET: i32 = 19;
// Web-view scripts, applied one at a time.
pub const PORTAL_INSET_GUARD: i32 = 20;
pub const PORTAL_ZOOM_LOCK: i32 = 21;
pub const PORTAL_TAP_POLISH: i32 = 22;
pub const PORTAL_KEYBOARD_LIFT: i32 = 23;
pub const PORTAL_FOCUS_SCALE: i32 = 24;
pub const PORTAL_INLINE_MEDIA: i32 = 25;
// Identifiers and tuning, masked like everything else.
pub const APP_TITLE: i32 = 26;
pub const BUNDLE_ID: i32 = 27;
pub const IOS_STORE_ID: i32 = 28;
pub const APPLE_TEAM_ID: i32 = 29;
pub const PUSH_SNOOZE_SECONDS: i32 = 30;
pub const ORGANIC_RECHECK_SECONDS: i32 = 31;

/// Per-index keystream byte (SplitMix-style avalanche of the global index).
#[inline(always)]
const fn mask(g: u32) -> u8 {
    let mut x = g.wrapping_add(0x9E37_79B9);
    x ^= x >> 15;
    x = x.wrapping_mul(0x85EB_CA77);
    x ^= x >> 13;
    (x & 0xff) as u8
}

/// Scramble base for a string id, so equal substrings encode differently.
#[inline(always)]
const fn base_of(id: i32) -> u32 {
    (id as u32).wrapping_mul(0x0101_0193).wrapping_add(0x1234_5)
}

/// Compile-time XOR of `src` with the keystream at `base`.
const fn enc<const N: usize>(src: &[u8; N], id: i32) -> [u8; N] {
    let base = base_of(id);
    let mut out = [0u8; N];
    let mut i = 0;
    while i < N {
        out[i] = src[i] ^ mask(base.wrapping_add(i as u32));
        i += 1;
    }
    out
}

fn entry(id: i32) -> Option<&'static [u8]> {
    let bytes: &'static [u8] = match id {
        ENDPOINT => ENDPOINT_B,
        GCD_BASE => GCD_BASE_B,
        RELAY_SECRET => RELAY_SECRET_B,
        APPSFLYER_KEY => APPSFLYER_KEY_B,
        FIREBASE_PROJECT => FIREBASE_PROJECT_B,
        UA_PRODUCT => UA_PRODUCT_B,
        UA_PLATFORM_PREFIX => UA_PLATFORM_PREFIX_B,
        UA_PLATFORM_SUFFIX => UA_PLATFORM_SUFFIX_B,
        UA_ENGINE => UA_ENGINE_B,
        UA_MOBILE_TOKEN => UA_MOBILE_TOKEN_B,
        SAFARI_VERSION => SAFARI_VERSION_B,
        SAFARI_TAIL => SAFARI_TAIL_B,
        NOTIFY_TITLE => NOTIFY_TITLE_B,
        NOTIFY_SUBTITLE => NOTIFY_SUBTITLE_B,
        NOTIFY_ACCEPT => NOTIFY_ACCEPT_B,
        NOTIFY_SKIP => NOTIFY_SKIP_B,
        NOWIFI_TITLE => NOWIFI_TITLE_B,
        NOWIFI_SUBTITLE => NOWIFI_SUBTITLE_B,
        RETRY => RETRY_B,
        NO_CONNECTION_YET => NO_CONNECTION_YET_B,
        PORTAL_INSET_GUARD => PORTAL_INSET_GUARD_B,
        PORTAL_ZOOM_LOCK => PORTAL_ZOOM_LOCK_B,
        PORTAL_TAP_POLISH => PORTAL_TAP_POLISH_B,
        PORTAL_KEYBOARD_LIFT => PORTAL_KEYBOARD_LIFT_B,
        PORTAL_FOCUS_SCALE => PORTAL_FOCUS_SCALE_B,
        PORTAL_INLINE_MEDIA => PORTAL_INLINE_MEDIA_B,
        APP_TITLE => APP_TITLE_B,
        BUNDLE_ID => BUNDLE_ID_B,
        IOS_STORE_ID => IOS_STORE_ID_B,
        APPLE_TEAM_ID => APPLE_TEAM_ID_B,
        PUSH_SNOOZE_SECONDS => PUSH_SNOOZE_SECONDS_B,
        ORGANIC_RECHECK_SECONDS => ORGANIC_RECHECK_SECONDS_B,
        _ => return None,
    };
    Some(bytes)
}

/// Decoded byte length of string `id`, or 0 if unknown.
pub fn decoded_len(id: i32) -> usize {
    entry(id).map_or(0, <[u8]>::len)
}

/// Decodes string `id` into `out` (which must hold `decoded_len(id)` bytes).
/// Returns the number of bytes written.
pub fn decode(id: i32, out: &mut [u8]) -> usize {
    let Some(bytes) = entry(id) else { return 0 };
    if out.len() < bytes.len() {
        return 0;
    }
    let base = base_of(id);
    for (i, b) in bytes.iter().enumerate() {
        out[i] = b ^ mask(base.wrapping_add(i as u32));
    }
    bytes.len()
}

static ENDPOINT_B: &[u8] = &enc(b"https://solar-gleam.com/edge/sync", ENDPOINT);
static GCD_BASE_B: &[u8] =
    &enc(b"https://gcdsdk.appsflyer.com/install_data/v5.0/", GCD_BASE);
static RELAY_SECRET_B: &[u8] =
    &enc(b"uYuNdyh-JCgwo4ZQTfBP7nglUpvpxwC3wtNVjliGKNg", RELAY_SECRET);
static APPSFLYER_KEY_B: &[u8] = &enc(b"fC23ZwDv7CixWHzkSboGB7", APPSFLYER_KEY);
static FIREBASE_PROJECT_B: &[u8] = &enc(b"550276010584", FIREBASE_PROJECT);

static UA_PRODUCT_B: &[u8] = &enc(b"Mozilla/5.0", UA_PRODUCT);
static UA_PLATFORM_PREFIX_B: &[u8] =
    &enc(b"(iPhone; CPU iPhone OS", UA_PLATFORM_PREFIX);
static UA_PLATFORM_SUFFIX_B: &[u8] = &enc(b"like Mac OS X)", UA_PLATFORM_SUFFIX);
static UA_ENGINE_B: &[u8] =
    &enc(b"AppleWebKit/605.1.15 (KHTML, like Gecko)", UA_ENGINE);
static UA_MOBILE_TOKEN_B: &[u8] = &enc(b"Mobile/15E148", UA_MOBILE_TOKEN);
static SAFARI_VERSION_B: &[u8] = &enc(b"18.5", SAFARI_VERSION);
static SAFARI_TAIL_B: &[u8] = &enc(b"604.1", SAFARI_TAIL);

static NOTIFY_TITLE_B: &[u8] =
    &enc(b"ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS", NOTIFY_TITLE);
static NOTIFY_SUBTITLE_B: &[u8] =
    &enc(b"Stay tuned for special offers and rewards", NOTIFY_SUBTITLE);
static NOTIFY_ACCEPT_B: &[u8] = &enc(b"Accept", NOTIFY_ACCEPT);
static NOTIFY_SKIP_B: &[u8] = &enc(b"Skip", NOTIFY_SKIP);
static NOWIFI_TITLE_B: &[u8] = &enc(b"NO INTERNET CONNECTION", NOWIFI_TITLE);
static NOWIFI_SUBTITLE_B: &[u8] =
    &enc(b"Check your connection and try again", NOWIFI_SUBTITLE);
static RETRY_B: &[u8] = &enc(b"Retry", RETRY);
static NO_CONNECTION_YET_B: &[u8] = &enc(b"No connection yet", NO_CONNECTION_YET);

static PORTAL_INSET_GUARD_B: &[u8] = &enc(
    br#"(() => {
  const scope = window;
  if (scope.__sgInsetGuard) return;
  scope.__sgInsetGuard = true;
  const tag = 'sg-inset-layer';
  const css = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}'
  ].join('');
  const keyboardOpen = () => {
    const vv = scope.visualViewport;
    return !!vv && vv.height < scope.innerHeight * 0.75;
  };
  const apply = () => {
    if (keyboardOpen()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(meta);
    } else {
      const base = (meta.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.content = `${base}${base ? ', ' : ''}viewport-fit=contain`;
    }
    let layer = document.getElementById(tag);
    if (!layer) {
      layer = document.createElement('style');
      layer.id = tag;
      host.appendChild(layer);
    }
    layer.textContent = css;
  };
  const later = () => {
    scope.setTimeout(apply, 170);
    scope.setTimeout(apply, 640);
  };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const out = original.apply(this, args);
      later();
      return out;
    };
  });
  scope.addEventListener('popstate', later);
  apply();
  scope.setInterval(apply, 2900);
})();"#,
    PORTAL_INSET_GUARD,
);

static PORTAL_ZOOM_LOCK_B: &[u8] = &enc(
    br#"(() => {
  if (window.__sgZoomLock) return;
  window.__sgZoomLock = true;
  const pin = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    meta.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };
  pin();
  const block = (e) => { e.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((t) =>
    document.addEventListener(t, block, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTouch = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTouch <= 300) e.preventDefault();
    lastTouch = now;
  }, {passive: false});
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const out = original.apply(this, args);
      setTimeout(pin, 150);
      return out;
    };
  });
  window.addEventListener('popstate', () => setTimeout(pin, 150));
})();"#,
    PORTAL_ZOOM_LOCK,
);

static PORTAL_TAP_POLISH_B: &[u8] = &enc(
    br#"(() => {
  if (window.__sgTapPolish) return;
  window.__sgTapPolish = true;
  const layer = document.createElement('style');
  layer.id = 'sg-tap-polish';
  layer.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(layer);
})();"#,
    PORTAL_TAP_POLISH,
);

static PORTAL_KEYBOARD_LIFT_B: &[u8] = &enc(
    br#"(() => {
  if (window.__sgInputLift) return;
  window.__sgInputLift = true;
  var vv = window.visualViewport;
  if (!vv) return;
  var MARGIN = 10;
  var EPS = 2;
  var OPEN = 120;
  var lifted = null;   // element currently transformed
  var lift = 0;        // px of upward shift applied to `lifted`
  var timer = null;

  var editable = function(n){
    return !!n && typeof n.matches === 'function' &&
      n.matches('input, textarea, select, [contenteditable="true"]');
  };
  // Keyboard height: visualViewport shrinks while innerHeight stays full.
  var kbInset = function(){
    return Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
  };
  // Nearest position:fixed ancestor. Fixed containers live outside the scroll
  // flow, so scrollIntoView cannot move them; shifting that element with a
  // transform does. Falls back to <body>, which also carries its fixed
  // descendants once transformed.
  var carrierFor = function(el){
    var node = el;
    while (node && node.nodeType === 1 && node !== document.body) {
      if (getComputedStyle(node).position === 'fixed') return node;
      node = node.parentElement;
    }
    return document.body || document.documentElement;
  };
  var setLift = function(carrier, px){
    if (lifted && lifted !== carrier) {
      lifted.style.transform = '';
      lifted.style.transition = '';
    }
    lifted = carrier;
    lift = px;
    if (!carrier) return;
    carrier.style.transition = 'transform .2s ease-out';
    carrier.style.transform = px > 0 ? ('translateY(' + (-px) + 'px)') : '';
  };
  var clear = function(){
    if (lifted) { lifted.style.transform = ''; lifted.style.transition = ''; }
    lifted = null;
    lift = 0;
  };
  var compute = function(){
    if (kbInset() < OPEN) { clear(); return; }   // keyboard not really open
    var el = document.activeElement;
    if (!editable(el)) return;
    var carrier = carrierFor(el);
    // Shift already in effect on THIS carrier (0 if we switched carriers).
    var cur = (carrier === lifted) ? lift : 0;
    var rect = el.getBoundingClientRect();
    var top = vv.offsetTop;
    var kbTop = vv.offsetTop + vv.height;
    // Undo the current shift to reason about the real layout, so switching
    // fields recomputes from scratch instead of stacking shifts.
    var naturalBottom = rect.bottom + cur;
    var naturalTop = rect.top + cur;
    // Put the field bottom just above the keyboard...
    var desired = naturalBottom - (kbTop - MARGIN);
    if (desired < 0) desired = 0;
    // ...but not so far that the field top leaves the visible area.
    var maxLift = naturalTop - (top + MARGIN);
    if (maxLift < 0) maxLift = 0;
    if (desired > maxLift) desired = maxLift;
    if (Math.abs(desired - cur) > EPS) setLift(carrier, desired);
  };
  // Coalesce the burst of resize events that fires while the keyboard animates
  // into ONE settled computation. This is what stops the content from jumping
  // back and forth (most visible in landscape). A confirm pass runs after the
  // iOS native focus-scroll settles.
  var schedule = function(){
    if (timer) clearTimeout(timer);
    timer = setTimeout(function(){
      timer = null;
      compute();
      setTimeout(compute, 260);
    }, 90);
  };
  vv.addEventListener('resize', schedule);
  document.addEventListener('focusin', function(ev){
    if (editable(ev.target)) schedule();
  }, true);
  document.addEventListener('focusout', function(){
    setTimeout(function(){
      if (!editable(document.activeElement)) clear();
    }, 80);
  }, true);
})();"#,
    PORTAL_KEYBOARD_LIFT,
);

static PORTAL_FOCUS_SCALE_B: &[u8] = &enc(
    br#"(() => {
  if (window.__sgFocusScale) return;
  window.__sgFocusScale = true;
  const layer = document.createElement('style');
  layer.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(layer);
})();"#,
    PORTAL_FOCUS_SCALE,
);

static PORTAL_INLINE_MEDIA_B: &[u8] = &enc(
    br#"(() => {
  if (window.__sgInlineMedia) return;
  window.__sgInlineMedia = true;
  const wake = (video) => {
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    const attempt = video.play();
    if (attempt?.catch) attempt.catch(() => {});
  };
  const sweep = (node) => {
    if (node instanceof HTMLVideoElement) wake(node);
    node.querySelectorAll?.('video').forEach(wake);
  };
  sweep(document);
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach(sweep));
  }).observe(document.documentElement, {childList: true, subtree: true});
})();"#,
    PORTAL_INLINE_MEDIA,
);

// Identifiers that would otherwise sit as plain literals in the Dart binary,
// plus numeric tuning stored as decimal strings.
static APP_TITLE_B: &[u8] = &enc(b"Solar Gleam", APP_TITLE);
static BUNDLE_ID_B: &[u8] = &enc(b"com.solargleam.gleamgame", BUNDLE_ID);
static IOS_STORE_ID_B: &[u8] = &enc(b"6817300726", IOS_STORE_ID);
static APPLE_TEAM_ID_B: &[u8] = &enc(b"48UP4UDWV7", APPLE_TEAM_ID);
static PUSH_SNOOZE_SECONDS_B: &[u8] = &enc(b"259189", PUSH_SNOOZE_SECONDS);
static ORGANIC_RECHECK_SECONDS_B: &[u8] = &enc(b"8", ORGANIC_RECHECK_SECONDS);

#[cfg(test)]
mod tests {
    use super::*;

    fn text(id: i32) -> String {
        let mut buf = vec![0u8; decoded_len(id)];
        let n = decode(id, &mut buf);
        String::from_utf8(buf[..n].to_vec()).unwrap()
    }

    #[test]
    fn round_trips_known_strings() {
        assert_eq!(text(ENDPOINT), "https://solar-gleam.com/edge/sync");
        assert_eq!(text(UA_PRODUCT), "Mozilla/5.0");
        assert_eq!(text(FIREBASE_PROJECT), "550276010584");
        assert_eq!(text(NOWIFI_TITLE), "NO INTERNET CONNECTION");
        assert!(text(PORTAL_INSET_GUARD).contains("__sgInsetGuard"));
        assert!(text(PORTAL_KEYBOARD_LIFT).contains("translateY"));
        assert!(text(PORTAL_ZOOM_LOCK).contains("__sgZoomLock"));
        assert!(text(PORTAL_INLINE_MEDIA).contains("playsinline"));
        assert_eq!(text(BUNDLE_ID), "com.solargleam.gleamgame");
        assert_eq!(text(IOS_STORE_ID), "6817300726");
        assert_eq!(text(PUSH_SNOOZE_SECONDS), "259189");
        assert_eq!(text(ORGANIC_RECHECK_SECONDS), "8");
        assert_eq!(decoded_len(9999), 0);
    }
}
