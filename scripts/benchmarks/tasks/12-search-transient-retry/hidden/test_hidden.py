import unittest
from app.transport.courier import dispatch


class Channel:
    def __init__(self, failures, error=ConnectionResetError):
        self.failures, self.error, self.calls = failures, error, 0

    def send(self, blob):
        self.calls += 1
        if self.calls <= self.failures:
            raise self.error('flaky')
        return 'receipt'


class Hidden(unittest.TestCase):
    def test_retries_transient(self):
        channel = Channel(2)
        self.assertEqual(dispatch(b'x', channel), 'receipt')
        self.assertEqual(channel.calls, 3)

    def test_gives_up_after_three(self):
        channel = Channel(5)
        with self.assertRaises(ConnectionResetError):
            dispatch(b'x', channel)
        self.assertEqual(channel.calls, 3)

    def test_no_retry_for_other_errors(self):
        channel = Channel(1, ValueError)
        with self.assertRaises(ValueError):
            dispatch(b'x', channel)
        self.assertEqual(channel.calls, 1)
