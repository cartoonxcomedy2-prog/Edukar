// home.js — Home page (proper website)
initPage('home');

var user = getUser();
document.getElementById('greeting').textContent = 'Welcome, ' + ((user && user.name) ? user.name.split(' ')[0] : 'Student') + '!';

var currentSlide = 0, banners = [], slideInterval;

// Intersection Observer for scroll animations
var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
        if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); }
    });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

document.querySelectorAll('.fade-in, .slide-left, .slide-right, .scale-in').forEach(function(el) { observer.observe(el); });

function statusClass(s) { var l=(s||'').toLowerCase(); if (l.includes('selected')||l.includes('approved')) return 'status--selected'; if (l.includes('rejected')) return 'status--rejected'; return 'status--applied'; }

// Load banners FIRST then rest in parallel
async function loadHome() {
    var bannerPromise = apiFetch('banners');
    try {
        var bannerRes = await bannerPromise;
        banners = bannerRes ? await bannerRes.json() : [];
        if (!Array.isArray(banners)) banners = [];
        renderBanners();
    } catch(e) { console.error('Banner load error:', e); renderBanners(); }

    // Restore from cache instantly so page loads fast
    try {
        var cachedHome = sessionStorage.getItem('st_home_data');
        if (cachedHome) {
            var ch = JSON.parse(cachedHome);
            document.getElementById('sUni').textContent = ch.uniCount || 0;
            document.getElementById('sSch').textContent = ch.schCount || 0;
            document.getElementById('sApp').textContent = ch.appCount || 0;
            document.getElementById('sNotif').textContent = ch.notifCount || 0;
        }
    } catch(ce) {}
    try {
        var results = await Promise.all([
            apiFetch('universities'), 
            apiFetch('scholarships'), 
            apiFetch('users/profile')
        ]);
        var uniData = results[0] ? await results[0].json() : [];
        var schData = results[1] ? await results[1].json() : [];
        var prof = results[2] ? await results[2].json() : {};

        var apps = prof.applications || [];
        var notifs = Array.isArray(prof.notifications) ? prof.notifications : [];

        var uniCount = Array.isArray(uniData) ? uniData.length : (uniData.data ? uniData.data.length : 0);
        var schCount = Array.isArray(schData) ? schData.length : (schData.data ? schData.data.length : 0);

        document.getElementById('sUni').textContent = uniCount;
        document.getElementById('sSch').textContent = schCount;
        document.getElementById('sApp').textContent = apps.length;
        var unreadCount = notifs.filter(function(n) { return !n.isRead; }).length;
        document.getElementById('sNotif').textContent = unreadCount;
        sessionStorage.setItem('st_home_data', JSON.stringify({ uniCount: uniCount, schCount: schCount, appCount: apps.length, notifCount: unreadCount }));

        if (prof.name) {
            setUser(prof);
            document.getElementById('greeting').textContent = 'Welcome, ' + prof.name.split(' ')[0] + '!';
        }

        var recentEl = document.getElementById('recentApps');
        if (apps.length === 0) {
            recentEl.innerHTML = '<div class="empty-state"><div class="empty-state__icon">📋</div><div class="empty-state__title">No applications yet</div><div class="empty-state__desc">Apply to universities or scholarships to see them here</div></div>';
        } else {
            // Sort by most recent first
            apps.sort(function(a, b) {
                return new Date(b.appliedAt || b.createdAt || 0) - new Date(a.appliedAt || a.createdAt || 0);
            });
            
            recentEl.innerHTML = apps.slice(0, 3).map(function(app) {
                var type = app.type || 'University';
                var entity = type === 'University' ? app.university : app.scholarship;
                if (!entity) return '';
                var name = type === 'University' ? (entity.name||'University') : (entity.title||'Scholarship');
                var status = app.status || 'Applied';
                return '<a href="application-detail?id=' + app._id + '" class="card fade-in visible" style="display:flex; gap:20px; padding:20px; margin-bottom:12px; text-decoration:none; align-items:center;">' +
                    '<div style="width:48px; height:48px; border-radius:12px; background:' + (type==='University'?'var(--primary-light)':'#FFF7ED') + '; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas fa-' + (type==='University'?'university':'award') + '" style="font-size:20px; color:' + (type==='University'?'var(--primary)':'var(--orange)') + ';"></i></div>' +
                    '<div style="flex:1; min-width:0;"><div style="font-size:10px; font-weight:900; color:var(--primary); text-transform:uppercase; letter-spacing:1px;">' + type + '</div><div style="font-size:15px; font-weight:800; color:var(--navy); margin:2px 0;">' + name + '</div></div>' +
                    '<span class="status ' + statusClass(status) + '">' + status + '</span></a>';
            }).join('');
        }

        document.querySelectorAll('.fade-in:not(.visible)').forEach(function(el) { observer.observe(el); });
    } catch (e) { console.error(e); }
}

