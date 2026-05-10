// education.js — matches Flutter edu sections exactly
initPage('education');
var education = {}, userProfile = {};

// Location data matching Flutter app's location_data.dart
var PROVINCES = ['Sindh', 'Punjab', 'KPK', 'Balochistan', 'Gilgit Baltistan', 'Azad Kashmir'];
var CITIES_MAP = {
    'Sindh': ['Karachi', 'Hyderabad', 'Sukkur', 'Larkana', 'Mirpurkhas', 'Nawabshah'],
    'Punjab': ['Lahore', 'Faisalabad', 'Rawalpindi', 'Multan', 'Gujranwala', 'Sialkot'],
    'KPK': ['Peshawar', 'Mardan', 'Abbottabad', 'Swat', 'Kohat', 'Dera Ismail Khan'],
    'Balochistan': ['Quetta', 'Gwadar', 'Turbat', 'Khuzdar', 'Hub', 'Chaman'],
    'Gilgit Baltistan': ['Gilgit', 'Skardu', 'Hunza', 'Ghizer', 'Diamer'],
    'Azad Kashmir': ['Muzaffarabad', 'Mirpur', 'Rawalakot', 'Kotli', 'Bhimber']
};
var YEARS = [];
for (var y = 1980; y <= 2025; y++) YEARS.push(String(y));

// Section definitions matching Flutter app
var sections = [
    { key: 'personal', title: 'Section 1: Personal & ID Info', icon: 'fa-user', render: renderPersonal },
    { key: 'matric', title: 'Section 2: School (Matric)', icon: 'fa-school', render: renderMatric },
    { key: 'intermediate', title: 'Section 3: College (Intermediate)', icon: 'fa-building-columns', render: renderIntermediate },
    { key: 'bachelor', title: 'Section 4: Bachelor\'s', icon: 'fa-graduation-cap', render: renderBachelor },
    { key: 'masters', title: 'Section 5: Master\'s', icon: 'fa-user-graduate', render: renderMasters }
];

var activeSection = null;
var hasApplied = false; // Lock identity fields after first application (fraud prevention)

async function loadEdu() {
    try {
        var res = await apiFetch('users/profile');
        userProfile = res ? await res.json() : {};
        education = userProfile.education || {};
        // Check if user has any non-reapply applications → lock identity fields
        var apps = userProfile.applications || [];
        hasApplied = apps.some(function(a) { return !a.isReapplyEligible; });
        renderMain();
    } catch(e) { console.error(e); }
}

