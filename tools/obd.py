"""Strict read-only command policy and CAN/ISO-TP decoding. No I/O or VIN printing."""
import re

ADAPTER_COMMANDS = frozenset(['ATAR', 'ATI', 'AT@1', 'ATDP', 'ATDPN', 'ATRV', 'ATCS',
    'ATE0', 'ATL0', 'ATS1', 'ATH1', 'ATD0', 'ATCAF1', 'ATCFC1', 'ATAT1', 'ATST64',
    'ATM0', 'ATSP0', 'ATSP6', 'ATSH7DF'])
LIVE_LENGTH = {0x04:1, 0x05:1, 0x0C:2, 0x0D:1, 0x0F:1, 0x10:2, 0x11:1,
               0x2F:1, 0x42:2, 0x5E:2}
BITMAPS = set(range(0, 0xE1, 0x20))
READS = frozenset([f'01{x:02X}' for x in BITMAPS | set(LIVE_LENGTH) | {1}] +
                  ['0900', '0902', '0904', '0906', '090A', '03', '07', '0A'])

def allowed_command(command):
    # No control characters, arbitrary AT commands, service ranges or appended frames.
    return isinstance(command, str) and command in ADAPTER_COMMANDS | READS

class PromptBuffer:
    def __init__(self):
        self.data = bytearray()
        self.done = False
    def feed(self, chunk):
        if self.done:
            raise ValueError('unsolicited bytes after prompt')
        self.data.extend(chunk)
        if len(self.data) > 65536:
            raise ValueError('response exceeds bound')
        if b'>' not in self.data:
            return None
        before, after = bytes(self.data).split(b'>', 1)
        if after.strip():
            raise ValueError('multiple/unsolicited responses')
        self.done = True
        return before

def supported_pids(base, payload):
    if len(payload) != 4 or base not in BITMAPS:
        raise ValueError('invalid capability bitmap')
    bits = int.from_bytes(payload, 'big')
    return [base+i+1 for i in range(32) if bits & (1 << (31-i))]

def decode_pid(pid, data):
    if pid not in LIVE_LENGTH or len(data) != LIVE_LENGTH[pid]:
        raise ValueError('unknown PID or wrong payload length')
    a, n = data[0], int.from_bytes(data, 'big')
    if pid in (0x04, 0x11, 0x2F): return a*100/255
    if pid in (0x05, 0x0F): return a-40
    if pid == 0x0C: return n/4
    if pid == 0x0D: return a
    if pid == 0x10: return n/100
    if pid == 0x42: return n/1000
    if pid == 0x5E: return n/20

def parse_can(text):
    """ELM ATH1 ATS1 ATD0 ATCAF1, 11-bit CAN. Retains source ECU, rejects gaps.

    Unrecognized lines fail closed. Never searches for 41/49 inside arbitrary bytes.
    """
    rows, pending = [], {}
    for line in re.split(r'[\r\n]+', text.replace('>', '')):
        line = line.strip()
        if not line or line == 'SEARCHING...': continue
        if not re.fullmatch(r'[0-9A-Fa-f]{3}(?: [0-9A-Fa-f]{2}){2,8}', line):
            raise ValueError('unexpected CAN response line')
        parts = line.split()
        ecu, data = parts[0].upper(), bytes.fromhex(''.join(parts[1:]))
        kind = data[0] >> 4
        if kind == 0:
            count = data[0] & 15
            if not 1 <= count <= 7 or len(data)-1 < count:
                raise ValueError('truncated single frame')
            rows.append((ecu, data[1:1+count]))
        elif kind == 1:
            if ecu in pending or len(data) != 8: raise ValueError('invalid first frame')
            total = ((data[0] & 15) << 8) | data[1]
            if total <= 7: raise ValueError('invalid multi-frame length')
            pending[ecu] = (total, bytearray(data[2:]), 1)
        elif kind == 2:
            if ecu not in pending: raise ValueError('orphan consecutive frame')
            total, collected, sequence = pending[ecu]
            if data[0] & 15 != sequence: raise ValueError('ISO-TP sequence gap')
            collected.extend(data[1:])
            if len(collected) >= total:
                rows.append((ecu, bytes(collected[:total])))
                del pending[ecu]
            else: pending[ecu] = (total, collected, (sequence+1) & 15)
        else: raise ValueError('unexpected PCI type')
    if pending: raise ValueError('incomplete multi-frame response')
    if not rows: raise ValueError('empty diagnostic response')
    return rows
