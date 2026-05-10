// university-detail.js — Vertical layout with hero overlay, info rows, about, expandable sections
initPage('universities');
var uniId = new URLSearchParams(location.search).get('id');
var uni = null, selectedProgram = null, existingApp = null;

async function loadUniDetail() {
    if (!uniId) { document.getElementById('detailPage').innerHTML = '<div class="empty-state"><div class="empty-state__icon">⚠️</div><div class="empty-state__title">No university selected</div></div>'; document.getElementById('applyBar').innerHTML = ''; return; }
    try {
        var res = await apiFetch('universities/' + uniId);
        if (!res) throw new Error('Network error');
        var json = await res.json();
        uni = json.data || json;
        if (!uni || !uni._id) throw new Error('Not found');
        document.title = (uni.name || 'University') + ' — EduKar';

        // Check if user already applied to this university
        try {
            var profileRes = await apiFetch('users/profile');
            var profile = profileRes ? await profileRes.json() : {};
            setUser(profile);
            var apps = profile.applications || [];
            for (var i = 0; i < apps.length; i++) {
                var a = apps[i];
                if ((a.type || '').toLowerCase() !== 'university') continue;
                var entity = a.university;
                if (entity && entity._id === uniId) {
                    existingApp = a;
                    break;
                }
            }
        } catch(pe) { console.warn('Profile check failed:', pe); }

        renderDetail();
    } catch (e) {
        console.error('Load error:', e);
        document.getElementById('detailPage').innerHTML = '<div class="empty-state"><div class="empty-state__icon">❌</div><div class="empty-state__title">Failed to load</div><div class="empty-state__desc">' + e.message + '</div></div>';
        document.getElementById('applyBar').innerHTML = '';
    }
}

function filterProgs(type) {
    return (uni.programs || []).filter(function (p) {
        var t = (p.type || '').toLowerCase().trim();
        var n = (p.name || p.programName || '').toLowerCase();
        if (type === 'bachelor') return t === 'bachelor' || t === 'bs' || t === 'bsc' || t === 'undergraduate' || t.includes('bachelor') || (!t && (n.startsWith('bs ') || n.startsWith('bsc ') || n.includes('bachelor')));
        if (type === 'master') return t === 'master' || t === 'ms' || t === 'msc' || t === 'mphil' || t === 'pgd' || t === 'postgraduate' || t === 'ma' || t === 'mba' || t.includes('master') || t.includes('postgrad') || (!t && (n.startsWith('ms ') || n.startsWith('msc ') || n.startsWith('mphil') || n.startsWith('pgd') || n.includes('master')));
        if (type === 'phd') return t === 'phd' || t === 'doctorate' || t === 'dphil' || t.includes('phd') || t.includes('doctor') || (!t && (n.includes('phd') || n.includes('doctor')));
        return false;
    });
}

function fmtMoney(amt) {
    if (!amt || amt === '0' || amt === '0.0') return 'Free';
    var cur = uni.currency || uni.feeCurrency || '';
    var str = String(amt).trim();
    try { 
        var num = Number(str.replace(/,/g, ''));
        if (isNaN(num)) return str;
        return (cur ? cur + ' ' : '') + num.toLocaleString(); 
    } catch (e) { return amt; }
}

