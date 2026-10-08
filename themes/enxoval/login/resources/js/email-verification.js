(() => {
  const panel = document.getElementById('enxoval-email-verification');
  if (!panel) return;

  // Re-enter the current required action without submitting the resend action.
  const checkUrl = new URL(panel.dataset.checkUrl, window.location.href);
  if (checkUrl.origin !== window.location.origin) return;
  checkUrl.searchParams.delete('session_code');
  document.getElementById('enxoval-email-continue').href = checkUrl.href;

  let stopped = false;
  let timer;
  let controller;
  const deadline = Date.now() + 15 * 60 * 1000;

  function stop() {
    stopped = true;
    clearTimeout(timer);
    controller?.abort();
  }

  async function check() {
    if (stopped || Date.now() >= deadline) return;
    controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      // Do not follow the OAuth callback in fetch: the browser must navigate
      // through it so the adapter can validate state and exchange the code.
      const response = await fetch(checkUrl, {
        credentials: 'same-origin',
        cache: 'no-store',
        redirect: 'manual',
        signal: controller.signal,
      });
      if (stopped) return;
      if (response.type === 'opaqueredirect') {
        stop();
        window.location.assign(checkUrl.href);
        return;
      }
      if (response.ok) {
        const html = new DOMParser().parseFromString(await response.text(), 'text/html');
        if (!html.getElementById('enxoval-email-verification')) {
          stop();
          window.location.assign(checkUrl.href);
          return;
        }
      }
    } catch {
      // A temporary network failure must not interrupt confirmation or resend.
    } finally {
      clearTimeout(timeout);
      if (!stopped) timer = setTimeout(check, 5000);
    }
  }

  window.addEventListener('pagehide', stop, { once: true });
  document.addEventListener('submit', stop, { once: true });
  document.addEventListener('click', (event) => {
    if (event.target.closest('a')) stop();
  });
  timer = setTimeout(check, 5000);
})();
