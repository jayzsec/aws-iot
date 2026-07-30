const API_URL = import.meta.env.PUBLIC_API_GATEWAY_URL;
const CLIENT_ID = import.meta.env.PUBLIC_COGNITO_CLIENT_ID;
const REGION = import.meta.env.PUBLIC_AWS_REGION || 'ap-southeast-2';

export function getToken() {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem('id_token');
}

export function setToken(token) {
    localStorage.setItem('id_token', token);
}

export function removeToken() {
    localStorage.removeItem('id_token');
}

export async function login(username, password) {
    const endpoint = `https://cognito-idp.${REGION}.amazonaws.com/`;
    const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-amz-json-1.1',
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
        },
        body: JSON.stringify({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: CLIENT_ID,
            AuthParameters: {
                USERNAME: username,
                PASSWORD: password,
            },
        }),
    });

    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.message || data.__type || 'Authentication failed');
    }

    const idToken = data.AuthenticationResult?.IdToken;
    if (idToken) {
        setToken(idToken);
        return idToken;
    }
    throw new Error('No ID Token returned from Cognito');
}

export async function fetchTelemetry(deviceId, range = '1h') {
    const token = getToken();
    if (!token) throw new Error('Unauthenticated');

    const response = await fetch(`${API_URL}/telemetry?device_id=${deviceId}&range=${range}`, {
        headers: {
            Authorization: `Bearer ${token}`,
        },
    });

    if (response.status === 401) {
        removeToken();
        window.location.href = '/login';
        throw new Error('Session expired');
    }

    if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        throw new Error(err.message || 'Failed to fetch telemetry data');
    }

    return await response.json();
}

export async function sendControlCommand(deviceId, command, payload = {}) {
    const token = getToken();
    if (!token) throw new Error('Unauthenticated');

    const response = await fetch(`${API_URL}/devices/${deviceId}/control`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ command, payload }),
    });

    if (response.status === 401) {
        removeToken();
        window.location.href = '/login';
        throw new Error('Session expired');
    }

    if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        throw new Error(err.message || 'Failed to send control command');
    }

    return await response.json();
}