const API_BASE_URL = 'https://lms2.yuktaa.com/api/v2';

// Helper function to handle API requests
async function apiCall(endpoint, options = {}) {
    const token = localStorage.getItem('api_token');
    
    const headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Type': 'Browser',
        ...options.headers
    };

    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }

    try {
        const response = await fetch(`${API_BASE_URL}${endpoint}`, {
            ...options,
            headers
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || data.message || data.error || 'An error occurred while communicating with the server.');
        }

        return data;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

// Authentication API methods
const api = {
    auth: {
        login: async (username, password) => {
            return apiCall('/auth/login', {
                method: 'POST',
                body: JSON.stringify({
                    username: username,
                    password: password,
                    app_version: "2.0.0"
                })
            });
        },
        logout: () => {
            localStorage.removeItem('api_token');
            localStorage.removeItem('user_data');
            window.location.href = 'index.html';
        }
    },
    user: {
        getProfile: async () => {
            // Placeholder for getting user profile if needed
            // return apiCall('/auth/me', { method: 'GET' });
            return JSON.parse(localStorage.getItem('user_data'));
        }
    }
};
