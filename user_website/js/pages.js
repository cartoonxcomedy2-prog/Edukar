// pages.js - Page init functions for all interior pages

// Shared: get user applications to check status on cards
var userApplications = [];
async function loadUserApps() {
    try {
        var res = await apiFetch('users/profile');
        var data = res ? await res.json() : {};
        userApplications = data.applications || [];
        setUser(data); // update cached user
    } catch(e) { userApplications = []; }
}

function getAppStatus(type, entityId) {
    // Returns { status, appId } or null
    for (var i = 0; i < userApplications.length; i++) {
        var app = userApplications[i];
        if ((app.type || '').toLowerCase() !== type.toLowerCase()) continue;
        var isReapply = app.isReapplyEligible === true || String(app.isReapplyEligible).toLowerCase() === 'true';
        if (isReapply) continue;
        var entity = type.toLowerCase() === 'university' ? app.university : app.scholarship;
        if (entity && entity._id === entityId) {
            return { status: (app.status || 'Applied').toLowerCase(), appId: app._id };
        }
    }
    return null;
}

function cardStatusBadge(type, entityId, isClosed) {
    var badgeStyle = 'position:absolute; top:10px; right:10px; padding:5px 12px; border-radius:8px; font-size:11px; font-weight:800; display:flex; align-items:center; gap:4px; z-index:2; box-shadow:0 2px 8px rgba(0,0,0,.2);';
    var app = getAppStatus(type, entityId);
    if (app) {
        var s = app.status;
        if (s.includes('selected') || s.includes('approved')) {
            return '<span style="' + badgeStyle + 'background:#10B981; color:#fff;">Selected <i class="fas fa-check-circle"></i></span>';
        }
        if (s.includes('rejected')) {
            return '<span style="' + badgeStyle + 'background:#EF4444; color:#fff;">Rejected <i class="fas fa-times-circle"></i></span>';
        }
        return '<span style="' + badgeStyle + 'background:#3B82F6; color:#fff;">Applied <i class="fas fa-clock"></i></span>';
    }
    if (isClosed) {
        return '<span style="' + badgeStyle + 'background:rgba(0,0,0,.6); color:#fff;">Closed <i class="fas fa-lock"></i></span>';
    }
    return '<span style="' + badgeStyle + 'background:#F97316; color:#fff;">Apply Now <i class="fas fa-paper-plane"></i></span>';
}

