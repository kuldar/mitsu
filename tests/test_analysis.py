import json
import pathlib
import tempfile
import unittest
from tools.analyze import analyze

class AnalysisTests(unittest.TestCase):
    def test_enhanced_response_is_not_a_fault_and_09_bitmap_is_recorded(self):
        rows=[{'event':'response','command':'0900','raw':'7E8 06 49 00 55 00 00 00\r',
               'latency_seconds':.1,'utc':'fixture','monotonic_seconds':1},
              {'event':'response','command':'2104','raw':'7B7 07 61 04 10 00 10 00 00\r',
               'latency_seconds':.1,'utc':'fixture','monotonic_seconds':2}]
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'fixture.jsonl';p.write_text('\n'.join(json.dumps(r) for r in rows))
            result=analyze(p)
        self.assertEqual(result['information_supported'],{'7E8':['02','04','06','08']})
        self.assertEqual(result['fault_responses'],[])
        self.assertEqual(len(result['enhanced_responses']),1)

    def test_enhanced_identifier_mismatch_is_rejected(self):
        row={'event':'response','command':'2104','raw':'7B7 04 61 03 10 00\r',
             'latency_seconds':.1,'utc':'fixture','monotonic_seconds':1}
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'fixture.jsonl';p.write_text(json.dumps(row))
            result=analyze(p)
        self.assertEqual(result['enhanced_responses'],[])
        self.assertEqual(len(result['parse_failures']),1)