function renderMain() {
    var el = document.getElementById('eduContent');
    if (activeSection !== null) { sections[activeSection].render(); return; }

    // Requirements note at TOP
    el.innerHTML = '<div style="margin-bottom:20px; background:#FFF7ED; border:1px solid #FDBA74; border-radius:14px; padding:18px 20px;">' +
        '<div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">' +
            '<div style="width:30px; height:30px; background:#FFEDD5; border-radius:50%; display:flex; align-items:center; justify-content:center;"><i class="fas fa-exclamation-triangle" style="color:#EA580C; font-size:14px;"></i></div>' +
            '<span style="font-weight:800; font-size:14px; color:#9A3412;">Important Requirements</span>' +
        '</div>' +
        '<div style="font-size:12px; color:#7C2D12; line-height:1.7;">' +
            '<div style="margin-bottom:6px;"><span style="font-weight:800;">• Bachelor:</span> Personal Info + CNIC + Matric + Inter.</div>' +
            '<div style="margin-bottom:6px;"><span style="font-weight:800;">• Master\'s:</span> Personal Info + CNIC + Matric + Inter + Bachelor.</div>' +
            '<div style="margin-bottom:6px;"><span style="font-weight:800;">• PhD:</span> Personal Info + CNIC + Matric + Inter + Bachelor + Master.</div>' +
        '</div>' +
        '<div style="border-top:1px solid #FDBA74; margin:10px 0; padding-top:10px;">' +
            '<div style="display:flex; gap:8px; align-items:flex-start;"><i class="fas fa-shield-halved" style="color:#DC2626; font-size:14px; margin-top:1px;"></i><span style="color:#B91C1C; font-weight:700; font-size:11.5px; line-height:1.4;">Missing any required document will result in application rejection.</span></div>' +
        '</div>' +
    '</div>' +
    '<p style="color:var(--slate-500); font-size:14px; margin-bottom:16px;">Select a section to manage your documents:</p>' +
    sections.map(function(sec, i) {
        var data = getSectionData(sec.key);
        var filled = countFilled(sec.key, data);
        var total = getTotalFields(sec.key);
        var pct = total > 0 ? Math.round((filled/total)*100) : 0;
        return '<div class="doc-section-card fade-in visible" data-idx="' + i + '" style="display:flex; align-items:center; gap:16px; padding:18px 20px; background:#fff; border:1px solid var(--slate-200); border-radius:14px; margin-bottom:12px; cursor:pointer; transition:all .3s;">' +
            '<div style="width:42px; height:42px; background:var(--primary-light); border-radius:10px; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas ' + sec.icon + '" style="color:var(--primary); font-size:18px;"></i></div>' +
            '<div style="flex:1;"><div style="font-weight:800; font-size:14px; color:var(--navy);">' + sec.title + '</div><div style="font-size:12px; color:var(--slate-500); margin-top:2px;">' + filled + '/' + total + ' fields completed</div></div>' +
            '<div style="display:flex; align-items:center; gap:10px;">' +
                '<div style="width:40px; height:40px; border-radius:50%; background:conic-gradient(var(--primary) ' + (pct*3.6) + 'deg, var(--slate-200) 0deg); display:flex; align-items:center; justify-content:center;"><div style="width:32px; height:32px; border-radius:50%; background:#fff; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:900; color:var(--primary);">' + pct + '%</div></div>' +
                '<i class="fas fa-chevron-right" style="color:var(--slate-400);"></i>' +
            '</div></div>';
    }).join('');

    // Card clicks
    el.querySelectorAll('.doc-section-card').forEach(function(card) {
        card.addEventListener('click', function() { activeSection = parseInt(this.dataset.idx); sections[activeSection].render(); });
        card.addEventListener('mouseenter', function() { this.style.borderColor = 'var(--primary)'; this.style.transform = 'translateX(4px)'; });
        card.addEventListener('mouseleave', function() { this.style.borderColor = 'var(--slate-200)'; this.style.transform = 'none'; });
    });
}

function getSectionData(key) {
    if (key==='personal') return { personalInfo: education.personalInfo||{}, nationalId: education.nationalId||{}, user: userProfile };
    return education[key] || {};
}

function countFilled(key, data) {
    var count = 0;
    if (key==='personal') {
        var pi = data.personalInfo||{}, nid = data.nationalId||{}, u = data.user||{};
        if (pi.fatherName||u.fatherName) count++;
        if (pi.fatherContactNumber) count++;
        if (pi.dateOfBirth||u.dateOfBirth) count++;
        if (u.address) count++;
        if (nid.idNumber) count++;
        if (nid.file) count++;
        if (pi.fatherCnicNumber) count++;
        if (pi.fatherCnicFile) count++;
    } else {
        var fields = key==='matric'||key==='intermediate' ? ['schoolName','passingYear','grade','transcript','certificate','state','city'] :
                     ['degreeName','collegeName','state','city','passingYear','grade','transcript','certificate'];
        fields.forEach(function(f) { if (data[f]) count++; });
    }
    return count;
}

function getTotalFields(key) {
    if (key==='personal') return 8;
    if (key==='matric'||key==='intermediate') return 7;
    return 8;
}

function backToMain() { activeSection = null; renderMain(); }

function sectionHeader(title) {
    return '<div style="display:flex; align-items:center; gap:12px; margin-bottom:28px;"><button class="btn btn--ghost btn--sm" id="backBtn"><i class="fas fa-arrow-left"></i> Back</button><h2 style="font-size:20px; font-weight:900; color:var(--navy);">' + title + '</h2></div>';
}

