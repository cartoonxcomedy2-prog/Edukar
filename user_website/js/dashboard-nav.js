// Shared nav for logged-in pages — Modern top-right layout with dropdown
function renderNav(activePage) {
    var user = getUser();
    var name = (user && user.name) ? user.name : 'User';
    var initial = name.charAt(0).toUpperCase();
    var unreadCount = 0;
    // Count unread notifications
    if (user && Array.isArray(user.notifications)) {
        unreadCount = user.notifications.filter(function(n) { return !n.isRead; }).length;
    }

    var nav = document.createElement('nav');
    nav.className = 'navbar';
    nav.id = 'navbar';
    nav.innerHTML = '<div class="navbar__inner">' +
        '<a href="home.html" class="navbar__logo"><div class="navbar__logo-icon"><i class="fas fa-graduation-cap"></i></div>EduKar</a>' +
        '<ul class="navbar__links" id="navLinks">' +
            '<li><a href="home.html"' + (activePage==='home'?' class="active"':'') + '>Home</a></li>' +
            '<li><a href="universities.html"' + (activePage==='universities'?' class="active"':'') + '>Universities</a></li>' +
            '<li><a href="scholarships.html"' + (activePage==='scholarships'?' class="active"':'') + '>Scholarships</a></li>' +
            '<li><a href="notifications.html"' + (activePage==='notifications'?' class="active"':'') + ' style="position:relative;">Alerts' +
                (unreadCount > 0 ? '<span style="position:absolute; top:-6px; right:-10px; background:#EF4444; color:#fff; font-size:10px; font-weight:900; min-width:18px; height:18px; border-radius:50%; display:flex; align-items:center; justify-content:center; border:2px solid #fff;">' + (unreadCount > 99 ? '99+' : unreadCount) + '</span>' : '') +
            '</a></li>' +
        '</ul>' +
        '<div class="navbar__actions">' +
            // User avatar dropdown
            '<div style="position:relative;" id="userDropdownWrap">' +
                '<button id="userAvatarBtn" style="width:38px; height:38px; border-radius:50%; background:linear-gradient(135deg, #2E8B57, #10B981); color:#fff; border:none; cursor:pointer; font-size:15px; font-weight:900; display:flex; align-items:center; justify-content:center; box-shadow:0 2px 8px rgba(46,139,87,.3);">' + initial + '</button>' +
                '<div id="userDropdown" style="display:none; position:absolute; top:48px; right:0; background:#fff; border-radius:14px; box-shadow:0 10px 40px rgba(0,0,0,.15); min-width:220px; z-index:99999; overflow:hidden; border:1px solid #E2E8F0;">' +
                    '<div style="padding:14px 16px; border-bottom:1px solid #F1F5F9; background:#F8FAFC;">' +
                        '<div style="font-weight:800; font-size:14px; color:#0F172A;">' + escapeHtml(name) + '</div>' +
                        '<div style="font-size:12px; color:#94A3B8;">' + escapeHtml((user && user.email) || '') + '</div>' +
                    '</div>' +
                    '<a href="my-account.html" style="display:flex; align-items:center; gap:10px; padding:12px 16px; text-decoration:none; color:#334155; font-size:13px; font-weight:600; transition:background .2s;" onmouseover="this.style.background=\'#F1F5F9\'" onmouseout="this.style.background=\'#fff\'"><i class="fas fa-user" style="color:#6366F1; width:16px;"></i> My Profile</a>' +
                    '<a href="track-application.html" style="display:flex; align-items:center; gap:10px; padding:12px 16px; text-decoration:none; color:#334155; font-size:13px; font-weight:600; transition:background .2s;" onmouseover="this.style.background=\'#F1F5F9\'" onmouseout="this.style.background=\'#fff\'"><i class="fas fa-clipboard-list" style="color:#0EA5E9; width:16px;"></i> My Applications</a>' +
                    '<a href="education-documents.html" style="display:flex; align-items:center; gap:10px; padding:12px 16px; text-decoration:none; color:#334155; font-size:13px; font-weight:600; transition:background .2s;" onmouseover="this.style.background=\'#F1F5F9\'" onmouseout="this.style.background=\'#fff\'"><i class="fas fa-folder-open" style="color:#F59E0B; width:16px;"></i> My Documents</a>' +
                    '<div style="border-top:1px solid #F1F5F9;"></div>' +
                    '<button id="dropdownLogout" style="display:flex; align-items:center; gap:10px; padding:12px 16px; width:100%; border:none; background:#fff; color:#EF4444; font-size:13px; font-weight:700; cursor:pointer; transition:background .2s;" onmouseover="this.style.background=\'#FEF2F2\'" onmouseout="this.style.background=\'#fff\'"><i class="fas fa-sign-out-alt" style="width:16px;"></i> Logout</button>' +
                '</div>' +
            '</div>' +
        '</div>' +
        '<button class="navbar__hamburger" id="hamburger"><i class="fas fa-bars"></i></button>' +
    '</div>';
    document.body.insertBefore(nav, document.body.firstChild);

    // Logout confirm overlay
    var logoutOverlay = document.createElement('div');
    logoutOverlay.id = 'logoutOverlay';
    logoutOverlay.style.cssText = 'position:fixed; inset:0; background:rgba(15,23,42,.5); backdrop-filter:blur(6px); z-index:9999; display:flex; align-items:center; justify-content:center; opacity:0; pointer-events:none; transition:all .3s ease;';
    logoutOverlay.innerHTML =
        '<div style="background:#fff; border-radius:20px; padding:36px; text-align:center; max-width:340px; width:90%; box-shadow:0 20px 60px rgba(0,0,0,.2);">' +
            '<div style="width:64px; height:64px; background:#FEF2F2; border-radius:50%; display:flex; align-items:center; justify-content:center; margin:0 auto 16px; font-size:28px; color:#EF4444;"><i class="fas fa-sign-out-alt"></i></div>' +
            '<h3 style="font-size:18px; font-weight:900; color:#0F172A; margin-bottom:6px;">Logout?</h3>' +
            '<p style="font-size:13px; color:#64748B; margin-bottom:24px;">Are you sure you want to logout from your account?</p>' +
            '<div style="display:flex; gap:10px;">' +
                '<button id="logoutCancel" style="flex:1; padding:12px; border-radius:12px; border:2px solid #E2E8F0; background:#fff; color:#334155; font-weight:700; font-size:13px; cursor:pointer; transition:all .2s;">Cancel</button>' +
                '<button id="logoutConfirm" style="flex:1; padding:12px; border-radius:12px; border:none; background:#EF4444; color:#fff; font-weight:700; font-size:13px; cursor:pointer; transition:all .2s;">Logout</button>' +
            '</div>' +
        '</div>';
    document.body.appendChild(logoutOverlay);

    // Add page top padding
    document.body.style.paddingTop = '72px';

    // Show the page content now that nav is rendered and auth is confirmed
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';

    // Scroll effect
    window.addEventListener('scroll', function() { nav.classList.toggle('scrolled', window.scrollY > 50); });

    // Hamburger
    document.getElementById('hamburger').addEventListener('click', function() {
        var links = document.getElementById('navLinks');
        links.classList.toggle('open');
        this.innerHTML = links.classList.contains('open') ? '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
    });

    // Dropdown toggle
    var avatarBtn = document.getElementById('userAvatarBtn');
    var dropdown = document.getElementById('userDropdown');
    avatarBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
    });
    document.addEventListener('click', function(e) {
        if (!document.getElementById('userDropdownWrap').contains(e.target)) {
            dropdown.style.display = 'none';
        }
    });

    // Logout with confirm dialog
    document.getElementById('dropdownLogout').addEventListener('click', function() {
        dropdown.style.display = 'none';
        logoutOverlay.style.opacity = '1';
        logoutOverlay.style.pointerEvents = 'all';
    });
    document.getElementById('logoutCancel').addEventListener('click', function() {
        logoutOverlay.style.opacity = '0';
        logoutOverlay.style.pointerEvents = 'none';
    });
    document.getElementById('logoutConfirm').addEventListener('click', function() {
        logout();
    });
    logoutOverlay.addEventListener('click', function(e) {
        if (e.target === logoutOverlay) {
            logoutOverlay.style.opacity = '0';
            logoutOverlay.style.pointerEvents = 'none';
        }
    });

    // Async update notification count from API
    updateNavNotifCount();
}

async function updateNavNotifCount() {
    try {
        var res = await apiFetch('users/profile');
        if (!res || !res.ok) return;
        var data = await res.json();
        setUser(data);
        var count = 0;
        if (Array.isArray(data.notifications)) {
            count = data.notifications.filter(function(n) { return !n.isRead; }).length;
        }
        // Update badge in nav links
        var alertLinks = document.querySelectorAll('a[href="notifications.html"]');
        alertLinks.forEach(function(link) {
            var badge = link.querySelector('span');
            if (count > 0) {
                if (!badge) {
                    badge = document.createElement('span');
                    badge.style.cssText = 'position:absolute; top:-6px; right:-10px; background:#EF4444; color:#fff; font-size:10px; font-weight:900; min-width:18px; height:18px; border-radius:50%; display:flex; align-items:center; justify-content:center; border:2px solid #fff;';
                    link.appendChild(badge);
                }
                badge.textContent = count > 99 ? '99+' : count;
            } else if (badge) {
                badge.remove();
            }
        });
    } catch(e) {}
}

function initPage(activePage) {
    if (!requireAuth()) return false;
    renderNav(activePage);
    return true;
}