// ============ UNIVERSITIES PAGE ============
function initUniversitiesPage() {
    if (!isLoggedIn()) return window.location.href = 'login.html';
    initPage('universities');
    var allUnis = [], filteredUnis = [], uniShown = 0, UNI_BATCH = parseInt(sessionStorage.getItem('st_uni_batch')) || 6;
    async function load() {
        // Restore from cache instantly so back-navigation is fast
        try {
            var cached = sessionStorage.getItem('st_uni_data');
            if (cached) {
                allUnis = JSON.parse(cached);
                filteredUnis = allUnis;
                uniShown = 0;
                renderUnis();
                var savedScroll = sessionStorage.getItem('st_uni_scroll');
                if (savedScroll) {
                    setTimeout(function() { window.scrollTo(0, parseInt(savedScroll)); }, 50);
                    sessionStorage.removeItem('st_uni_scroll');
                }
            }
        } catch(ce) {}
        // Fetch fresh in background
        try {
            var [_, res] = await Promise.all([
                loadUserApps(),
                apiFetch('universities')
            ]);
            var fresh = res ? await res.json() : [];
            if (!Array.isArray(fresh)) fresh = [];
            sessionStorage.setItem('st_uni_data', JSON.stringify(fresh));
            if (JSON.stringify(fresh) !== JSON.stringify(allUnis)) {
                allUnis = fresh;
                filteredUnis = allUnis;
                uniShown = 0;
                renderUnis();
            }
        } catch(e) { console.error(e); }
    }
    function renderUnis() {
        var grid = document.getElementById('uniGrid');
        if (!filteredUnis.length) { grid.innerHTML = '<div class="empty-state"><div class="empty-state__icon">🏫</div><div class="empty-state__title">No universities found</div></div>'; return; }
        var end = Math.min(uniShown + UNI_BATCH, filteredUnis.length);
        var batch = filteredUnis.slice(uniShown, end);
        if (uniShown === 0) grid.innerHTML = '';
        grid.querySelectorAll('.load-more-wrap').forEach(function(el) { el.remove(); });
        grid.innerHTML += batch.map(function(u) {
            var fee = u.applicationFee || u.applicationFees || '';
            var feeDisplay = fee && fee !== '0' ? (u.currency||'') + ' ' + fee : 'Free';
            var deadline = u.deadline ? new Date(u.deadline) : null;
            var isClosed = !(u.isActive !== false) || (deadline && deadline < new Date());
            var badge = cardStatusBadge('University', u._id, isClosed);
            return '<a href="university-detail?id=' + u._id + '" class="st-card fade-in visible" style="text-decoration:none;" onclick="sessionStorage.setItem(\'st_uni_scroll\', window.scrollY)">' +
                '<div class="st-card__img" style="position:relative;">' + badge + '<img src="' + resolveAsset(u.thumbnail||u.logo) + '" alt="' + (u.name||'') + '" onerror="this.style.display=\'none\'; this.parentElement.style.background=\'linear-gradient(135deg, var(--primary), var(--accent))\'"></div>' +
                '<div class="st-card__body">' +
                    '<span class="st-card__tag">' + (u.universityType||u.type||'University') + '</span>' +
                    '<h3 class="st-card__title">' + (u.name||'') + '</h3>' +
                    '<div class="st-card__info"><i class="fas fa-map-marker-alt" style="color:#6366F1;"></i> ' + ([u.city, u.country].filter(Boolean).join(', ') || 'N/A') + '</div>' +
                    '<div class="st-card__info st-card__deadline"><i class="fas fa-calendar-alt"></i> Deadline: ' + formatDate(u.deadline) + '</div>' +
                    '<div class="st-card__info st-card__fee"><i class="fas fa-money-bill-wave"></i> Application Fee: ' + feeDisplay + '</div>' +
                '</div></a>';
        }).join('');
        uniShown = end;
        sessionStorage.setItem('st_uni_batch', Math.max(uniShown, 6));
        if (uniShown < filteredUnis.length) {
            grid.innerHTML += '<div class="load-more-wrap" style="grid-column:1/-1; text-align:center; padding:16px;"><button class="btn btn--outline" id="uniLoadMore" style="padding:12px 40px; font-size:14px; font-weight:700; border-radius:12px;"><i class="fas fa-plus" style="margin-right:6px;"></i>Load More (' + (filteredUnis.length - uniShown) + ' remaining)</button></div>';
            document.getElementById('uniLoadMore').addEventListener('click', function() { UNI_BATCH = 3; renderUnis(); });
        }
    }
    document.getElementById('searchInput').addEventListener('input', function(e) {
        var q = e.target.value.toLowerCase().trim();
        filteredUnis = q ? allUnis.filter(function(u) { return (u.name||'').toLowerCase().includes(q) || (u.city||'').toLowerCase().includes(q) || (u.country||'').toLowerCase().includes(q); }) : allUnis;
        uniShown = 0; UNI_BATCH = 6; renderUnis();
    });
    load();
}