function renderDetail() {
    var deadline = uni.deadline ? new Date(uni.deadline) : null;
    var isClosed = !(uni.isActive !== false) || (deadline && deadline < new Date());
    var loc = uni.address || uni.officeAddress || [uni.city, uni.state, uni.country].filter(Boolean).join(', ');
    var uniType = (uni.universityType || uni.type || 'University').toUpperCase();
    if (uniType === 'GENERAL' || uniType === '') uniType = 'PUBLIC';
    var testDate = uni.testDate || uni.test_date;
    var interviewDate = uni.interviewDate || uni.interview_date;
    var website = uni.website;
    var thumbSrc = resolveAsset(uni.thumbnail || uni.logo);

    // === BUILD PAGE — COMPACT LANDSCAPE ===
    var html = '';

    // ====== HERO THUMBNAIL + OVERLAY TITLE ======
    html += '<div style="width:100%; height:300px; position:relative; overflow:hidden; border-radius:20px; margin-bottom:16px; box-shadow:0 8px 30px rgba(0,0,0,.12);">';
    if (thumbSrc) {
        html += '<img src="' + thumbSrc + '" alt="' + (uni.name || '') + '" style="width:100%; height:100%; object-fit:cover; image-rendering:high-quality;" onerror="this.style.display=\'none\'; this.parentElement.style.background=\'linear-gradient(135deg, #2E8B57, #10B981)\'">';
    } else {
        html += '<div style="width:100%; height:100%; background:linear-gradient(135deg, #2E8B57, #10B981);"></div>';
    }
    html += '<div style="position:absolute; inset:0; background:linear-gradient(to top, rgba(15,23,42,0.88) 0%, rgba(15,23,42,0.1) 60%, transparent 100%); display:flex; flex-direction:column; justify-content:space-between; padding:20px 28px;">';
    html += '<div style="display:flex; justify-content:space-between; align-items:center;">';
    html += '<a href="javascript:void(0)" onclick="history.back()" style="width:38px; height:38px; background:rgba(255,255,255,.15); border-radius:50%; display:flex; align-items:center; justify-content:center; color:#fff; text-decoration:none; backdrop-filter:blur(8px); cursor:pointer;"><i class="fas fa-arrow-left"></i></a>';
    html += '<span style="padding:4px 12px; border-radius:6px; font-size:10px; font-weight:900; text-transform:uppercase; letter-spacing:1.5px; color:#fff; background:var(--primary);">' + uniType + '</span>';
    html += '</div>';
    html += '<h1 style="font-size:clamp(20px, 2.5vw, 32px); font-weight:900; color:#fff; line-height:1.2; text-shadow:0 2px 8px rgba(0,0,0,.5);">' + escapeHtml(uni.name || 'University') + '</h1>';
    html += '</div></div>';

    // ====== INFO STRIP (only show cards that have actual data) ======
    html += '<div style="display:flex; flex-wrap:wrap; gap:8px; margin-bottom:14px;">';
    if (loc) html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-map-marker-alt" style="color:#6366F1; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#94A3B8; font-weight:700; text-transform:uppercase;">Location</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + loc + '</div></div></div>';
    if (uni.deadline) html += '<div style="flex:1; min-width:180px; border:1px solid #FECACA; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-calendar-alt" style="color:#EF4444; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#EF4444; font-weight:700; text-transform:uppercase;">Deadline</div><div style="font-size:14px; font-weight:800; color:#991B1B;">' + formatDate(uni.deadline) + '</div></div></div>';
    var feeVal = uni.applicationFee || uni.applicationFees;
    if (feeVal && String(feeVal).trim() && feeVal !== '0') html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-money-bill-wave" style="color:var(--primary); font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#94A3B8; font-weight:700; text-transform:uppercase;">Fee</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + fmtMoney(feeVal) + '</div></div></div>';
    if (testDate) html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-clipboard-check" style="color:#F59E0B; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#F59E0B; font-weight:700; text-transform:uppercase;">Test</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + formatDate(testDate) + '</div></div></div>';
    if (interviewDate) html += '<div style="flex:1; min-width:180px; border:1px solid #E2E8F0; border-radius:12px; padding:12px 16px; display:flex; align-items:center; gap:10px;"><i class="fas fa-microphone" style="color:#7C3AED; font-size:16px; flex-shrink:0;"></i><div><div style="font-size:11px; color:#7C3AED; font-weight:700; text-transform:uppercase;">Interview</div><div style="font-size:14px; font-weight:800; color:#0F172A;">' + formatDate(interviewDate) + '</div></div></div>';
    html += '</div>';
    if (website) {
        var wHref = website.startsWith('http') ? website : 'https://' + website;
        html += '<div style="padding:4px 16px; margin-bottom:14px;"><a href="' + wHref + '" target="_blank" style="display:inline-flex; align-items:center; gap:8px; font-size:14px; font-weight:700; color:#2563EB; text-decoration:none;"><i class="fas fa-globe" style="font-size:16px;"></i>Official Website <i class="fas fa-external-link-alt" style="font-size:10px; color:#94A3B8;"></i></a></div>';
    }

    // ====== ABOUT (max 3 lines + See More) ======
    html += '<div style="background:#fff; border:1px solid #E2E8F0; border-radius:16px; padding:16px 20px; margin-bottom:16px;">';
    html += '<h3 style="font-size:15px; font-weight:800; color:#0F172A; margin-bottom:8px;"><i class="fas fa-building" style="color:var(--primary); margin-right:8px;"></i>About</h3>';
    html += '<p class="about-text" id="aboutText" style="-webkit-line-clamp:6;">' + escapeHtml(uni.description || 'No description available.') + '</p>';
    if ((uni.description || '').length > 150) {
        html += '<button class="see-more-btn" id="aboutToggle">See More <i class="fas fa-chevron-down" style="font-size:10px; margin-left:4px;"></i></button>';
    }
    html += '</div>';

    // ====== EXPANDABLE SECTIONS (only show sections that have data) ======
    var allSections = [
        { id: 'programs', icon: 'fa-graduation-cap', title: 'Available Programs (' + (uni.programs || []).length + ')', render: renderPrograms, hasData: (uni.programs || []).length > 0 },
        { id: 'fees', icon: 'fa-wallet', title: 'Fee Structure (' + (uni.programs || []).length + ')', render: renderFees, hasData: (uni.programs || []).some(function(p) { return p.feeAmount || p.semesterFee || p.annualFee; }) },
        { id: 'eligibility', icon: 'fa-check-circle', title: 'Eligibility Criteria', render: renderEligibility, hasData: !!(uni.eligibility && String(uni.eligibility).trim()) },
        { id: 'scholarship', icon: 'fa-award', title: 'Scholarship Details', render: renderScholarshipDetails, hasData: !!(uni.scholarshipDetails && String(uni.scholarshipDetails).trim()) },
        { id: 'contact', icon: 'fa-phone-alt', title: 'Contact Info', render: renderContacts, hasData: (Array.isArray(uni.contactInfo) && uni.contactInfo.length > 0 && uni.contactInfo.some(function(c) { return (c.email && c.email.trim()) || (c.phone && c.phone.trim()); })) || !!(uni.contact && String(uni.contact).trim()) }
    ];

    // Only show sections that have actual data — hide empty optional sections
    var sections = allSections.filter(function(s) { return s.hasData; });

    sections.forEach(function (s) {
        html += '<div class="exp-section" id="sec_' + s.id + '">' +
            '<div class="exp-header" data-target="' + s.id + '"><div class="icon"><i class="fas ' + s.icon + '"></i></div><h3>' + s.title + '</h3><div class="arrow"><i class="fas fa-chevron-down"></i></div></div>' +
            '<div class="exp-body" id="body_' + s.id + '"><div class="exp-body__inner">' + s.render() + '</div></div></div>';
    });

    document.getElementById('detailPage').innerHTML = html;

    // About toggle
    var at = document.getElementById('aboutToggle');
    if (at) at.addEventListener('click', function () {
        var txt = document.getElementById('aboutText');
        txt.classList.toggle('expanded');
        var isExpanded = txt.classList.contains('expanded');
        at.innerHTML = isExpanded
            ? 'Show Less <i class="fas fa-chevron-up" style="font-size:10px; margin-left:4px;"></i>'
            : 'See More <i class="fas fa-chevron-down" style="font-size:10px; margin-left:4px;"></i>';
    });

    // Section toggle clicks
    document.querySelectorAll('.exp-header').forEach(function (header) {
        header.addEventListener('click', function () {
            var target = this.dataset.target;
            var body = document.getElementById('body_' + target);
            var isOpen = body.classList.contains('open');
            document.querySelectorAll('.exp-body').forEach(function (b) { b.classList.remove('open'); });
            document.querySelectorAll('.exp-header').forEach(function (h) { h.classList.remove('open'); });
            if (!isOpen) { body.classList.add('open'); this.classList.add('open'); }
        });
    });

    // === APPLY BAR ===
    var applyBarEl = document.getElementById('applyBar');
    if (existingApp) {
        var appStatus = (existingApp.status || 'Applied').toLowerCase();
        if (appStatus.includes('selected') || appStatus.includes('approved')) {
            applyBarEl.innerHTML = '<div class="apply-bar__inner"><div style="flex:1; font-size:14px; font-weight:700; color:#10B981;"><i class="fas fa-check-circle"></i> You have been selected!</div><a href="application-detail?id=' + existingApp._id + '" class="btn btn--lg" style="background:#10B981; color:#fff;"><i class="fas fa-eye"></i> View Application</a></div>';
        } else if (appStatus.includes('rejected')) {
            applyBarEl.innerHTML = '<div class="apply-bar__inner"><div style="flex:1; font-size:14px; font-weight:700; color:#EF4444;"><i class="fas fa-times-circle"></i> Application Rejected</div><a href="application-detail?id=' + existingApp._id + '" class="btn btn--lg" style="background:#EF4444; color:#fff;"><i class="fas fa-eye"></i> View Details</a></div>';
        } else {
            applyBarEl.innerHTML = '<div class="apply-bar__inner"><div style="flex:1; font-size:14px; font-weight:700; color:#3B82F6;"><i class="fas fa-clock"></i> Application Submitted</div><a href="application-detail?id=' + existingApp._id + '" class="btn btn--lg" style="background:#3B82F6; color:#fff;"><i class="fas fa-arrow-right"></i> Track Application</a></div>';
        }
    } else if (isClosed) {
        applyBarEl.innerHTML = '<div class="apply-bar__inner" style="display:none;"><button class="btn btn--full btn--lg" disabled style="background:#F97316; color:#fff; opacity:0.7; flex:1;"><i class="fas fa-lock"></i> Applications Closed</button></div>';
    } else {
        applyBarEl.innerHTML = '<div class="apply-bar__inner" style="display:none; justify-content:flex-end;"><button class="btn btn--lg" id="applyBtn" style="background:#F97316; color:#fff; padding:12px 36px; border:none; border-radius:10px; font-size:14px; font-weight:800; cursor:pointer; box-shadow:0 4px 12px rgba(249,115,22,.3);"><i class="fas fa-paper-plane" style="margin-right:6px;"></i>Apply Now</button></div>';
    }

    var ab = document.getElementById('applyBtn');
    if (ab) ab.addEventListener('click', applyNow);
}

