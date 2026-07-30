import { useState, useEffect } from 'react';
import { fetchTelemetry } from '../lib/api';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { RefreshCw, Activity, Thermometer, Droplets, BatteryCharging } from 'lucide-react';

export default function TelemetryChart({ selectedDevice, selectedRange, onRangeChange }) {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [lastUpdated, setLastUpdated] = useState(null);

    const loadTelemetry = async () => {
        setLoading(true);
        setError(null);
        try {
            const res = await fetchTelemetry(selectedDevice, selectedRange);
            const formatted = (res.telemetry || []).map((point) => ({
                time: new Date(point.bucket).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                temperature: Number(point.avg_temperature),
                humidity: Number(point.avg_humidity),
                battery: Number(point.avg_battery),
            }));
            setData(formatted);
            setLastUpdated(new Date().toLocaleTimeString());
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadTelemetry();
        const interval = setInterval(loadTelemetry, 15000);
        return () => clearInterval(interval);
    }, [selectedDevice, selectedRange]);

    const latestPoint = data[data.length - 1] || {};

    return (
        <div className="space-y-6">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4 backdrop-blur-sm">
                    <div className="flex items-center justify-between text-slate-400">
                        <span className="text-sm font-medium">Avg Temperature</span>
                        <Thermometer className="h-5 w-5 text-orange-400" />
                    </div>
                    <div className="mt-2 text-2xl font-bold text-slate-100">
                        {latestPoint.temperature !== undefined ? `${latestPoint.temperature}°C` : '--'}
                    </div>
                </div>

                <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4 backdrop-blur-sm">
                    <div className="flex items-center justify-between text-slate-400">
                        <span className="text-sm font-medium">Avg Humidity</span>
                        <Droplets className="h-5 w-5 text-blue-400" />
                    </div>
                    <div className="mt-2 text-2xl font-bold text-slate-100">
                        {latestPoint.humidity !== undefined ? `${latestPoint.humidity}%` : '--'}
                    </div>
                </div>

                <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4 backdrop-blur-sm">
                    <div className="flex items-center justify-between text-slate-400">
                        <span className="text-sm font-medium">Battery Level</span>
                        <BatteryCharging className="h-5 w-5 text-emerald-400" />
                    </div>
                    <div className="mt-2 text-2xl font-bold text-slate-100">
                        {latestPoint.battery !== undefined ? `${latestPoint.battery}%` : '--'}
                    </div>
                </div>
            </div>

            <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm">
                <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
                    <div className="flex items-center gap-2">
                        <Activity className="h-5 w-5 text-cyan-400" />
                        <h2 className="text-lg font-semibold text-slate-100">Live Telemetry Metrics</h2>
                        {lastUpdated && <span className="text-xs text-slate-500">Updated: {lastUpdated}</span>}
                    </div>

                    <div className="flex items-center gap-2">
                        {['1h', '24h', '7d'].map((range) => (
                            <button
                                key={range}
                                onClick={() => onRangeChange(range)}
                                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                                    selectedRange === range
                                        ? 'bg-cyan-500 text-slate-950'
                                        : 'bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-slate-200'
                                }`}
                            >
                                {range.toUpperCase()}
                            </button>
                        ))}
                        <button
                            onClick={loadTelemetry}
                            disabled={loading}
                            className="rounded-lg bg-slate-800 p-2 text-slate-400 hover:bg-slate-700 hover:text-slate-200 disabled:opacity-50"
                            title="Refresh Data"
                        >
                            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
                        </button>
                    </div>
                </div>

                {error ? (
                    <div className="flex h-64 w-full items-center justify-center rounded-lg border border-red-900/50 bg-red-950/20 text-red-400 text-sm">
                        {error}
                    </div>
                ) : loading && data.length === 0 ? (
                    <div className="flex h-64 w-full items-center justify-center">
                        <div className="h-8 w-8 animate-spin rounded-full border-4 border-cyan-500 border-t-transparent"></div>
                    </div>
                ) : data.length === 0 ? (
                    <div className="flex h-64 w-full items-center justify-center text-slate-500 text-sm">
                        No telemetry data recorded for this time range.
                    </div>
                ) : (
                    <div className="h-72 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={data}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                                <XAxis dataKey="time" stroke="#94a3b8" fontSize={12} />
                                <YAxis stroke="#94a3b8" fontSize={12} />
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.5rem', color: '#f8fafc' }}
                                />
                                <Legend />
                                <Line type="monotone" dataKey="temperature" name="Temp (°C)" stroke="#fb923c" strokeWidth={2} dot={false} />
                                <Line type="monotone" dataKey="humidity" name="Humidity (%)" stroke="#60a5fa" strokeWidth={2} dot={false} />
                                <Line type="monotone" dataKey="battery" name="Battery (%)" stroke="#34d399" strokeWidth={2} dot={false} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                )}
            </div>
        </div>
    );
}