import unittest

from app.auth.security import new_token, token_hash


class SecurityTests(unittest.TestCase):
    def test_tokens_are_random_and_only_digest_is_fixed_length(self):
        first = new_token()
        second = new_token()
        self.assertNotEqual(first, second)
        self.assertEqual(len(token_hash(first)), 64)
        self.assertNotEqual(first, token_hash(first))


if __name__ == "__main__":
    unittest.main()
