import { useState } from 'react';
import { sendControlCommand } from '../lib/api';
import { Send, RotateCcw, Clock, CheckCircle2, AlertCircle } from 'lucide-react';

export default function DeviceControl({ selectedDevice }) {
    const [intervalValue, setIntervalValue] = useState(5);
    const [loadingCommand, setLoadingCommand] = useState(null);
    const [statusMsg, setStatusMsg] = useState(null);

    const handleSetInterval = async (e) => {
        e.preventDefault();
        setLoadingCommand('SET_INTERVAL');
        setStatusMsg(null);
        try {
            await sendControlCommand(selectedDevice, 'SET_INTERVAL', {
                interval_seconds: Number(intervalValue),
            });
            setStatusMsg({ type: 'success', text: `Telemetry interval set to ${intervalValue}s!` });
        } catch (err) {
            setStatusMsg({ type: 'error', text: err.message });
        } finally {
            setLoadingCommand(null);
        }
    };

    const handleRestart = async () => {
        if (!confirm(`Are you sure you want to send RESTART command to ${selectedDevice}?`)) return;
        setLoadingCommand('RESTART');
        setStatusMsg(null);
        try {
            await sendControlCommand(selectedDevice, 'RESTART');
            setStatusMsg({ type: 'success', text: 'Restart command published to AWS IoT Core!' });
        } catch (err) {
            setStatusMsg({ type: 'error', text: err.message });
        } finally {
            setLoadingCommand(null);
        }
    };

    return (
        <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm">
            <div className="mb-4 flex items-center gap-2">
                <Clock className="h-5 w-5 text-cyan-400" />
                <h2 className="text-lg font-semibold text-slate-100">Remote Control Panel</h2>
            </div>

            <div className="space-y-6">
                <form onSubmit={handleSetInterval} className="space-y-3">
                    <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Publish Interval (Seconds)
                    </label>
                    <div className="flex gap-2">
                        <input
                            type="number"
                            min="1"
                            max="3600"
                            value={intervalValue}
                            onChange={(e) => setIntervalValue(e.target.value)}
                            className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:border-cyan-500 focus:outline-none"
                        />
                        <button
                            type="submit"
                            disabled={loadingCommand === 'SET_INTERVAL'}
                            className="flex items-center gap-2 whitespace-nowrap rounded-lg bg-cyan-500 px-4 py-2 text-xs font-bold text-slate-950 transition-colors hover:bg-cyan-400 disabled:opacity-50"
                        >
                            <Send className="h-4 w-4" />
                            {loadingCommand === 'SET_INTERVAL' ? 'Sending...' : 'Update'}
                        </button>
                    </div>
                </form>

                <hr className="border-slate-800" />

                <div>
                    <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">
                        System Commands
                    </label>
                    <button
                        onClick={handleRestart}
                        disabled={loadingCommand === 'RESTART'}
                        className="flex w-full items-center justify-center gap-2 rounded-lg border border-red-800/60 bg-red-950/30 py-2.5 text-xs font-bold text-red-400 transition-colors hover:bg-red-900/50 disabled:opacity-50"
                    >
                        <RotateCcw className={`h-4 w-4 ${loadingCommand === 'RESTART' ? 'animate-spin' : ''}`} />
                        {loadingCommand === 'RESTART' ? 'Sending Signal...' : 'Send RESTART Command'}
                    </button>
                </div>

                {statusMsg && (
                    <div
                        className={`flex items-center gap-2 rounded-lg p-3 text-xs font-medium ${
                            statusMsg.type === 'success'
                                ? 'border border-emerald-900/50 bg-emerald-950/30 text-emerald-400'
                                : 'border border-red-900/50 bg-red-950/30 text-red-400'
                        }`}
                    >
                        {statusMsg.type === 'success' ? (
                            <CheckCircle2 className="h-4 w-4 flex-shrink-0" />
                        ) : (
                            <AlertCircle className="h-4 w-4 flex-shrink-0" />
                        )}
                        <span>{statusMsg.text}</span>
                    </div>
                )}
            </div>
        </div>
    );
}