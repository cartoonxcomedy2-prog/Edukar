// register.js - Registration page functionality
if (isLoggedIn()) window.location.href = 'home.html';

document.getElementById('regForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const pw = document.getElementById('password').value;
    if (pw !== document.getElementById('confirmPassword').value) {
        showToast('Passwords do not match', 'error');
        return;
    }
    const btn = document.getElementById('regBtn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...';
    try {
        const body = {
            name: document.getElementById('name').value.trim(),
            email: document.getElementById('email').value.trim().toLowerCase(),
            password: pw
        };
        const phone = document.getElementById('phone').value.trim();
        if (phone) body.phone = phone;
        const res = await apiFetch('users', { method: 'POST', body });
        if (!res) throw new Error('Network error');
        const data = await res.json();
        if (!res.ok) throw new Error(data.message || 'Registration failed');
        showToast('Account created! Please login.');
        setTimeout(() => window.location.href = 'login.html', 1000);
    } catch (err) {
        showToast(err.message, 'error');
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-user-plus"></i> Create Account';
    }
});