function infoRow(icon, bg, color, label, value) {
    return '<div class="info-row"><div class="info-row__icon" style="background:' + bg + '; color:' + color + ';"><i class="fas ' + icon + '"></i></div><div><div class="info-row__label">' + label + '</div><div class="info-row__value">' + value + '</div></div></div>';
}

function renderPrograms() {
    if (!(uni.programs || []).length) return '<p style="color:var(--slate-400); font-size:13px;">No programs available at this moment.</p>';
    return '<p style="font-size:12px; color:var(--slate-500); margin-bottom:8px;">Tap a program to select it before applying.</p>' +
        '<div class="tabs" id="progTabs"><button class="tab-btn active" data-type="bachelor">Bachelor (' + filterProgs('bachelor').length + ')</button><button class="tab-btn" data-type="master">Master (' + filterProgs('master').length + ')</button><button class="tab-btn" data-type="phd">PhD (' + filterProgs('phd').length + ')</button></div>' +
        '<div id="progList" style="max-height:220px; overflow-y:auto; overflow-x:hidden;">' + renderProgList('bachelor') + '</div>';
}

function renderProgList(type) {
    var list = filterProgs(type);
    if (!list.length) return '<div style="padding:20px; text-align:center; color:var(--slate-400);">No programs</div>';
    return list.map(function (p, i) {
        var n = p.name || p.programName || '';
        var sel = selectedProgram && selectedProgram.programName === n;
        return '<div class="prog-item ' + (sel ? 'selected' : '') + '" data-idx="' + i + '" data-type="' + type + '" data-ctx="prog">' +
            '<div><div class="prog-item__name">' + (i + 1) + '. ' + n + '</div><div class="prog-item__dur">Duration: ' + (p.duration || 'N/A') + '</div></div>' +
            (sel ? '<i class="fas fa-check-circle" style="color:var(--primary);"></i>' : '') + '</div>';
    }).join('');
}

