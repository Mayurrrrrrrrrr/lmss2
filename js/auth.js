document.addEventListener('DOMContentLoaded', () => {
    // If we're on the login page, check if already logged in
    if (window.location.pathname.endsWith('index.html') || window.location.pathname === '/') {
        if (localStorage.getItem('api_token')) {
            window.location.href = 'dashboard.html';
            return;
        }
    }

    const loginForm = document.getElementById('login-form');
    const togglePasswordBtn = document.getElementById('toggle-password');
    const passwordInput = document.getElementById('password');
    const errorBanner = document.getElementById('error-message');
    const loginButton = document.getElementById('login-button');
    const buttonText = loginButton?.querySelector('.button-text');
    const loader = loginButton?.querySelector('.loader');

    // Toggle password visibility
    if (togglePasswordBtn && passwordInput) {
        togglePasswordBtn.addEventListener('click', () => {
            const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
            passwordInput.setAttribute('type', type);
            
            // Toggle eye icon (optional enhancement)
            if (type === 'text') {
                togglePasswordBtn.innerHTML = '<svg class="eye-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>';
            } else {
                togglePasswordBtn.innerHTML = '<svg class="eye-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>';
            }
        });
    }

    // Handle login form submission
    if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value.trim();
            const password = passwordInput.value;

            // Reset UI
            errorBanner.classList.add('hidden');
            loginButton.disabled = true;
            buttonText.classList.add('hidden');
            loader.classList.remove('hidden');

            try {
                const response = await api.auth.login(username, password);
                
                // Assuming backend returns { token: "...", user: {...} } or similar
                // We will store the full response in local storage for now
                if (response && (response.token || response.access_token || response.data?.token)) {
                    const token = response.token || response.access_token || response.data?.token;
                    localStorage.setItem('api_token', token);
                    localStorage.setItem('user_data', JSON.stringify(response.data || response.user || response));
                    
                    // Redirect to dashboard
                    window.location.href = 'dashboard.html';
                } else {
                    throw new Error('Invalid response from server. Missing token.');
                }
            } catch (error) {
                // Show error message
                errorBanner.querySelector('span').textContent = error.message || 'Login failed. Please check your credentials and try again.';
                errorBanner.classList.remove('hidden');
                
                // Reset button
                loginButton.disabled = false;
                buttonText.classList.remove('hidden');
                loader.classList.add('hidden');
            }
        });
    }
});
