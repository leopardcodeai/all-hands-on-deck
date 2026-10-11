import tempfile
import unittest
from pathlib import Path
from write_ci_xcconfig import encode_value, write_config


class CIConfigTests(unittest.TestCase):
    def test_urls_are_not_xcconfig_comments(self):
        self.assertEqual(encode_value('https://example.com/path'), 'https:/$()/example.com/path')

    def test_rejects_multiline_settings(self):
        with self.assertRaises(ValueError):
            encode_value('value\nOTHER = value')

    def test_preserves_provided_config(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Secrets.xcconfig'
            write_config({'SUPABASE_URL': 'https://example.supabase.co', 'SUPABASE_ANON_KEY': 'a.b.c'}, path)
            content = path.read_text()
            self.assertIn('SUPABASE_URL = https:/$()/example.supabase.co\n', content)
            self.assertIn('SUPABASE_ANON_KEY = a.b.c\n', content)

    def test_absent_secrets_use_test_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Secrets.xcconfig'
            write_config({'SUPABASE_URL': 'https://example.supabase.co'}, path)
            content = path.read_text()
            self.assertIn('ci-test.supabase.co', content)
            self.assertIn('test-only.anon.not-a-real-signature', content)


if __name__ == '__main__':
    unittest.main()
