import unittest

from validate_public import validate_file


class PublicValidationTests(unittest.TestCase):
    def test_valid_rules_and_list(self):
        self.assertEqual(validate_file("rule_provider/custom/Lenovo.yaml", b"payload:\n  - IP-CIDR,10.1.2.3/32\n"), {"10.1.2.3"})
        self.assertEqual(validate_file("openclash/custom/lenovo_intranet_ips.list", b"10.1.2.3\n"), {"10.1.2.3"})

    def test_blocks_config_and_credentials(self):
        cases = [
            ("config/config_full.yaml", b"payload: []\n"),
            ("rule_provider/custom/Test.yaml", b"payload: []\n" + b"proxies" + b": []\n"),
            ("README.md", b"private" + b"-key: unsafe\n"),
            ("README.md", b"vless" + b"://example\n"),
            ("README.md", b"https://example.test/?" + b"token=example\n"),
            ("README.md", b"-----BEGIN " + b"PRIVATE KEY-----\n"),
        ]
        for path, data in cases:
            with self.subTest(path=path, data_type=len(data)):
                with self.assertRaises(ValueError):
                    validate_file(path, data)

    def test_rejects_duplicate_keys_and_wide_lenovo_cidr(self):
        for data in (b"payload: []\npayload: []\n", b"payload:\n  - IP-CIDR,10.0.0.0/8\n"):
            with self.assertRaises(ValueError):
                validate_file("rule_provider/custom/Lenovo.yaml", data)


if __name__ == "__main__":
    unittest.main()