// application-detail.js — Modern single-column layout
initPage('tracking');
var appId = new URLSearchParams(location.search).get('id');

function statusColor(s) {
    var l = (s || '').toLowerCase();
    if (l.includes('selected') || l.includes('approved')) return '#10B981';
    if (l.includes('rejected')) return '#EF4444';
    if (l.includes('admit')) return '#7C3AED';
    if (l.includes('test') || l.includes('interview')) return '#F59E0B';
    if (l.includes('offer')) return '#0F766E';
    return '#0EA5E9';
}

function hasFile(v) { return v && v.trim && v.trim() && v !== 'null' && v !== 'undefined' && v !== 'n/a'; }

async function loadAppDetail() {
    if (!appId) {
        document.getElementById('content').innerHTML = '<div style="text-align:center;padding:80px 20px;"><i class="fas fa-exclamation-circle" style="font-size:48px;color:#94A3B8;margin-bottom:16px;display:block;"></i><div style="font-size:18px;font-weight:800;color:#0F172A;">No application selected</div></div>';
        return;
    }
    try {
        var profRes = await apiFetch('users/profile');
        var prof = profRes ? await profRes.json() : {};
        var apps = prof.applications || [];
        var app = apps.find(function(a) { return a._id === appId; });
        if (!app) throw new Error('Not found');
        renderAppDetail(app);
    } catch(e) {
        document.getElementById('content').innerHTML = '<div style="text-align:center;padding:80px 20px;"><i class="fas fa-times-circle" style="font-size:48px;color:#EF4444;margin-bottom:16px;display:block;"></i><div style="font-size:18px;font-weight:800;color:#0F172A;">Application not found</div></div>';
    }
}