function renderFees() {
    if (!(uni.programs || []).length) return '<p style="color:var(--slate-400); font-size:13px;">No fee structure available.</p>';
    return '<div class="tabs" id="feeTabs"><button class="tab-btn active" data-type="bachelor">Bachelor (' + filterProgs('bachelor').length + ')</button><button class="tab-btn" data-type="master">Master (' + filterProgs('master').length + ')</button><button class="tab-btn" data-type="phd">PhD (' + filterProgs('phd').length + ')</button></div>' +
        '<div id="feeList" style="max-height:220px; overflow-y:auto; overflow-x:hidden;">' + renderFeeList('bachelor') + '</div>';
}

function renderFeeList(type) {
    var list = filterProgs(type);
    if (!list.length) return '<div style="padding:20px; text-align:center; color:var(--slate-400);">No fee info</div>';
    return list.map(function (p, i) {
        var fee = p.feeAmount || p.semesterFee || p.annualFee || '0';
        var structure = p.feeStructure || p.feeType || (p.semesterFee ? 'Per Semester' : 'Per Year');
        return '<div style="display:flex; justify-content:space-between; align-items:center; padding:10px 12px; background:var(--slate-50); border-radius:8px; margin-bottom:6px;">' +
            '<div><div style="font-size:13px; font-weight:700; color:var(--navy);">' + (i + 1) + '. ' + (p.name || '') + '</div><div style="font-size:11px; color:var(--slate-500);">Duration: ' + (p.duration || 'N/A') + '</div></div>' +
            '<div style="text-align:right;"><div style="font-weight:900; font-size:13px; color:var(--primary);">' + fmtMoney(fee) + '</div><div style="font-size:10px; color:var(--slate-500);">' + structure + '</div></div></div>';
    }).join('');
}