function field(label, id, value, type, icon) {
    return '<div class="form-group"><label><i class="fas ' + (icon||'fa-pen') + '" style="color:var(--primary); margin-right:6px;"></i>' + label + '</label><input type="' + (type||'text') + '" class="form-input" id="' + id + '" value="' + (value||'').replace(/"/g,'&quot;') + '"></div>';
}

function lockedField(label, id, value, type, icon) {
    return '<div class="form-group"><label><i class="fas ' + (icon||'fa-pen') + '" style="color:var(--primary); margin-right:6px;"></i>' + label + ' <span style="background:#FEF3C7; color:#92400E; font-size:10px; font-weight:900; padding:2px 8px; border-radius:6px; margin-left:6px;"><i class="fas fa-lock" style="font-size:9px; margin-right:3px;"></i>Locked</span></label><input type="' + (type||'text') + '" class="form-input" id="' + id + '" value="' + (value||'').replace(/"/g,'&quot;') + '" disabled style="background:#F8FAFC; color:#64748B; cursor:not-allowed; border-color:#E2E8F0;"></div>';
}

// Dropdown for State/Province
function dropField(label, id, options, selectedValue, icon) {
    var html = '<div class="form-group"><label><i class="fas ' + (icon||'fa-map') + '" style="color:var(--primary); margin-right:6px;"></i>' + label + '</label>';
    html += '<select class="form-input" id="' + id + '" style="cursor:pointer;">';
    html += '<option value="">Select ' + label + '</option>';
    options.forEach(function(opt) {
        html += '<option value="' + opt + '"' + (opt === selectedValue ? ' selected' : '') + '>' + opt + '</option>';
    });
    html += '</select></div>';
    return html;
}

// Year dropdown
function yearField(label, id, selectedValue, icon) {
    return dropField(label, id, YEARS, selectedValue, icon || 'fa-calendar');
}

function fileField(label, multerKey, savedValue, section, field) {
    var isImage = savedValue && /\.(jpg|jpeg|png|webp)/i.test(savedValue);
    var previewHtml = '';
    if (savedValue) {
        var url = resolveAsset(savedValue);
        if (isImage) {
            previewHtml = '<img src="' + url + '" style="width:40px; height:40px; object-fit:cover; border-radius:6px; border:1px solid #E2E8F0;" onerror="this.style.display=\'none\'">';
        } else {
            previewHtml = '<div style="width:40px; height:40px; background:#FEF2F2; border-radius:6px; display:flex; align-items:center; justify-content:center;"><i class="fas fa-file-pdf" style="color:#EF4444; font-size:18px;"></i></div>';
        }
    }
    var statusIcon = savedValue
        ? '<div style="width:32px; height:32px; background:#D1FAE5; border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas fa-check" style="color:#059669; font-size:14px;"></i></div>'
        : '<div style="width:32px; height:32px; background:var(--slate-100); border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas fa-cloud-upload-alt" style="color:var(--slate-400); font-size:14px;"></i></div>';
    
    var buttonsHtml = '';
    if (savedValue) {
        buttonsHtml += '<button type="button" onclick="window.open(\'' + resolveAsset(savedValue).replace(/'/g,"\\'") + '\', \'_blank\')" class="btn btn--outline btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700; margin-right:6px;" title="View"><i class="fas fa-eye" style="margin-right:6px;"></i>View</button>';
        if (section && field && userProfile && userProfile._id) {
            var fName = (userProfile.name || 'document') + '-' + field;
            buttonsHtml += '<button type="button" onclick="downloadEduDocument(\'' + userProfile._id + '\', \'' + section + '\', \'' + field + '\', \'' + fName.replace(/'/g,"\\'") + '\')" class="btn btn--outline btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700; margin-right:6px;" title="Download"><i class="fas fa-download" style="margin-right:6px;"></i>Download</button>';
        }
    }
    buttonsHtml += '<label class="btn btn--primary btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700;"><i class="fas ' + (savedValue ? 'fa-edit' : 'fa-upload') + '" style="margin-right:6px;"></i>' + (savedValue ? 'Change' : 'Upload') + '<input type="file" accept=".pdf,.jpg,.jpeg,.png" style="display:none;" data-field="' + multerKey + '"></label>';
    
    if (savedValue && section && field) {
        buttonsHtml += '<button type="button" onclick="removeDocument(\'' + section + '\', \'' + field + '\')" class="btn btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700; background:#FEF2F2; color:#DC2626; border:1px solid #FCA5A5; margin-left:6px;"><i class="fas fa-times" style="margin-right:6px;"></i>Remove</button>';
    }

    return '<div class="doc-field">' + statusIcon +
        '<div style="flex:1;"><div style="font-weight:700; font-size:14px; color:var(--navy);">' + label + '</div><div style="font-size:12px; font-weight:700; color:' + (savedValue?'#059669':'var(--slate-400)') + ';">' + (savedValue?'Uploaded':'Not uploaded') + '</div></div>' +
        (previewHtml ? previewHtml : '') + buttonsHtml + '</div>';
}

function lockedFileField(label, multerKey, savedValue, section, field) {
    var previewHtml = '';
    if (savedValue) {
        var url = resolveAsset(savedValue);
        var isImage = /\.(jpg|jpeg|png|webp)/i.test(savedValue);
        previewHtml = isImage
            ? '<img src="' + url + '" style="width:40px; height:40px; object-fit:cover; border-radius:6px; border:1px solid #E2E8F0;" onerror="this.style.display=\'none\'">'
            : '<div style="width:40px; height:40px; background:#FEF2F2; border-radius:6px; display:flex; align-items:center; justify-content:center;"><i class="fas fa-file-pdf" style="color:#EF4444; font-size:18px;"></i></div>';
    }
    var statusIcon = savedValue
        ? '<div style="width:32px; height:32px; background:#D1FAE5; border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas fa-check" style="color:#059669; font-size:14px;"></i></div>'
        : '<div style="width:32px; height:32px; background:var(--slate-100); border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0;"><i class="fas fa-cloud-upload-alt" style="color:var(--slate-400); font-size:14px;"></i></div>';
    
    var viewBtn = '';
    if (savedValue) {
        viewBtn += '<button type="button" onclick="window.open(\'' + resolveAsset(savedValue).replace(/'/g,"\\'") + '\', \'_blank\')" class="btn btn--outline btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700; margin-right:6px;" title="View"><i class="fas fa-eye" style="margin-right:6px;"></i>View</button>';
        if (section && field && userProfile && userProfile._id) {
            var fName = (userProfile.name || 'document') + '-' + field;
            viewBtn += '<button type="button" onclick="downloadEduDocument(\'' + userProfile._id + '\', \'' + section + '\', \'' + field + '\', \'' + fName.replace(/'/g,"\\'") + '\')" class="btn btn--outline btn--sm" style="padding:6px 12px; cursor:pointer; font-weight:700;" title="Download"><i class="fas fa-download" style="margin-right:6px;"></i>Download</button>';
        }
    }
    return '<div class="doc-field">' + statusIcon +
        '<div style="flex:1;"><div style="font-weight:700; font-size:14px; color:var(--navy);">' + label + ' <span style="background:#FEF3C7; color:#92400E; font-size:10px; font-weight:900; padding:2px 8px; border-radius:6px; margin-left:6px;"><i class="fas fa-lock" style="font-size:9px; margin-right:3px;"></i>Locked</span></div><div style="font-size:12px; font-weight:700; color:' + (savedValue?'#059669':'var(--slate-400)') + ';">' + (savedValue?'Uploaded':'Not uploaded') + '</div></div>' +
        (previewHtml ? previewHtml : '') + viewBtn + '</div>';
}

function removeDocument(section, field) {
    if(!confirm('Are you sure you want to remove this document?')) return;
    var update = { education: {} };
    update.education[section] = {};
    update.education[section][field] = null;
    saveTextFields(update);
}

function attachFileHandlers() {
    document.querySelectorAll('input[type="file"]').forEach(function(inp) {
        inp.addEventListener('change', function() { uploadFile(this.dataset.field, this); });
    });
    document.getElementById('backBtn').addEventListener('click', backToMain);
}

function showUploadOverlay() {
    var overlay = document.createElement('div');
    overlay.id = 'uploadOverlay';
    overlay.style.cssText = 'position:fixed; inset:0; background:rgba(15,23,42,0.6); backdrop-filter:blur(6px); z-index:9999; display:flex; align-items:center; justify-content:center;';
    overlay.innerHTML = '<div style="background:#fff; border-radius:20px; padding:40px 50px; text-align:center; box-shadow:0 20px 60px rgba(0,0,0,.2);">' +
        '<div style="width:50px; height:50px; border:4px solid #E2E8F0; border-top-color:var(--primary); border-radius:50%; animation:spin 0.8s linear infinite; margin:0 auto 16px;"></div>' +
        '<div style="font-size:16px; font-weight:800; color:var(--navy);">Please Wait</div>' +
        '<div style="font-size:13px; color:var(--slate-500); margin-top:4px;">Uploading your document...</div></div>';
    // Add spin animation if not exists
    if (!document.getElementById('spinStyle')) {
        var style = document.createElement('style');
        style.id = 'spinStyle';
        style.textContent = '@keyframes spin { to { transform: rotate(360deg); } }';
        document.head.appendChild(style);
    }
    document.body.appendChild(overlay);
}

function hideUploadOverlay() {
    var overlay = document.getElementById('uploadOverlay');
    if (overlay) overlay.remove();
}

function showSuccessOverlay(fileName) {
    var isImg = /\.(jpg|jpeg|png|webp)/i.test(fileName);
    var overlay = document.createElement('div');
    overlay.id = 'uploadOverlay';
    overlay.style.cssText = 'position:fixed; inset:0; background:rgba(15,23,42,0.6); backdrop-filter:blur(6px); z-index:9999; display:flex; align-items:center; justify-content:center;';
    overlay.innerHTML = '<div style="background:#fff; border-radius:20px; padding:40px 50px; text-align:center; box-shadow:0 20px 60px rgba(0,0,0,.2);">' +
        '<div style="width:60px; height:60px; background:#D1FAE5; border-radius:50%; display:flex; align-items:center; justify-content:center; margin:0 auto 16px;"><i class="fas fa-check" style="font-size:28px; color:#059669;"></i></div>' +
        '<div style="font-size:16px; font-weight:800; color:var(--navy);">Upload Successful!</div>' +
        '<div style="font-size:13px; color:var(--slate-500); margin-top:4px;">' + (isImg ? 'Image' : 'Document') + ' saved successfully.</div></div>';
    document.body.appendChild(overlay);
    setTimeout(function() { hideUploadOverlay(); }, 1500);
}

async function uploadFile(multerField, input) {
    var file = input.files && input.files[0];
    if (!file) return;
    if (file.size > 10*1024*1024) { showToast('File too large (max 10MB)', 'error'); return; }
    showUploadOverlay();
    try {
        var fd = new FormData(); fd.append(multerField, file);
        var res = await apiFetch('users/profile', { method: 'PUT', body: fd });
        if (!res || !res.ok) { var d = await res.json(); throw new Error(d.message||'Upload failed'); }
        var data = await res.json();
        education = data.education || education;
        userProfile = data;
        hideUploadOverlay();
        showSuccessOverlay(file.name);
        setTimeout(function() { sections[activeSection].render(); }, 1600);
    } catch(e) { hideUploadOverlay(); showToast(e.message, 'error'); }
    input.value = '';
}

async function saveTextFields(body) {
    showUploadOverlay();
    try {
        var res = await apiFetch('users/profile', { method: 'PUT', body: body });
        if (!res || !res.ok) { var d = await res.json(); throw new Error(d.message||'Save failed'); }
        var data = await res.json();
        education = data.education || education;
        userProfile = data;
        hideUploadOverlay();
        showToast('Saved successfully!');
        sections[activeSection].render();
    } catch(e) { hideUploadOverlay(); showToast(e.message, 'error'); }
}

// Helper to get cities for a selected state
function getCitiesForState(state) {
    return CITIES_MAP[state] || ['General City'];
}

// ============ SECTION RENDERERS ============

function renderPersonal() {
    var pi = education.personalInfo || {};
    var nid = education.nationalId || {};
    var el = document.getElementById('eduContent');
    var savedState = userProfile.state || '';
    var savedCity = userProfile.city || '';

    // Identity fields that lock after first application
    var lockNotice = '';
    if (hasApplied) {
        lockNotice = '<div style="margin-bottom:16px; background:#FEF3C7; border:1px solid #FCD34D; border-radius:12px; padding:14px 16px; display:flex; align-items:center; gap:10px;">' +
            '<i class="fas fa-shield-alt" style="color:#D97706; font-size:18px;"></i>' +
            '<div><div style="font-weight:800; font-size:13px; color:#92400E;">Identity Fields Locked</div>' +
            '<div style="font-size:11.5px; color:#A16207; line-height:1.4;">Your CNIC, father details, and ID documents are locked after submitting an application. This prevents identity fraud. Contact support if you need changes.</div></div></div>';
    }

    el.innerHTML = sectionHeader('Personal & ID Info') + lockNotice +
        '<div class="detail-section">' +
        (hasApplied ? lockedField('Father Name', 'fatherName', pi.fatherName||userProfile.fatherName, 'text', 'fa-user') : field('Father Name', 'fatherName', pi.fatherName||userProfile.fatherName, 'text', 'fa-user')) +
        (hasApplied ? lockedField('Father Contact Number', 'fatherContact', pi.fatherContactNumber, 'tel', 'fa-phone') : field('Father Contact Number', 'fatherContact', pi.fatherContactNumber, 'tel', 'fa-phone')) +
        (hasApplied ? lockedField('Date of Birth', 'dob', (pi.dateOfBirth||userProfile.dateOfBirth||'').split('T')[0], 'date', 'fa-calendar') : field('Date of Birth', 'dob', (pi.dateOfBirth||userProfile.dateOfBirth||'').split('T')[0], 'date', 'fa-calendar')) +
        dropField('State / Province', 'state', PROVINCES, savedState, 'fa-map') +
        dropField('City', 'city', savedState ? getCitiesForState(savedState) : [], savedCity, 'fa-city') +
        field('Home Address', 'address', userProfile.address, 'text', 'fa-home') +
        (hasApplied ? lockedField('ID / CNIC Number', 'idNumber', nid.idNumber, 'text', 'fa-id-card') : field('ID / CNIC Number', 'idNumber', nid.idNumber, 'text', 'fa-id-card')) +
        (hasApplied ? lockedFileField('National ID Card File', 'idFile', nid.file, 'nationalId', 'file') : fileField('National ID Card File', 'idFile', nid.file, 'nationalId', 'file')) +
        (hasApplied ? lockedField('Father CNIC Number', 'fatherCnicNumber', pi.fatherCnicNumber, 'text', 'fa-id-card') : field('Father CNIC Number', 'fatherCnicNumber', pi.fatherCnicNumber, 'text', 'fa-id-card')) +
        (hasApplied ? lockedFileField('Father CNIC File', 'fatherCnicFile', pi.fatherCnicFile, 'personalInfo', 'fatherCnicFile') : fileField('Father CNIC File', 'fatherCnicFile', pi.fatherCnicFile, 'personalInfo', 'fatherCnicFile')) +
        '<button class="btn btn--primary btn--full" id="saveBtn" style="margin-top:16px;"><i class="fas fa-save"></i> Save Personal & ID Info</button>' +
        '</div>';
    attachFileHandlers();

    // State dropdown change → update city dropdown
    document.getElementById('state').addEventListener('change', function() {
        var selState = this.value;
        var citySelect = document.getElementById('city');
        var cities = selState ? getCitiesForState(selState) : [];
        citySelect.innerHTML = '<option value="">Select City</option>';
        cities.forEach(function(c) {
            citySelect.innerHTML += '<option value="' + c + '">' + c + '</option>';
        });
    });

    document.getElementById('saveBtn').addEventListener('click', function() {
        var body = {
            address: document.getElementById('address').value.trim(),
            state: document.getElementById('state').value,
            city: document.getElementById('city').value,
        };
        var eduUpdate = Object.assign({}, education);

        if (!hasApplied) {
            // Only allow identity field updates when not locked
            body.fatherName = document.getElementById('fatherName').value.trim();
            body.dateOfBirth = document.getElementById('dob').value;
            eduUpdate.personalInfo = Object.assign({}, pi, {
                fatherName: document.getElementById('fatherName').value.trim(),
                fatherContactNumber: document.getElementById('fatherContact').value.trim(),
                fatherCnicNumber: document.getElementById('fatherCnicNumber').value.trim(),
                dateOfBirth: document.getElementById('dob').value
            });
            eduUpdate.nationalId = Object.assign({}, nid, { idNumber: document.getElementById('idNumber').value.trim() });
        }

        body.education = eduUpdate;
        saveTextFields(body);
    });
}

function renderAcademic(key, title, fields) {
    var data = education[key] || {};
    var el = document.getElementById('eduContent');
    el.innerHTML = sectionHeader(title) +
        '<div class="detail-section">' +
        fields.map(function(f) {
            if (f.type === 'file') return fileField(f.label, f.multer, data[f.dataKey], key, f.dataKey);
            if (f.type === 'dropdown') return dropField(f.label, f.id, f.options, data[f.dataKey], f.icon);
            if (f.type === 'year') return yearField(f.label, f.id, data[f.dataKey], f.icon);
            return field(f.label, f.id, data[f.dataKey], f.inputType||'text', f.icon);
        }).join('') +
        '<button class="btn btn--primary btn--full" id="saveBtn" style="margin-top:16px;"><i class="fas fa-save"></i> Save ' + title + '</button></div>';
    attachFileHandlers();

    // Wire up state→city dropdown cascade
    var stateSelect = document.getElementById(key + '_state');
    var citySelect = document.getElementById(key + '_city');
    if (stateSelect && citySelect) {
        stateSelect.addEventListener('change', function() {
            var selState = this.value;
            var cities = selState ? getCitiesForState(selState) : [];
            citySelect.innerHTML = '<option value="">Select City</option>';
            cities.forEach(function(c) {
                citySelect.innerHTML += '<option value="' + c + '">' + c + '</option>';
            });
        });
    }

    document.getElementById('saveBtn').addEventListener('click', function() {
        var body = {};
        fields.forEach(function(f) {
            if (f.type !== 'file') {
                var el = document.getElementById(f.id);
                if (el) body[f.dataKey] = el.value.trim();
            }
        });
        var eduUpdate = {};
        eduUpdate[key] = Object.assign({}, data, body);
        saveTextFields({ education: Object.assign({}, education, eduUpdate) });
    });
}

function renderMatric() {
    var data = education.matric || {};
    var savedState = data.state || '';
    renderAcademic('matric', 'School (Matric)', [
        { label: 'State / Province', id: 'matric_state', dataKey: 'state', icon: 'fa-map', type: 'dropdown', options: PROVINCES },
        { label: 'City', id: 'matric_city', dataKey: 'city', icon: 'fa-city', type: 'dropdown', options: savedState ? getCitiesForState(savedState) : [] },
        { label: 'School Name', id: 'mSchool', dataKey: 'schoolName', icon: 'fa-school' },
        { label: 'Passing Year', id: 'mYear', dataKey: 'passingYear', icon: 'fa-calendar', type: 'year' },
        { label: 'Grade / Percentage', id: 'mGrade', dataKey: 'grade', icon: 'fa-percent' },
        { label: 'Transcript', multer: 'matricTranscript', dataKey: 'transcript', type: 'file' },
        { label: 'Certificate', multer: 'matricCertificate', dataKey: 'certificate', type: 'file' }
    ]);
}

function renderIntermediate() {
    var data = education.intermediate || {};
    var savedState = data.state || '';
    renderAcademic('intermediate', 'College (Intermediate)', [
        { label: 'State / Province', id: 'intermediate_state', dataKey: 'state', icon: 'fa-map', type: 'dropdown', options: PROVINCES },
        { label: 'City', id: 'intermediate_city', dataKey: 'city', icon: 'fa-city', type: 'dropdown', options: savedState ? getCitiesForState(savedState) : [] },
        { label: 'College Name', id: 'iCollege', dataKey: 'collegeName', icon: 'fa-building-columns' },
        { label: 'Passing Year', id: 'iYear', dataKey: 'passingYear', icon: 'fa-calendar', type: 'year' },
        { label: 'Grade / Percentage', id: 'iGrade', dataKey: 'grade', icon: 'fa-percent' },
        { label: 'Transcript', multer: 'interTranscript', dataKey: 'transcript', type: 'file' },
        { label: 'Certificate', multer: 'interCertificate', dataKey: 'certificate', type: 'file' }
    ]);
}

function renderBachelor() {
    var data = education.bachelor || {};
    var savedState = data.state || '';
    renderAcademic('bachelor', "Bachelor's Degree", [
        { label: 'Degree Name', id: 'bDeg', dataKey: 'degreeName', icon: 'fa-graduation-cap' },
        { label: 'University / Institute', id: 'bInst', dataKey: 'collegeName', icon: 'fa-building-columns' },
        { label: 'State / Province', id: 'bachelor_state', dataKey: 'state', icon: 'fa-map', type: 'dropdown', options: PROVINCES },
        { label: 'City', id: 'bachelor_city', dataKey: 'city', icon: 'fa-city', type: 'dropdown', options: savedState ? getCitiesForState(savedState) : [] },
        { label: 'Passing Year', id: 'bYear', dataKey: 'passingYear', icon: 'fa-calendar', type: 'year' },
        { label: 'Grade / GPA', id: 'bGrade', dataKey: 'grade', icon: 'fa-percent' },
        { label: 'Transcript', multer: 'bachTranscript', dataKey: 'transcript', type: 'file' },
        { label: 'Degree Certificate', multer: 'bachCertificate', dataKey: 'certificate', type: 'file' }
    ]);
}

function renderMasters() {
    var data = education.masters || {};
    var savedState = data.state || '';
    renderAcademic('masters', "Master's Degree", [
        { label: 'Degree Name', id: 'msDeg', dataKey: 'degreeName', icon: 'fa-user-graduate' },
        { label: 'University / Institute', id: 'msInst', dataKey: 'collegeName', icon: 'fa-building-columns' },
        { label: 'State / Province', id: 'masters_state', dataKey: 'state', icon: 'fa-map', type: 'dropdown', options: PROVINCES },
        { label: 'City', id: 'masters_city', dataKey: 'city', icon: 'fa-city', type: 'dropdown', options: savedState ? getCitiesForState(savedState) : [] },
        { label: 'Passing Year', id: 'msYear', dataKey: 'passingYear', icon: 'fa-calendar', type: 'year' },
        { label: 'Grade / GPA', id: 'msGrade', dataKey: 'grade', icon: 'fa-percent' },
        { label: 'Transcript', multer: 'masterTranscript', dataKey: 'transcript', type: 'file' },
        { label: 'Degree Certificate', multer: 'masterCertificate', dataKey: 'certificate', type: 'file' }
    ]);
}

loadEdu();