function renderAppDetail(app) {
    var type = app.type || 'University';
    var entity = type === 'University' ? app.university : app.scholarship;
    var name = type === 'University' ? (entity && entity.name || 'University') : (entity && entity.title || 'Scholarship');
    var status = app.status || 'Applied';
    var thumb = '';
    if (entity) thumb = entity.thumbnail || entity.logo || entity.image || '';
    var loc = entity ? [entity.city, entity.state, entity.country].filter(Boolean).join(', ') : '';
    var steps = ['Applied', 'Admit Card', 'Test', 'Interview', 'Selected'];
    var currentStep = steps.indexOf(status);
    var isRejected = status.toLowerCase().includes('rejected');
    if (isRejected) currentStep = steps.length;
    if (currentStep < 0) currentStep = 0;
    var progs = app.selectedPrograms || [];
    var offered = app.offeredUniversities || [];
    var sc = statusColor(status);
    var testDate = app.testDate || (entity && (entity.testDate || entity.test_date)) || '';
    var interviewDate = app.interviewDate || (entity && (entity.interviewDate || entity.interview_date)) || '';
    var isUni = type === 'University';
    var primaryColor = isUni ? '#2E8B57' : '#F97316';
    var primaryLight = isUni ? '#EAF7EE' : '#FFF7ED';

    var html = '';

    // ====== HERO with back button ======
    var thumbSrc = thumb ? resolveAsset(thumb) : '';
    html += '<div style="width:100%; height:220px; position:relative; overflow:hidden; border-radius:20px; margin-bottom:16px; box-shadow:0 8px 30px rgba(0,0,0,.12);">';
    if (thumbSrc) {
        html += '<img src="' + thumbSrc + '" alt="' + name + '" style="width:100%; height:100%; object-fit:contain;" onerror="this.style.display=\'none\'; this.parentElement.style.background=\'linear-gradient(135deg, ' + primaryColor + ', #10B981)\'">';
    } else {
        html += '<div style="width:100%; height:100%; background:linear-gradient(135deg, ' + primaryColor + ', #10B981);"></div>';
    }
    html += '<div style="position:absolute; inset:0; background:linear-gradient(to top, rgba(15,23,42,0.88) 0%, rgba(15,23,42,0.1) 60%, transparent 100%); display:flex; flex-direction:column; justify-content:space-between; padding:20px 28px;">';
    html += '<div style="display:flex; justify-content:space-between; align-items:center;">';
    html += '<a href="javascript:void(0)" onclick="history.back()" style="width:38px; height:38px; background:rgba(255,255,255,.15); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#fff; text-decoration:none; backdrop-filter:blur(8px); cursor:pointer;"><i class="fas fa-arrow-left"></i></a>';
    html += '<span style="padding:6px 14px; border-radius:8px; font-size:11px; font-weight:900; text-transform:uppercase; letter-spacing:1px; color:#fff; background:' + sc + ';">' + status + '</span>';
    html += '</div>';
    html += '<div><div style="font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:1.5px; color:rgba(255,255,255,.7); margin-bottom:4px;">' + type + ' Application</div>';
    html += '<h1 style="font-size:clamp(18px, 2.5vw, 28px); font-weight:900; color:#fff; line-height:1.2; text-shadow:0 2px 8px rgba(0,0,0,.5);">' + name + '</h1></div>';
    html += '</div></div>';

    // ====== INFO STRIP ======
    html += '<div style="display:flex; flex-wrap:wrap; gap:6px; margin-bottom:14px;">';
    if (loc) html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-map-marker-alt" style="color:#6366F1; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#94A3B8; font-weight:700; text-transform:uppercase;">Location</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + loc + '</div></div></div>';
    html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-calendar" style="color:#0EA5E9; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#94A3B8; font-weight:700; text-transform:uppercase;">Applied</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + formatDate(app.appliedAt || app.createdAt) + '</div></div></div>';
    html += '<div style="flex:1; min-width:180px; border:1px solid ' + sc + '30; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-flag" style="color:' + sc + '; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:' + sc + '; font-weight:700; text-transform:uppercase;">Status</div><div style="font-size:14px; font-weight:800; color:' + sc + ';">' + status + '</div></div></div>';
    if (testDate) html += '<div style="flex:1; min-width:180px; border:1px solid #FEF3C7; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-clipboard-check" style="color:#F59E0B; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#F59E0B; font-weight:700; text-transform:uppercase;">Test Date</div><div style="font-size:14px; font-weight:800; color:#92400E;">' + formatDate(testDate) + '</div></div></div>';
    if (interviewDate) html += '<div style="flex:1; min-width:180px; border:1px solid #EDE9FE; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-microphone" style="color:#7C3AED; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#7C3AED; font-weight:700; text-transform:uppercase;">Interview</div><div style="font-size:14px; font-weight:800; color:#5B21B6;">' + formatDate(interviewDate) + '</div></div></div>';
    html += '</div>';

    // ====== TIMELINE ======
    html += '<div style="background:#fff; border-radius:14px; padding:20px; margin-bottom:14px;">';
    html += '<div style="font-size:14px; font-weight:900; color:#0F172A; margin-bottom:16px;"><i class="fas fa-stream" style="color:' + primaryColor + '; margin-right:8px;"></i>Application Timeline</div>';
    html += '<div style="display:flex; justify-content:space-between; position:relative; margin:0;">';
    html += '<div style="position:absolute; top:18px; left:5%; right:5%; height:4px; background:#E2E8F0; border-radius:2px; z-index:0;"></div>';
    html += '<div style="position:absolute; top:18px; left:5%; width:' + (isRejected ? '100' : (Math.max(0, currentStep) * 25)) + '%; height:4px; background:' + (isRejected ? '#EF4444' : primaryColor) + '; border-radius:2px; z-index:1; transition:width .6s;"></div>';
    steps.forEach(function(s, i) {
        var done = isRejected || i <= currentStep;
        var bg = (isRejected && i === steps.length - 1) ? '#EF4444' : (done ? primaryColor : '#E2E8F0');
        var fg = done ? '#fff' : '#94A3B8';
        html += '<div class="timeline-step"><div class="timeline-dot" style="background:' + bg + '; color:' + fg + '; box-shadow:' + (done ? '0 3px 10px rgba(0,0,0,.15)' : 'none') + ';">' + (done ? '✓' : (i + 1)) + '</div><div class="timeline-label" style="color:' + (done ? primaryColor : '#94A3B8') + ';">' + s + '</div></div>';
    });
    html += '</div>';
    if (isRejected) {
        html += '<div style="margin-top:16px; padding:12px 16px; background:#FEF2F2; border:1px solid #FEE2E2; border-radius:10px; display:flex; align-items:center; gap:10px;"><i class="fas fa-times-circle" style="color:#EF4444; font-size:18px;"></i><div><div style="font-weight:800; font-size:13px; color:#EF4444;">Application Rejected</div><div style="font-size:12px; color:#92400E;">Contact the institution for more details.</div></div></div>';
    }
    html += '</div>';

    // ====== DOCUMENTS — Only show if admit card or offer letter exists ======
    var hasAdmit = hasFile(app.admitCard);
    var hasOffer = hasFile(app.offerLetter);
    if (hasAdmit || hasOffer) {
        html += '<div style="background:#fff; border-radius:14px; padding:20px; margin-bottom:14px;">';
        html += '<div style="font-size:14px; font-weight:900; color:#0F172A; margin-bottom:16px;"><i class="fas fa-file-alt" style="color:' + primaryColor + '; margin-right:8px;"></i>Documents</div>';
        html += '<div style="display:grid; grid-template-columns:' + (hasAdmit && hasOffer ? '1fr 1fr' : '1fr') + '; gap:12px;">';
        if (hasAdmit) {
            var admitName = name.replace(/[^a-zA-Z0-9]/g, '-') + '-Admit-Card';
            html += '<div class="doc-card" style="background:linear-gradient(135deg,#F5F3FF,#EDE9FE); border:1px solid #DDD6FE;">' +
                '<i class="fas fa-id-card" style="font-size:32px; color:#7C3AED; margin-bottom:10px; display:block;"></i>' +
                '<div style="font-weight:800; font-size:14px; color:#5B21B6; margin-bottom:12px;">Admit Card</div>' +
                '<button onclick="downloadDocument(\'' + app._id + '\', \'admitCard\', \'' + admitName + '\')" class="btn btn--sm" style="background:#7C3AED; color:#fff; padding:8px 24px; border-radius:10px; font-weight:800; font-size:12px; cursor:pointer;"><i class="fas fa-download" style="margin-right:6px;"></i> Download</button></div>';
        }
        if (hasOffer) {
            var offerName = name.replace(/[^a-zA-Z0-9]/g, '-') + '-Offer-Letter';
            html += '<div class="doc-card" style="background:linear-gradient(135deg,#F0FDF9,#D1FAE5); border:1px solid #A7F3D0;">' +
                '<i class="fas fa-envelope-open-text" style="font-size:32px; color:#059669; margin-bottom:10px; display:block;"></i>' +
                '<div style="font-weight:800; font-size:14px; color:#065F46; margin-bottom:12px;">Offer Letter</div>' +
                '<button onclick="downloadDocument(\'' + app._id + '\', \'offerLetter\', \'' + offerName + '\')" class="btn btn--sm" style="background:#059669; color:#fff; padding:8px 24px; border-radius:10px; font-weight:800; font-size:12px; cursor:pointer;"><i class="fas fa-download" style="margin-right:6px;"></i> Download</button></div>';
        }
        html += '</div></div>';
    }

    // ====== SELECTED PROGRAMS ======
    if (progs.length) {
        html += '<div style="background:#fff; border-radius:14px; padding:20px; margin-bottom:14px;">';
        html += '<div style="font-size:14px; font-weight:900; color:#0F172A; margin-bottom:14px;"><i class="fas fa-graduation-cap" style="color:' + primaryColor + '; margin-right:8px;"></i>Selected Programs (' + progs.length + ')</div>';
        html += '<div style="display:grid; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:10px;">';
        progs.forEach(function(p) {
            html += '<div style="padding:14px 16px; background:' + primaryLight + '; border-radius:12px; border:1px solid ' + primaryColor + '20;">' +
                '<div style="font-weight:800; font-size:14px; color:#0F172A;">' + (p.programName || '') + '</div>' +
                '<div style="font-size:12px; color:#64748B; margin-top:4px;">' + (p.programType || '') + (p.duration ? ' • ' + p.duration : '') + '</div></div>';
        });
        html += '</div></div>';
    }

    // ====== OFFERED UNIVERSITIES (scholarship apps) ======
    if (offered.length) {
        html += '<div style="background:#fff; border-radius:14px; padding:20px; margin-bottom:14px;">';
        html += '<div style="font-size:14px; font-weight:900; color:#0F172A; margin-bottom:14px;"><i class="fas fa-university" style="color:' + primaryColor + '; margin-right:8px;"></i>Offered Universities (' + offered.length + ')</div>';
        offered.forEach(function(ou) {
            var uni = (ou.university && typeof ou.university === 'object') ? ou.university : {};
            var uniName = uni.name || 'University';
            var uniThumb = uni.thumbnail || uni.logo || '';
            var ouStatus = ou.status || 'Applied';
            var ousc = statusColor(ouStatus);
            var ouAdmit = hasFile(ou.admitCard);
            var ouOffer = hasFile(ou.offerLetter);
            html += '<div style="padding:16px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:12px; margin-bottom:8px;">';
            html += '<div style="display:flex; align-items:center; gap:14px; margin-bottom:' + (ouAdmit || ouOffer ? '12px' : '0') + ';">';
            html += '<div style="width:44px; height:44px; border-radius:10px; background:#E2E8F0; overflow:hidden; display:flex; align-items:center; justify-content:center; flex-shrink:0;">';
            html += (uniThumb ? '<img src="' + resolveAsset(uniThumb) + '" style="width:100%;height:100%;object-fit:contain;" onerror="this.style.display=\'none\'">' : '<i class="fas fa-university" style="color:#94A3B8;"></i>');
            html += '</div>';
            html += '<div style="flex:1; min-width:0;"><div style="font-weight:800; font-size:14px; color:#0F172A;">' + uniName + '</div>';
            html += '<span style="display:inline-block; padding:2px 10px; border-radius:6px; font-size:10px; font-weight:800; color:' + ousc + '; background:' + ousc + '15; margin-top:4px;">' + ouStatus + '</span></div></div>';
            if (ouAdmit || ouOffer) {
                html += '<div style="display:flex; gap:8px; flex-wrap:wrap;">';
                if (ouAdmit) {
                    var ouAdmitName = uniName.replace(/[^a-zA-Z0-9]/g, '-') + '-Admit-Card';
                    var ouUniId = (uni._id || ou.university || '').toString();
                    html += '<button onclick="downloadDocument(\'' + app._id + '\', \'admitCard\', \'' + ouAdmitName + '\', \'' + ouUniId + '\')" class="btn btn--sm" style="background:#7C3AED; color:#fff; padding:7px 16px; font-size:11px; font-weight:800; border-radius:8px; cursor:pointer;"><i class="fas fa-download" style="margin-right:4px;"></i> Admit Card</button>';
                }
                if (ouOffer) {
                    var ouOfferName = uniName.replace(/[^a-zA-Z0-9]/g, '-') + '-Offer-Letter';
                    var ouUniId2 = (uni._id || ou.university || '').toString();
                    html += '<button onclick="downloadDocument(\'' + app._id + '\', \'offerLetter\', \'' + ouOfferName + '\', \'' + ouUniId2 + '\')" class="btn btn--sm" style="background:#059669; color:#fff; padding:7px 16px; font-size:11px; font-weight:800; border-radius:8px; cursor:pointer;"><i class="fas fa-download" style="margin-right:4px;"></i> Offer Letter</button>';
                }
                html += '</div>';
            }
            html += '</div>';
        });
        html += '</div>';
    }

    // ====== VIEW ENTITY LINK ======
    if (entity && entity._id) {
        html += '<a href="' + (isUni ? 'university-detail?id=' : 'scholarship-detail?id=') + entity._id + '" style="display:flex; align-items:center; justify-content:center; gap:8px; padding:14px; background:' + primaryColor + '; color:#fff; border-radius:12px; text-decoration:none; font-weight:800; font-size:14px; margin-bottom:14px; transition:all .2s;"><i class="fas fa-external-link-alt"></i> View ' + type + ' Details</a>';
    }

    document.getElementById('content').innerHTML = html;
}

loadAppDetail();