function renderEligibility() {
    return '<p style="color:var(--slate-600); line-height:1.7; white-space:pre-line; font-size:13px;">' + escapeHtml(uni.eligibility || 'No eligibility criteria available at the moment.') + '</p>';
}

function renderScholarshipDetails() {
    return '<p style="color:var(--slate-600); line-height:1.7; white-space:pre-line; font-size:13px;">' + escapeHtml(uni.scholarshipDetails || 'No scholarship details available at the moment.') + '</p>';
}

function renderContacts() {
    var contacts = uni.contactInfo || [];
    if (!Array.isArray(contacts)) contacts = [contacts];
    if (!contacts.length) return '<p style="color:var(--slate-400); font-size:13px;">No contact info available.</p>';
    return contacts.map(function (c) {
        return '<div style="background:var(--slate-50); border-radius:10px; padding:12px; margin-bottom:8px;">' +
            (c.email ? '<div style="display:flex; align-items:center; gap:8px; margin-bottom:4px;"><i class="fas fa-envelope" style="color:var(--primary); font-size:12px;"></i><a href="mailto:' + c.email + '" style="font-size:13px; font-weight:700;">' + c.email + '</a></div>' : '') +
            (c.phone ? '<div style="display:flex; align-items:center; gap:8px;"><i class="fas fa-phone" style="color:var(--primary); font-size:12px;"></i><a href="tel:' + c.phone + '" style="font-size:13px; font-weight:700;">' + c.phone + '</a></div>' : '') +
            '</div>';
    }).join('');
}

