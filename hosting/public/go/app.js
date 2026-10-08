(function () {
  const links = window.BRAIN_RUSH_STORE_LINKS || {};
  const valid = (raw) => {
    try {
      const url = new URL(raw);
      return url.protocol === 'https:' && url.hostname ? url.href : null;
    } catch (_) {
      return null;
    }
  };
  const appStore = valid(links.APP_STORE_URL);
  const playStore = valid(links.PLAY_STORE_URL);
  const agent = navigator.userAgent || '';
  const appleMobile = /iPhone|iPad|iPod/i.test(agent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const android = /Android/i.test(agent);

  if (appleMobile && appStore) {
    window.location.replace(appStore);
  } else if (android && playStore) {
    window.location.replace(playStore);
  }

  const showButton = (id, url) => {
    if (!url) return;
    const button = document.getElementById(id);
    button.href = url;
    button.hidden = false;
    button.rel = 'noreferrer noopener';
    document.getElementById('store-buttons').hidden = false;
  };
  showButton('app-store-button', appStore);
  showButton('play-store-button', playStore);
})();