function renderBanners() {
    var el = document.getElementById('bannerSlider');
    var dots = document.getElementById('bannerDots');
    if (!banners || !banners.length) {
        el.innerHTML = '<div style="height:300px; background:linear-gradient(135deg, var(--primary), var(--accent)); border-radius:24px; display:flex; align-items:center; justify-content:center; color:#fff; font-weight:800; font-size:24px;"><i class="fas fa-graduation-cap" style="margin-right:12px; font-size:32px;"></i> Welcome to EduKar</div>';
        return;
    }

    // Build slides + clone first slide at end for seamless infinite loop
    var slidesHTML = banners.map(function(b) {
        return '<div class="banner-slider__slide"><img src="' + resolveAsset(b.imageUrl) + '" alt="' + (b.title||'') + '" onerror="this.parentElement.style.background=\'linear-gradient(135deg, var(--primary), var(--accent))\'; this.style.display=\'none\';"><div class="banner-slider__caption">' + (b.title||'') + '</div></div>';
    }).join('');

    // Clone first slide at end for seamless right-to-left infinite loop
    if (banners.length > 1) {
        slidesHTML += '<div class="banner-slider__slide"><img src="' + resolveAsset(banners[0].imageUrl) + '" alt="' + (banners[0].title||'') + '" onerror="this.parentElement.style.background=\'linear-gradient(135deg, var(--primary), var(--accent))\'; this.style.display=\'none\';"><div class="banner-slider__caption">' + (banners[0].title||'') + '</div></div>';
    }

    el.innerHTML = '<div class="banner-slider__track" id="bannerTrack">' + slidesHTML + '</div>';
    dots.innerHTML = banners.map(function(_, i) {
        return '<button class="banner-slider__dot ' + (i===0?'active':'') + '" data-slide="' + i + '"></button>';
    }).join('');

    dots.addEventListener('click', function(e) {
        if (e.target.dataset.slide != null) {
            clearInterval(slideInterval);
            var track = document.getElementById('bannerTrack');
            if (track) track.style.transition = 'transform .7s cubic-bezier(.25,.1,.25,1)';
            goSlide(parseInt(e.target.dataset.slide));
            startSlider();
        }
    });

    if (banners.length > 1) startSlider();
}

function goSlide(i) {
    currentSlide = i;
    var track = document.getElementById('bannerTrack');
    if (track) track.style.transform = 'translateX(-' + (i * 100) + '%)';
    document.querySelectorAll('.banner-slider__dot').forEach(function(d, idx) {
        d.classList.toggle('active', idx === (i % banners.length));
    });
}

function startSlider() {
    clearInterval(slideInterval);
    slideInterval = setInterval(function() {
        var track = document.getElementById('bannerTrack');
        if (!track) return;

        var nextSlide = currentSlide + 1;

        // Smooth transition right-to-left
        track.style.transition = 'transform .7s cubic-bezier(.25,.1,.25,1)';
        goSlide(nextSlide);

        // If we reached the clone (past last real slide), snap back to 0 instantly
        if (nextSlide >= banners.length) {
            setTimeout(function() {
                track.style.transition = 'none';
                currentSlide = 0;
                track.style.transform = 'translateX(0%)';
            }, 750); // wait for slide animation to finish
        }
    }, 4000);
}

loadHome();