// === DOCUMENT GUARD (matches Flutter app logic) ===
function resolveLevel(rawType, fallbackName) {
    var text = ((rawType || '') + ' ' + (fallbackName || '')).toLowerCase().trim();
    if (text.includes('phd') || text.includes('doctor')) return 'phd';
    if (text.includes('master') || text.includes('ms') || text.includes('msc') || text.includes('mphil') || text.includes('postgraduate')) return 'master';
    return 'bachelor';
}

function hasValue(v) { return v != null && String(v).trim() !== ''; }

function missingDocumentsForLevel(user, level) {
    var edu = (user && user.education) || {};
    var missing = [];
    var pi = edu.personalInfo || {};
    var nid = edu.nationalId || {};
    if (!hasValue(pi.fatherName) || !hasValue(pi.fatherContactNumber) || !hasValue(pi.dateOfBirth)) missing.push('Personal Information');
    if (!hasValue(nid.file)) missing.push('Identity Documents');
    // Bachelor, Master, PhD all need matric + intermediate
    if (level === 'bachelor' || level === 'master' || level === 'phd') {
        var matric = edu.matric || {};
        if (!((hasValue(matric.transcript) || hasValue(matric.certificate)) && (hasValue(matric.schoolName)) && hasValue(matric.passingYear) && hasValue(matric.grade)))
            missing.push('Matric Documents & Details');
        var inter = edu.intermediate || {};
        if (!((hasValue(inter.transcript) || hasValue(inter.certificate)) && (hasValue(inter.collegeName)) && hasValue(inter.passingYear) && hasValue(inter.grade)))
            missing.push('Intermediate Documents & Details');
    }
    // Master & PhD also need bachelor
    if (level === 'master' || level === 'phd') {
        var bach = edu.bachelor || {};
        if (!((hasValue(bach.transcript) || hasValue(bach.certificate)) && (hasValue(bach.collegeName)) && hasValue(bach.passingYear) && hasValue(bach.grade) && hasValue(bach.degreeName)))
            missing.push('Bachelor Documents & Details');
    }
    // PhD also needs master
    if (level === 'phd') {
        var masters = edu.masters || {};
        if (!((hasValue(masters.transcript) || hasValue(masters.certificate)) && (hasValue(masters.collegeName)) && hasValue(masters.passingYear) && hasValue(masters.grade) && hasValue(masters.degreeName)))
            missing.push('Master Documents & Details');
    }
    return missing;
}

// Event delegation for tabs and program selection
document.addEventListener('click', function (e) {
    var tabBtn = e.target.closest('#progTabs .tab-btn');
    if (tabBtn) {
        tabBtn.parentElement.querySelectorAll('.tab-btn').forEach(function (b) { b.classList.remove('active'); });
        tabBtn.classList.add('active');
        document.getElementById('progList').innerHTML = renderProgList(tabBtn.dataset.type);
        return;
    }
    var feeBtn = e.target.closest('#feeTabs .tab-btn');
    if (feeBtn) {
        feeBtn.parentElement.querySelectorAll('.tab-btn').forEach(function (b) { b.classList.remove('active'); });
        feeBtn.classList.add('active');
        document.getElementById('feeList').innerHTML = renderFeeList(feeBtn.dataset.type);
        return;
    }
    var item = e.target.closest('.prog-item[data-ctx="prog"]');
    if (item) {
        var idx = parseInt(item.dataset.idx);
        var type = item.dataset.type;
        var prog = filterProgs(type)[idx];
        if (prog) {
            var n = prog.name || prog.programName;
            selectedProgram = { programName: n, programType: prog.type, duration: prog.duration };
            document.getElementById('progList').innerHTML = renderProgList(type);
            showToast('Selected: ' + n);
        }
    }
});

