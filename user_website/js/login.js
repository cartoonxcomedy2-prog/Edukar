// login.js - Login page functionality
if (isLoggedIn()) window.location.href = 'home.html';

document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = document.getElementById('loginBtn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Signing in...';
    try {
        const res = await apiFetch('users/login', {
            method: 'POST',
            body: {
                email: document.getElementById('email').value.trim().toLowerCase(),
                password: document.getElementById('password').value
            }
        });
        if (!res) throw new Error('Network error');
        const data = await res.json();
        if (!res.ok) throw new Error(data.message || 'Login failed');
        localStorage.setItem('st_token', data.token);
        saveLoginTimestamp();
        setUser(data);
        showToast('Login successful!');
        setTimeout(() => window.location.href = 'home.html', 600);
    } catch (err) {
        showToast(err.message, 'error');
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Sign In';
    }
});
