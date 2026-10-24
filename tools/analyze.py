#!/usr/bin/env python3
"""Summarize local evidence; VIN/identity response contents remain in the JSON file."""
import argparse
import collections
import json
import pathlib
import statistics
try:
    from .obd import BITMAPS, LIVE_LENGTH, decode_pid, parse_can, supported_pids
except ImportError:
    from obd import BITMAPS, LIVE_LENGTH, decode_pid, parse_can, supported_pids

def analyze(path):
    rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    responses = [r for r in rows if r['event'] == 'response']
    result = {'log':str(path), 'start':next((r for r in rows if r['event']=='start'), None),
              'end':next((r for r in reversed(rows) if r['event']=='end'), None),
              'requests':sum(r['event']=='request' for r in rows), 'responses':len(responses),
              'timeouts':sum(r['event']=='timeout' for r in rows), 'negative_responses':[],
              'parse_failures':[], 'ecus':[], 'supported':{}, 'samples':[], 'vehicle_information':[],
              'fault_responses':[], 'enhanced_responses':[], 'information_supported':{}, 'readiness':[], 'latencies':{}, 'rates':{}}
    times = collections.defaultdict(list)
    supported = collections.defaultdict(set)
    ecus = set()
    latencies = collections.defaultdict(list)
    for r in responses:
        command = r['command']
        latencies[command].append(r['latency_seconds'])
        raw = r['raw']
        lines = [s.strip() for s in raw.replace('\r','\n').splitlines()]
        clean = '\r'.join(s for s in lines if s and s != command)
        if command.startswith('AT'): continue
        if clean in ['NO DATA', '?', 'UNABLE TO CONNECT']:
            result['negative_responses'].append({'command':command,'response':clean}); continue
        try:
            messages = parse_can(clean)
            for ecu, payload in messages:
                ecus.add(ecu)
                if payload[:1] == b'\x7F':
                    result['negative_responses'].append({'command':command,'ecu':ecu,'payload':payload.hex().upper()}); continue
                service = int(command[:2], 16)
                if not payload or payload[0] != service+0x40:
                    raise ValueError('response service mismatch')
                if service in (1, 9, 0x21) and (len(payload)<2 or payload[1] != int(command[2:],16)):
                    raise ValueError('response PID mismatch')
                if service == 1:
                    pid, data = payload[1], payload[2:]
                    if pid in BITMAPS:
                        supported[ecu].update(supported_pids(pid,data))
                    elif pid == 1:
                        result['readiness'].append({'ecu':ecu,'payload':data.hex().upper()})
                    elif pid in LIVE_LENGTH:
                        value = decode_pid(pid,data)
                        result['samples'].append({'utc':r['utc'],'time':r['monotonic_seconds'], 'ecu':ecu,
                            'pid':f'{pid:02X}', 'value':value,'payload':payload.hex().upper()})
                        times[(ecu, pid)].append(r['monotonic_seconds'])
                elif service == 9:
                    if payload[1] == 0:
                        result['information_supported'][ecu] = [f'{x:02X}' for x in supported_pids(0, payload[2:])]
                        continue
                    result['vehicle_information'].append({'ecu':ecu,'command':command,'payload':payload.hex().upper()})
                elif service == 0x21:
                    result['enhanced_responses'].append({'ecu':ecu,'command':command,'payload':payload.hex().upper(),'utc':r['utc'],'time':r['monotonic_seconds']})
                else:
                    result['fault_responses'].append({'ecu':ecu,'command':command,'payload':payload.hex().upper()})
        except ValueError as e:
            result['parse_failures'].append({'command':command,'utc':r['utc'],'error':str(e)})
    result['ecus'] = sorted(ecus)
    result['supported'] = {ecu:[f'{x:02X}' for x in sorted(pids)] for ecu,pids in supported.items()}
    for command, values in latencies.items():
        result['latencies'][command] = {'count':len(values),'median_seconds':statistics.median(values),
              'p95_seconds':sorted(values)[max(0, int(len(values)*0.95+0.999)-1)],'max_seconds':max(values)}
    for (ecu,pid), t in times.items():
        intervals = [b-a for a,b in zip(t,t[1:])]
        result['rates'][f'{ecu}:{pid:02X}'] = {'samples':len(t),
            'observed_hz': (len(t)-1)/(t[-1]-t[0]) if len(t)>1 and t[-1]>t[0] else None,
            'max_gap_seconds':max(intervals) if intervals else None}
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('logs',nargs='+',type=pathlib.Path)
    p.add_argument('--output',type=pathlib.Path,required=True); args=p.parse_args()
    results=[analyze(path) for path in args.logs]
    args.output.write_text(json.dumps(results,indent=2)+'\n'); args.output.chmod(0o600)
    for r in results:
        # Deliberately omit all raw data and vehicle identifiers from console output.
        print(f"{r['log']}: {r['requests']} requests, {r['responses']} replies, {r['timeouts']} timeouts, {len(r['parse_failures'])} decode errors; ECUs {','.join(r['ecus']) or 'not established'}")

if __name__=='__main__': main()