async function applyNow() {
    if (!selectedProgram) { showToast('Please select a program first', 'error'); return; }

    // Check documents
    var user = getUser();
    var level = resolveLevel(selectedProgram.programType, selectedProgram.programName);
    var missing = missingDocumentsForLevel(user, level);
    if (missing.length > 0) {
        // Show premium popup for missing documents
        var levelName = level.charAt(0).toUpperCase() + level.slice(1);
        var docList = missing.map(function(d) {
            return '<div style="display:flex; align-items:center; gap:10px; padding:10px 14px; background:#FEF2F2; border-radius:10px; border-left:3px solid #EF4444;">' +
                '<i class="fas fa-exclamation-triangle" style="color:#EF4444; font-size:14px;"></i>' +
                '<span style="font-size:13px; font-weight:700; color:#991B1B;">' + d + '</span></div>';
        }).join('');

        var popupHtml = '<div id="docMissingOverlay" style="position:fixed; inset:0; z-index:9999; background:rgba(0,0,0,.6); backdrop-filter:blur(6px); display:flex; align-items:center; justify-content:center; animation:fadeIn .3s;">' +
            '<div style="background:#fff; border-radius:24px; padding:32px; max-width:440px; width:90%; box-shadow:0 25px 60px rgba(0,0,0,.3); animation:slideUp .4s;">' +
            '<div style="text-align:center; margin-bottom:20px;">' +
            '<div style="width:60px; height:60px; border-radius:50%; background:#FEF2F2; display:flex; align-items:center; justify-content:center; margin:0 auto 14px;"><i class="fas fa-folder-open" style="font-size:24px; color:#EF4444;"></i></div>' +
            '<h3 style="font-size:18px; font-weight:900; color:#0F172A; margin-bottom:6px;">Documents Missing</h3>' +
            '<p style="font-size:13px; color:#64748B; line-height:1.5;">To apply for <strong>' + levelName + '</strong> program, please upload the following documents first:</p>' +
            '</div>' +
            '<div style="display:flex; flex-direction:column; gap:8px; margin-bottom:24px; max-height:200px; overflow-y:auto; overflow-x:hidden;">' + docList + '</div>' +
            '<div style="display:flex; gap:12px;">' +
            '<button onclick="document.getElementById(\'docMissingOverlay\').remove()" style="flex:1; padding:12px; border-radius:12px; border:2px solid #E2E8F0; background:#fff; font-size:14px; font-weight:700; color:#64748B; cursor:pointer;">Cancel</button>' +
            '<button onclick="location.href=\'education-documents\'" style="flex:1; padding:12px; border-radius:12px; border:none; background:linear-gradient(135deg, #EF4444, #DC2626); font-size:14px; font-weight:700; color:#fff; cursor:pointer; box-shadow:0 4px 12px rgba(239,68,68,.4);"><i class="fas fa-upload" style="margin-right:6px;"></i>Upload Now</button>' +
            '</div></div></div>';

        document.body.insertAdjacentHTML('beforeend', popupHtml);
        return;
    }

    // Show Please Wait dialog
    var overlay = document.getElementById('applyOverlay');
    var dialog = document.getElementById('applyDialog');
    dialog.innerHTML = '<div class="spinner"></div><h4>Please Wait...</h4><p>Submitting your application</p>';
    overlay.classList.add('show');

    var btn = document.getElementById('applyBtn');
    if (btn) { btn.disabled = true; }

    try {
        await new Promise(function (r) { setTimeout(r, 3000); });
        var res = await apiFetch('applications/apply', { method: 'POST', body: { type: 'University', universityId: uniId, selectedPrograms: [selectedProgram] } });
        var data = res ? await res.json() : {};
        if (!res || !res.ok) throw new Error(data.message || 'Application failed');

        // Show success
        playSuccessSound();
        dialog.innerHTML = '<div class="success-icon"><i class="fas fa-check-circle"></i></div><h4>Applied Successfully!</h4><p>Your application has been submitted.</p>';
        await new Promise(function (r) { setTimeout(r, 2000); });
        overlay.classList.remove('show');
        location.href = 'track-application';
    } catch (e) {
        overlay.classList.remove('show');
        showToast(e.message, 'error');
        if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-paper-plane"></i> Apply Now'; }
    }
}

loadUniDetail();
