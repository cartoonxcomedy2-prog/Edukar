// ============ API CONFIG ============
const API_BASE = (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') ? 'http://localhost:5000' : 'https://supadmin.edukar.info/api';
const SESSION_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const getApiBase = () => localStorage.getItem('st_api_base') || API_BASE;

function getToken() {
    var token = localStorage.getItem('st_token');
    if (!token) return '';
    // Check session expiry
    var loginAt = parseInt(localStorage.getItem('st_login_at') || '0', 10);
    if (loginAt && (Date.now() - loginAt) > SESSION_MAX_AGE_MS) {
        // Session expired — clear everything
        localStorage.removeItem('st_token');
        localStorage.removeItem('st_user');
        localStorage.removeItem('st_login_at');
        return '';
    }
    return token;
}

const getUser = () => { try { return JSON.parse(localStorage.getItem('st_user') || 'null'); } catch { return null; } };
const setUser = (u) => {
    if (!u) { localStorage.removeItem('st_user'); return; }
    // Never persist the JWT token inside the cached user object
    var safe = Object.assign({}, u);
    delete safe.token;
    delete safe.password;
    localStorage.setItem('st_user', JSON.stringify(safe));
};
const isLoggedIn = () => !!getToken();

// Save login timestamp (call this when user logs in or registers)
function saveLoginTimestamp() {
    localStorage.setItem('st_login_at', String(Date.now()));
}

// HTML escape — prevent XSS from server-supplied content injected via innerHTML
function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

function resolveAsset(val) {
    if (!val) return '';
    const s = val.toString().trim();
    if (s.startsWith('http')) return s;
    if (s.startsWith('data:')) return s;
    const base = getApiBase().replace(/\/+$/, '');
    let p = s;
    if (p.includes('uploads/')) p = p.split('uploads/').pop();
    if (p.startsWith('/')) p = p.slice(1);
    
    // If base already contains /api, we can just append /uploads since backend has app.use('/api/uploads', ...)
    return `${base}/uploads/${p}`;
}

async function apiFetch(path, opts = {}) {
    const base = getApiBase().replace(/\/+$/, '');
    const url = `${base}/${path.replace(/^\/+/, '')}`;
    const headers = { ...(opts.headers || {}) };
    const token = getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (!(opts.body instanceof FormData) && opts.body && typeof opts.body === 'object') {
        headers['Content-Type'] = 'application/json';
        opts.body = JSON.stringify(opts.body);
    }
    const res = await fetch(url, { ...opts, headers });
    var isAuthPage = window.location.pathname.includes('login') || window.location.pathname.includes('register');
    if (res.status === 401 && !isAuthPage) { logout(); return null; }
    return res;
}

function logout() {
    localStorage.removeItem('st_token');
    localStorage.removeItem('st_user');
    localStorage.removeItem('st_login_at');
    // Clear all session/cache data
    sessionStorage.clear();
    if (!window.location.pathname.includes('login')) {
        window.location.href = 'login.html';
    }
}

function requireAuth() {
    if (!isLoggedIn()) {
        // Hide page content immediately to prevent flash of dashboard before redirect
        document.body.style.visibility = 'hidden';
        document.body.style.opacity = '0';
        window.location.href = 'login.html';
        return false;
    }
    return true;
}

function formatDate(d) {
    if (!d) return 'N/A';
    try { const dt = new Date(d); var dd = String(dt.getDate()).padStart(2,'0'); var mm = String(dt.getMonth()+1).padStart(2,'0'); var yy = dt.getFullYear(); return dd + '/' + mm + '/' + yy; } catch { return d; }
}

function showToast(msg, type = 'success') {
    const t = document.createElement('div');
    t.className = `toast toast--${type}`;
    t.textContent = msg;
    document.body.appendChild(t);
    requestAnimationFrame(() => t.classList.add('show'));
    setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 400); }, 3000);
}

function truncate(str, len = 120) {
    if (!str) return '';
    return str.length > len ? str.slice(0, len) + '...' : str;
}

// Success sound — pleasant chime using Web Audio API (no external files needed)
function playSuccessSound() {
    try {
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        // First tone
        var o1 = ctx.createOscillator();
        var g1 = ctx.createGain();
        o1.type = 'sine';
        o1.frequency.setValueAtTime(800, ctx.currentTime);
        o1.frequency.setValueAtTime(1200, ctx.currentTime + 0.1);
        g1.gain.setValueAtTime(0.3, ctx.currentTime);
        g1.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.4);
        o1.connect(g1); g1.connect(ctx.destination);
        o1.start(ctx.currentTime); o1.stop(ctx.currentTime + 0.4);
        // Second tone (harmony)
        var o2 = ctx.createOscillator();
        var g2 = ctx.createGain();
        o2.type = 'sine';
        o2.frequency.setValueAtTime(1000, ctx.currentTime + 0.1);
        o2.frequency.setValueAtTime(1600, ctx.currentTime + 0.2);
        g2.gain.setValueAtTime(0.2, ctx.currentTime + 0.1);
        g2.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
        o2.connect(g2); g2.connect(ctx.destination);
        o2.start(ctx.currentTime + 0.1); o2.stop(ctx.currentTime + 0.5);
    } catch(e) { /* Audio not supported */ }
}

// Download a document via the backend API (proper format + MIME handling)
async function downloadDocument(appId, field, filename, universityId) {
    if (!appId || !field) { showToast('File not available', 'error'); return; }
    try {
        var params = 'downloadName=' + encodeURIComponent(filename || 'document');
        if (universityId) params += '&universityId=' + encodeURIComponent(universityId);
        var res = await apiFetch('applications/' + appId + '/download-doc/' + field + '?' + params);
        if (!res || !res.ok) throw new Error('Download failed');
        var blob = await res.blob();
        var safeName = (filename || 'document').replace(/[^a-zA-Z0-9._-]/g, '-');
        if (!/\.\w{2,5}$/.test(safeName)) safeName += '.pdf';
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = safeName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function() { URL.revokeObjectURL(a.href); }, 1000);
        showToast('Downloaded!');
    } catch(e) {
        console.error('Download error:', e);
        showToast('Download failed', 'error');
    }
}

// Download an education document via the secure backend API
async function downloadEduDocument(userId, section, field, filename) {
    if (!userId || !section || !field) { showToast('File not available', 'error'); return; }
    try {
        var params = 'downloadName=' + encodeURIComponent(filename || 'document');
        var res = await apiFetch('users/' + userId + '/education/' + section + '/' + field + '/download?' + params);
        if (!res || !res.ok) throw new Error('Download failed');
        var blob = await res.blob();
        var safeName = (filename || 'document').replace(/[^a-zA-Z0-9._-]/g, '-');
        if (!/\.\w{2,5}$/.test(safeName)) safeName += '.pdf';
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = safeName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function() { URL.revokeObjectURL(a.href); }, 1000);
        showToast('Downloaded!');
    } catch(e) {
        console.error('Download error:', e);
        showToast('Download failed', 'error');
    }
}
