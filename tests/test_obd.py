import unittest
from tools.obd import allowed_command, parse_can, decode_pid, supported_pids, PromptBuffer

class OBDTests(unittest.TestCase):
    def test_rejects_state_changes_and_injection(self):
        for command in ['04', '2701', '1003', '3101', '2E123400', 'ATMA', 'ATCSM0', 'ATSH123', '010C\r04', '', '\r']:
            self.assertFalse(allowed_command(command), command)
        for command in ['ATI', 'ATRV', '0100', '010C', '0902', '03', '07', '0A']:
            self.assertTrue(allowed_command(command), command)
    def test_split_prompt(self):
        p = PromptBuffer()
        self.assertIsNone(p.feed(b'7E8 04 41 0C 1A'))
        self.assertEqual(p.feed(b' F8\r>'), b'7E8 04 41 0C 1A F8\r')
        with self.assertRaises(ValueError): p.feed(b'late')
    def test_isotp_single_frame_length_and_multi_ecu(self):
        rows = parse_can('7E8 04 41 0C 1A F8 00 00 00\r7E9 04 41 0C 00 00 00 00 00\r>')
        self.assertEqual(rows, [('7E8', bytes.fromhex('410C1AF8')), ('7E9', bytes.fromhex('410C0000'))])
        with self.assertRaises(ValueError): parse_can('7E8 04 41 0C 1A\r>')
    def test_isotp_vin_reassembly_and_missing_sequence(self):
        fixture = '7E8 10 14 49 02 01 41 42 43\r7E8 21 44 45 46 47 48 49 4A\r7E8 22 4B 4C 4D 4E 4F 50 51\r>'
        self.assertEqual(parse_can(fixture)[0][1], bytes.fromhex('490201')+b'ABCDEFGHIJKLMNOPQ')
        with self.assertRaises(ValueError): parse_can(fixture.replace('7E8 21', '7E8 23'))
        with self.assertRaises(ValueError): parse_can(fixture.split('7E8 22')[0]+'>')
    def test_empty_prompt_is_not_a_complete_diagnostic_reply(self):
        with self.assertRaises(ValueError): parse_can('\r>')
    def test_decode_and_bitmap(self):
        self.assertEqual(decode_pid(0x0c, bytes.fromhex('1AF8')), 1726)
        self.assertEqual(decode_pid(0x05, b'\x50'), 40)
        self.assertEqual(decode_pid(0x42, bytes.fromhex('36B0')), 14)
        self.assertEqual(supported_pids(0, bytes.fromhex('80000001')), [1, 32])
        with self.assertRaises(ValueError): decode_pid(0x0c, b'\x1A')

if __name__ == '__main__': unittest.main()
