(() => {
  const REPO = 'makikub/screenshot-light-app';
  const API_URL = `https://api.github.com/repos/${REPO}/releases/latest`;

  const formatDate = (iso) => {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const showVersion = (version, dateStr) => {
    const el = document.getElementById('version-info');
    if (!el) return;
    el.textContent = dateStr
      ? `最新版 ${version} — ${dateStr} リリース`
      : `最新版 ${version}`;
  };

  fetch(API_URL, { headers: { Accept: 'application/vnd.github+json' } })
    .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
    .then((data) => {
      const version = data.tag_name || '';
      const dateStr = data.published_at ? formatDate(data.published_at) : null;
      if (version) showVersion(version, dateStr);
    })
    .catch(() => {
      // フォールバック: 「最新版」表示のまま (HTML 初期値) を維持
    });
})();