// ============ SCHOLARSHIPS PAGE ============
function initScholarshipsPage() {
    if (!isLoggedIn()) return window.location.href = 'login.html';
    initPage('scholarships');
    var allSchs = [], filteredSchs = [], schShown = 0, SCH_BATCH = parseInt(sessionStorage.getItem('st_sch_batch')) || 6;
    async function load() {
        // Restore from cache instantly so back-navigation is fast
        try {
            var cached = sessionStorage.getItem('st_sch_data');
            if (cached) {
                allSchs = JSON.parse(cached);
                filteredSchs = allSchs;
                schShown = 0;
                renderSchs();
                var savedScroll = sessionStorage.getItem('st_sch_scroll');
                if (savedScroll) {
                    setTimeout(function() { window.scrollTo(0, parseInt(savedScroll)); }, 50);
                    sessionStorage.removeItem('st_sch_scroll');
                }
            }
        } catch(ce) {}
        // Fetch fresh in background
        try {
            var [_, res] = await Promise.all([
                loadUserApps(),
                apiFetch('scholarships')
            ]);
            var fresh = res ? await res.json() : [];
            if (!Array.isArray(fresh)) fresh = [];
            sessionStorage.setItem('st_sch_data', JSON.stringify(fresh));
            if (JSON.stringify(fresh) !== JSON.stringify(allSchs)) {
                allSchs = fresh;
                filteredSchs = allSchs;
                schShown = 0;
                renderSchs();
            }
        } catch(e) { console.error(e); }
    }
    function renderSchs() {
        var grid = document.getElementById('schGrid');
        if (!filteredSchs.length) { grid.innerHTML = '<div class="empty-state"><div class="empty-state__icon">🏆</div><div class="empty-state__title">No scholarships found</div></div>'; return; }
        var end = Math.min(schShown + SCH_BATCH, filteredSchs.length);
        var batch = filteredSchs.slice(schShown, end);
        if (schShown === 0) grid.innerHTML = '';
        grid.querySelectorAll('.load-more-wrap').forEach(function(el) { el.remove(); });
        grid.innerHTML += batch.map(function(s) {
            var amt = s.amount || '';
            var amtDisplay = amt ? (s.currency||'') + ' ' + amt : 'Contact for details';
            var deadline = s.deadline ? new Date(s.deadline) : null;
            var isClosed = !(s.isActive !== false) || (deadline && deadline < new Date());
            var badge = cardStatusBadge('Scholarship', s._id, isClosed);
            return '<a href="scholarship-detail?id=' + s._id + '" class="st-card fade-in visible" style="text-decoration:none;" onclick="sessionStorage.setItem(\'st_sch_scroll\', window.scrollY)">' +
                '<div class="st-card__img" style="position:relative;">' + badge + '<img src="' + resolveAsset(s.image||s.thumbnail) + '" alt="' + (s.title||'') + '" onerror="this.style.display=\'none\'; this.parentElement.style.background=\'linear-gradient(135deg, var(--orange), var(--primary))\'"></div>' +
                '<div class="st-card__body">' +
                    '<span class="st-card__tag" style="background:#FFF7ED; color:var(--orange);">' + (s.type||'Scholarship') + '</span>' +
                    '<h3 class="st-card__title">' + (s.title||'') + '</h3>' +
                    '<div class="st-card__info"><i class="fas fa-map-marker-alt" style="color:#6366F1;"></i> ' + ([s.city, s.country].filter(Boolean).join(', ') || 'N/A') + '</div>' +
                    '<div class="st-card__info st-card__deadline"><i class="fas fa-calendar-alt"></i> Deadline: ' + formatDate(s.deadline) + '</div>' +
                    '<div class="st-card__info st-card__fee"><i class="fas fa-coins"></i> Scholarship Amount: ' + amtDisplay + '</div>' +
                '</div></a>';
        }).join('');
        schShown = end;
        sessionStorage.setItem('st_sch_batch', Math.max(schShown, 6));
        if (schShown < filteredSchs.length) {
            grid.innerHTML += '<div class="load-more-wrap" style="grid-column:1/-1; text-align:center; padding:16px;"><button class="btn btn--outline" id="schLoadMore" style="padding:12px 40px; font-size:14px; font-weight:700; border-radius:12px;"><i class="fas fa-plus" style="margin-right:6px;"></i>Load More (' + (filteredSchs.length - schShown) + ' remaining)</button></div>';
            document.getElementById('schLoadMore').addEventListener('click', function() { SCH_BATCH = 3; renderSchs(); });
        }
    }
    document.getElementById('searchInput').addEventListener('input', function(e) {
        var q = e.target.value.toLowerCase().trim();
        filteredSchs = q ? allSchs.filter(function(s) { return (s.title||'').toLowerCase().includes(q) || (s.city||'').toLowerCase().includes(q); }) : allSchs;
        schShown = 0; SCH_BATCH = 6; renderSchs();
    });
    load();
}

