import { useState } from 'react';
import AuthGuard from './AuthGuard';
import TelemetryChart from './TelemetryChart';
import DeviceControl from './DeviceControl';
import { removeToken } from '../lib/api';
import { Cpu, LogOut, Server } from 'lucide-react';

const DEVICES = [
    'iot-fleet-platform-dev-sim-01',
    'iot-fleet-platform-dev-sim-02',
];

export default function DashboardApp() {
    const [selectedDevice, setSelectedDevice] = useState(DEVICES[0]);
    const [selectedRange, setSelectedRange] = useState('1h');

    const handleLogout = () => {
        removeToken();
        window.location.href = '/login';
    };

    return (
        <AuthGuard>
            <div className="min-h-screen bg-slate-950 text-slate-100">
                <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur-md">
                    <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6">
                        <div className="flex items-center gap-3">
                            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                                <Cpu className="h-6 w-6" />
                            </div>
                            <div>
                                <h1 className="text-lg font-bold text-slate-100">IoT Telemetry Console</h1>
                                <p className="text-xs text-slate-400">AWS IoT Core + TimescaleDB Monitoring</p>
                            </div>
                        </div>

                        <button
                            onClick={handleLogout}
                            className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs font-semibold text-slate-300 hover:bg-slate-700 hover:text-white"
                        >
                            <LogOut className="h-4 w-4" />
                            Sign Out
                        </button>
                    </div>
                </header>

                <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 space-y-8">
                    <div className="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-slate-800 bg-slate-900/40 p-4">
                        <div className="flex items-center gap-2">
                            <Server className="h-5 w-5 text-cyan-400" />
                            <span className="text-sm font-medium text-slate-300">Active Device Target:</span>
                        </div>

                        <select
                            value={selectedDevice}
                            onChange={(e) => setSelectedDevice(e.target.value)}
                            className="rounded-lg border border-slate-700 bg-slate-950 px-4 py-2 text-sm font-semibold text-cyan-400 focus:border-cyan-500 focus:outline-none"
                        >
                            {DEVICES.map((id) => (
                                <option key={id} value={id}>
                                    {id}
                                </option>
                            ))}
                        </select>
                    </div>

                    <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
                        <div className="lg:col-span-2">
                            <TelemetryChart
                                selectedDevice={selectedDevice}
                                selectedRange={selectedRange}
                                onRangeChange={setSelectedRange}
                            />
                        </div>

                        <div>
                            <DeviceControl selectedDevice={selectedDevice} />
                        </div>
                    </div>
                </main>
            </div>
        </AuthGuard>
    );
}