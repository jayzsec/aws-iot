import { useState, useEffect } from 'react';
import { getToken } from '../lib/api';

export default function AuthGuard({ children }) {
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const token = getToken();
        if (!token) {
            window.location.href = '/login';
        } else {
            setIsAuthenticated(true);
        }
        setLoading(false);
    }, []);

    if (loading) {
        return (
            <div className="flex h-screen w-full items-center justify-center bg-slate-950">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-cyan-500 border-t-transparent"></div>
            </div>
        );
    }

    if (!isAuthenticated) return null;

    return <>{children}</>;
}