// ============ NOTIFICATIONS PAGE ============
function initNotificationsPage() {
    initPage('notifications');
    var notifications = [], notifShown = 0, NOTIF_BATCH = parseInt(sessionStorage.getItem('st_notif_batch')) || 10;

    function timeAgo(d) {
        if (!d) return '';
        var diff = Date.now() - new Date(d).getTime();
        var mins = Math.floor(diff / 60000);
        if (mins < 1) return 'Just now';
        if (mins < 60) return mins + 'm ago';
        var hrs = Math.floor(mins / 60);
        if (hrs < 24) return hrs + 'h ago';
        var days = Math.floor(hrs / 24);
        if (days < 7) return days + 'd ago';
        return formatDate(d);
    }

    function statusColor(s) {
        var l = (s || '').toLowerCase();
        if (l.includes('admit')) return '#7C3AED';
        if (l.includes('offer')) return '#0F766E';
        if (l.includes('applied')) return '#0EA5E9';
        if (l.includes('selected') || l.includes('approved')) return '#10B981';
        if (l.includes('rejected')) return '#EF4444';
        if (l.includes('interview') || l.includes('test')) return '#F59E0B';
        if (l.includes('closing') || l.includes('deadline')) return '#EA580C';
        return '#3B82F6';
    }

    function entityIcon(type) {
        var t = (type || '').toLowerCase();
        if (t === 'university') return '<i class="fas fa-university" style="font-size:18px; color:var(--slate-400);"></i>';
        if (t === 'scholarship') return '<i class="fas fa-award" style="font-size:18px; color:var(--slate-400);"></i>';
        return '<i class="fas fa-bell" style="font-size:18px; color:var(--slate-400);"></i>';
    }

    async function load() {
        // Restore from cache instantly
        try {
            var cached = sessionStorage.getItem('st_notif_data');
            if (cached) {
                notifications = JSON.parse(cached);
                notifShown = 0;
                renderNotifs();
                var savedScroll = sessionStorage.getItem('st_notif_scroll');
                if (savedScroll) {
                    setTimeout(function() { window.scrollTo(0, parseInt(savedScroll)); }, 50);
                    sessionStorage.removeItem('st_notif_scroll');
                }
            }
        } catch(ce) {}
        // Fetch fresh in background
        try {
            var res = await apiFetch('users/profile');
            var data = res ? await res.json() : {};
            var fresh = Array.isArray(data.notifications) ? data.notifications : [];
            sessionStorage.setItem('st_notif_data', JSON.stringify(fresh));
            if (JSON.stringify(fresh) !== JSON.stringify(notifications)) {
                notifications = fresh;
                notifShown = 0;
                renderNotifs();
            }
        } catch (e) { console.error(e); }
    }

    function renderNotifs() {
        var el = document.getElementById('notifList');
        if (!notifications.length) {
            el.innerHTML = '<div class="empty-state"><div class="empty-state__icon">🔔</div><div class="empty-state__title">No notifications yet</div><div class="empty-state__desc">You\'ll see updates here</div></div>';
            return;
        }
        var end = Math.min(notifShown + NOTIF_BATCH, notifications.length);
        var batch = notifications.slice(notifShown, end);
        if (notifShown === 0) el.innerHTML = '';
        el.querySelectorAll('.load-more-wrap').forEach(function(x) { x.remove(); });
        el.innerHTML += batch.map(function(n) {
            var nd = (n.data && typeof n.data === 'object') ? n.data : {};
            var entityType = nd.entityType || n.entityType || '';
            var entityName = nd.entityName || n.entityName || '';
            var thumb = nd.entityThumbnail || n.entityThumbnail || '';
            var status = nd.status || '';
            var title = (n.title || '').trim();
            var body = (n.body || n.message || '').trim();
            var isRead = n.isRead === true;
            var isDeadline = (nd.type || '').includes('deadline');
            var createdAt = timeAgo(n.createdAt || n.date);
            var primaryName = entityName || title || 'Notification';
            var subText = entityName ? title : body;
            var entityId = nd.entityId || '';
            var link = '#';
            if (entityId && entityType) {
                link = entityType.toLowerCase() === 'scholarship' ? 'scholarship-detail?id=' + entityId : 'university-detail?id=' + entityId;
            }
            if (nd.applicationId) link = 'application-detail?id=' + nd.applicationId;

            var thumbHTML = thumb
                ? '<img src="' + resolveAsset(thumb) + '" style="width:100%;height:100%;object-fit:contain;" onerror="this.outerHTML=\'' + entityIcon(entityType).replace(/'/g, "\\'") + '\'">'
                : entityIcon(entityType);

            var statusBadge = status ? '<span style="display:inline-block;padding:2px 8px;border-radius:4px;font-size:10px;font-weight:800;text-transform:uppercase;color:' + statusColor(status) + ';background:' + statusColor(status) + '15;margin-right:6px;">' + status + '</span>' : '';
            var typeBadge = entityType ? '<span style="display:inline-block;padding:2px 7px;border-radius:4px;font-size:9px;font-weight:800;text-transform:uppercase;color:var(--slate-500);background:var(--slate-100);">' + entityType + '</span>' : '';
            var applyBtn = (isDeadline && entityId) ? '<a href="' + link + '" class="btn btn--primary btn--sm" style="padding:5px 14px;font-size:11px;margin-top:6px;display:inline-flex;text-decoration:none;"><i class="fas fa-paper-plane"></i> Apply Now</a>' : '';

            return '<a href="' + link + '" onclick="sessionStorage.setItem(\'st_notif_scroll\', window.scrollY)" style="display:flex;gap:12px;padding:14px 16px;border:1px solid ' + (isRead ? 'var(--slate-200)' : (isDeadline ? '#FDE68A' : 'rgba(46,139,87,.2)')) + ';border-radius:16px;margin-bottom:12px;background:' + (isRead ? '#fff' : (isDeadline ? '#FFFBEB' : 'var(--primary-light)')) + ';text-decoration:none;transition:all .3s;' + (isDeadline && !isRead ? 'border-left:4px solid #EA580C;' : '') + '">' +
                '<div style="width:48px;height:48px;border-radius:12px;background:var(--slate-100);overflow:hidden;display:flex;align-items:center;justify-content:center;flex-shrink:0;">' + thumbHTML + '</div>' +
                '<div style="flex:1;min-width:0;">' +
                    '<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px;">' +
                        '<div style="font-weight:900;font-size:14px;color:var(--navy);line-height:1.2;">' + primaryName + '</div>' +
                        (!isRead ? '<span style="padding:2px 8px;border-radius:20px;font-size:9px;font-weight:900;color:#EF4444;background:rgba(239,68,68,.1);flex-shrink:0;">NEW</span>' : '<span style="font-size:10px;font-weight:700;color:var(--slate-400);flex-shrink:0;">' + createdAt + '</span>') +
                    '</div>' +
                    (subText ? '<div style="font-size:11px;color:var(--slate-500);font-weight:500;margin-top:4px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + subText + '</div>' : '') +
                    (body && entityName ? '<div style="font-size:12px;color:var(--slate-500);line-height:1.3;margin-top:4px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;">' + body + '</div>' : '') +
                    '<div style="margin-top:6px;display:flex;align-items:center;gap:6px;flex-wrap:wrap;">' + statusBadge + typeBadge + '</div>' +
                    (!isRead ? '<div style="margin-top:4px;font-size:10px;font-weight:900;color:var(--slate-400);"><i class="fas fa-clock" style="font-size:9px;"></i> ' + createdAt + '</div>' : '') +
                    applyBtn +
                '</div></a>';
        }).join('');
        notifShown = end;
        sessionStorage.setItem('st_notif_batch', Math.max(notifShown, 10));
        if (notifShown < notifications.length) {
            el.innerHTML += '<div class="load-more-wrap" style="text-align:center; padding:16px;"><button class="btn btn--outline" id="notifLoadMore" style="padding:12px 40px; font-size:14px; font-weight:700; border-radius:12px;"><i class="fas fa-plus" style="margin-right:6px;"></i>Load More (' + (notifications.length - notifShown) + ' remaining)</button></div>';
            document.getElementById('notifLoadMore').addEventListener('click', function() { NOTIF_BATCH = 3; renderNotifs(); });
        }
    }

    window.markAllRead = async function() {
        try {
            await apiFetch('users/notifications/read', { method: 'PUT' });
            notifications.forEach(function(n) { n.isRead = true; });
            renderNotifs();
            showToast('All marked as read');
        } catch (e) { showToast('Failed', 'error'); }
    };
    load();
}

// ============ MY ACCOUNT PAGE ============
function initMyAccountPage() {
    initPage('account');
    async function loadProfile() {
        try {
            var res = await apiFetch('users/profile');
            var u = res ? await res.json() : {};
            setUser(u);
            document.getElementById('dispName').textContent = u.name || 'User';
            document.getElementById('dispEmail').textContent = u.email || '';
            document.getElementById('avatar').textContent = (u.name||'U')[0].toUpperCase();
            document.getElementById('name').value = u.name || '';
            document.getElementById('phone').value = u.phone || '';
            if (u.dateOfBirth) document.getElementById('dob').value = u.dateOfBirth.split('T')[0];
        } catch(e) { console.error(e); }
    }
    document.getElementById('profileForm').addEventListener('submit', async function(e) {
        e.preventDefault();
        var btn = document.getElementById('saveBtn');
        btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
        try {
            var body = { name: document.getElementById('name').value.trim(), phone: document.getElementById('phone').value.trim() };
            var dob = document.getElementById('dob').value; if (dob) body.dateOfBirth = dob;
            var res = await apiFetch('users/profile', { method: 'PUT', body: body });
            if (!res || !res.ok) { var d = await res.json(); throw new Error(d.message || 'Failed'); }
            showToast('Profile updated!'); loadProfile();
        } catch(err) { showToast(err.message, 'error'); }
        btn.disabled = false; btn.innerHTML = '<i class="fas fa-save"></i> Save Changes';
    });
    document.getElementById('pwForm').addEventListener('submit', async function(e) {
        e.preventDefault();
        if (document.getElementById('newPw').value !== document.getElementById('confirmPw').value) { showToast("Passwords don't match", 'error'); return; }
        var btn = document.getElementById('pwBtn'); btn.disabled = true;
        try {
            var res = await apiFetch('users/profile', { method: 'PUT', body: { currentPassword: document.getElementById('currentPw').value, newPassword: document.getElementById('newPw').value } });
            if (!res || !res.ok) { var d = await res.json(); throw new Error(d.message || 'Failed'); }
            showToast('Password updated!'); document.getElementById('pwForm').reset();
        } catch(err) { showToast(err.message, 'error'); }
        btn.disabled = false;
    });
    loadProfile();
}

// ============ TRACK APPLICATION PAGE ============
function initTrackAppPage() {
    initPage('tracking');
    var allApps = [], filteredApps = [], appShown = 0, APP_BATCH = parseInt(sessionStorage.getItem('st_app_batch')) || 6;
    function statusClass(s) { var l=(s||'').toLowerCase(); if (l.includes('selected')||l.includes('approved')) return 'status--selected'; if (l.includes('rejected')) return 'status--rejected'; if (l.includes('test')||l.includes('interview')||l.includes('admit')) return 'status--test'; return 'status--applied'; }
    function statusIcon(s) { var l=(s||'').toLowerCase(); if (l.includes('selected')) return 'fa-check-circle'; if (l.includes('rejected')) return 'fa-times-circle'; if (l.includes('test')) return 'fa-clipboard-check'; if (l.includes('interview')) return 'fa-microphone'; if (l.includes('admit')) return 'fa-id-card'; return 'fa-hourglass-half'; }

    async function load() {
        // Restore from cache instantly
        try {
            var cached = sessionStorage.getItem('st_app_data');
            if (cached) {
                allApps = JSON.parse(cached);
                filteredApps = allApps;
                appShown = 0;
                renderApps();
                var savedScroll = sessionStorage.getItem('st_app_scroll');
                if (savedScroll) {
                    setTimeout(function() { window.scrollTo(0, parseInt(savedScroll)); }, 50);
                    sessionStorage.removeItem('st_app_scroll');
                }
            }
        } catch(ce) {}
        // Fetch fresh in background
        try {
            var res = await apiFetch('users/profile');
            var data = res ? await res.json() : {};
            var fresh = data.applications || [];
            sessionStorage.setItem('st_app_data', JSON.stringify(fresh));
            if (JSON.stringify(fresh) !== JSON.stringify(allApps)) {
                allApps = fresh;
                filteredApps = allApps;
                appShown = 0;
                renderApps();
            }
        } catch(e) { console.error(e); }
    }
    function renderApps() {
        var el = document.getElementById('appList');
        if (!filteredApps.length) { el.innerHTML = '<div class="empty-state"><div class="empty-state__icon">📋</div><div class="empty-state__title">No applications yet</div><div class="empty-state__desc">Apply to universities or scholarships to see them here</div></div>'; return; }
        var end = Math.min(appShown + APP_BATCH, filteredApps.length);
        var batch = filteredApps.slice(appShown, end);
        if (appShown === 0) el.innerHTML = '';
        el.querySelectorAll('.load-more-wrap').forEach(function(x) { x.remove(); });
        el.innerHTML += batch.map(function(app) {
            var type = app.type || 'University';
            var entity = type === 'University' ? app.university : app.scholarship;
            if (!entity) return '';
            var name = type === 'University' ? (entity.name||'University') : (entity.title||'Scholarship');
            var status = app.status || 'Applied';
            var thumb = entity.thumbnail || entity.logo || entity.image || '';
            var loc = [entity.city, entity.country].filter(Boolean).join(', ');
            var sl = status.toLowerCase();
            var sc = sl.includes('selected')||sl.includes('approved') ? '#10B981' : sl.includes('rejected') ? '#EF4444' : sl.includes('admit') ? '#7C3AED' : sl.includes('test')||sl.includes('interview') ? '#F59E0B' : '#0EA5E9';
            var thumbHTML = thumb
                ? '<img src="' + resolveAsset(thumb) + '" style="width:100%;height:100%;object-fit:contain;display:block;" onerror="this.style.display=\'none\'">'
                : '<i class="fas fa-' + (type==='University'?'university':'award') + '" style="font-size:20px;color:' + (type==='University'?'var(--primary)':'var(--orange)') + ';"></i>';
            return '<a href="application-detail?id=' + app._id + '" onclick="sessionStorage.setItem(\'st_app_scroll\', window.scrollY)" style="display:flex;gap:16px;padding:18px 20px;border:1px solid var(--slate-200);border-radius:16px;margin-bottom:14px;text-decoration:none;background:#fff;transition:all .3s;align-items:center;" onmouseenter="this.style.borderColor=\'var(--primary)\';this.style.transform=\'translateY(-2px)\';this.style.boxShadow=\'0 8px 20px rgba(0,0,0,.06)\'" onmouseleave="this.style.borderColor=\'var(--slate-200)\';this.style.transform=\'none\';this.style.boxShadow=\'none\'">' +
                '<div style="width:56px;height:56px;border-radius:14px;background:var(--slate-100);overflow:hidden;display:flex;align-items:center;justify-content:center;flex-shrink:0;">' + thumbHTML + '</div>' +
                '<div style="flex:1;min-width:0;">' +
                    '<div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">' +
                        '<span style="font-size:10px;font-weight:900;color:' + (type==='University'?'var(--primary)':'var(--orange)') + ';text-transform:uppercase;letter-spacing:1px;">' + type + '</span>' +
                    '</div>' +
                    '<div style="font-size:15px;font-weight:800;color:var(--navy);line-height:1.3;margin-bottom:4px;">' + name + '</div>' +
                    (loc ? '<div style="font-size:12px;color:var(--slate-500);"><i class="fas fa-map-marker-alt" style="color:#6366F1;margin-right:3px;font-size:10px;"></i>' + loc + '</div>' : '') +
                '</div>' +
                '<div style="text-align:right;flex-shrink:0;">' +
                    '<span style="display:inline-block;padding:6px 16px;border-radius:8px;font-size:11px;font-weight:800;color:' + sc + ';background:' + sc + '15;">' + status + '</span>' +
                    '<div style="font-size:11px;color:var(--slate-400);margin-top:8px;">Applied ' + formatDate(app.appliedAt || app.createdAt) + '</div>' +
                '</div></a>';
        }).join('');
        appShown = end;
        sessionStorage.setItem('st_app_batch', Math.max(appShown, 6));
        if (appShown < filteredApps.length) {
            el.innerHTML += '<div class="load-more-wrap" style="text-align:center; padding:16px;"><button class="btn btn--outline" id="appLoadMore" style="padding:12px 40px; font-size:14px; font-weight:700; border-radius:12px;"><i class="fas fa-plus" style="margin-right:6px;"></i>Load More (' + (filteredApps.length - appShown) + ' remaining)</button></div>';
            document.getElementById('appLoadMore').addEventListener('click', function() { APP_BATCH = 3; renderApps(); });
        }
    }
    document.getElementById('searchInput').addEventListener('input', function(e) {
        var q = e.target.value.toLowerCase().trim();
        if (!q) { filteredApps = allApps; } else {
            filteredApps = allApps.filter(function(a) {
                var entity = a.type==='University' ? a.university : a.scholarship;
                var name = (entity && (entity.name || entity.title) || '').toLowerCase();
                return name.includes(q) || (a.status||'').toLowerCase().includes(q);
            });
        }
        appShown = 0; APP_BATCH = 6; renderApps();
    });
    load();
}
