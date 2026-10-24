import tempfile
import unittest
from pathlib import Path
from tools.audit_public import audit

class PublicAuditTests(unittest.TestCase):
    def test_local_profiles_signing_artifacts_and_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'VehicleIdentity.local.json').write_text('{}')
            (root/'certificate.p12').write_bytes(b'not a certificate')
            (root/'link').symlink_to('VehicleIdentity.local.json')
            names={p for p,_ in audit(root)}
            self.assertEqual(names,{'VehicleIdentity.local.json','certificate.p12','link'})
    def test_binary_home_and_device_identifiers_are_detected_without_printing_values(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'image.bin').write_bytes(b'header'+b'/Users/'+b'example'+b'/secret\0')
            (root/'device.txt').write_text('00000000'+'-'+'0'*16)
            self.assertEqual({p for p,_ in audit(root)},{'image.bin','device.txt'})
    def test_release_detects_ignored_outputs_and_source_archives(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'build').mkdir()
            (root/'build'/'binary').write_bytes(b'generated')
            folder=root/'assets'/'source';folder.mkdir(parents=True)
            (folder/'model.txt').write_text('not redistributable')
            self.assertEqual({p for p,_ in audit(root,release=True)},{'build','assets/source/model.txt'})
    def test_safe_template_passes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'project.yml').write_text('DEVELOPMENT_TEAM: ""\nPRODUCT_BUNDLE_IDENTIFIER: com.example.mitsu\n')
            self.assertEqual(audit(root),[])
