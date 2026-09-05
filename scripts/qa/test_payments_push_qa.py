import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('qa', Path(__file__).with_name('payments_push_qa.py'))
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)

ORDER = '301960c1-1600-4920-a176-d5294c53100b'


class PaymentsPushQaTests(unittest.TestCase):
    def order(self):
        return {'orderId': ORDER, 'userId': 'owner', 'paymentProvider': 'google_play',
                'status': 'succeeded', 'sparkToGrant': 20}

    def entry(self):
        return {'entryId': 'one', 'userId': 'owner', 'reason': 'purchase:' + ORDER,
                'source': 'pack_purchase', 'delta': 20}

    def test_duplicate_credit_fails_even_when_total_looks_valid(self):
        entries = [dict(self.entry(), delta=10), dict(self.entry(), entryId='two', delta=10)]
        with self.assertRaises(qa.QaError):
            qa.purchase_evidence(self.order(), entries, ORDER)

    def test_wrong_owner_amount_provider_or_pending_order_fails(self):
        for changed in [dict(self.order(), status='pending'), dict(self.order(), userId='other'),
                        dict(self.order(), sparkToGrant=19), dict(self.order(), paymentProvider='stripe')]:
            with self.subTest(changed=changed), self.assertRaises(qa.QaError):
                qa.purchase_evidence(changed, [self.entry()], ORDER)

    def test_exact_store_credit_passes_without_exporting_personal_data(self):
        evidence = qa.purchase_evidence(self.order(), [self.entry()], ORDER)
        self.assertEqual({'entryId': 'one', 'delta': 20, 'provider': 'google_play'}, evidence)

    def test_ledger_reads_all_pages(self):
        class Api:
            def request(self, path):
                if 'skip=0&' in path:
                    return {'items': [{'entryId': str(i)} for i in range(100)], 'hasMore': True}
                return {'items': [{'entryId': '100'}], 'hasMore': False}
        self.assertEqual(101, len(qa.ledger(Api())))

    def test_ledger_rejects_overlapping_pages(self):
        class Api:
            def request(self, path):
                return {'items': [{'entryId': str(i)} for i in range(100)], 'hasMore': True}
        with self.assertRaises(qa.QaError):
            qa.ledger(Api())

    def test_origin_rejects_plaintext_credentials_and_query(self):
        for origin in ['http://example.com', 'https://token@example.com',
                       'https://example.com/?secret=x', 'https://example.com/api']:
            with self.subTest(origin=origin), self.assertRaises(qa.QaError):
                qa.api_origin(origin)

    def test_redirect_does_not_forward_authorization(self):
        self.assertIsNone(qa.NoRedirect().redirect_request(None, None, None, None, None, None))

    def test_report_resume_preserves_evidence_and_never_enables_binding(self):
        with tempfile.TemporaryDirectory() as directory:
            report = qa.Report(directory, 'https://api.example.com')
            report.add('contract', 'passed', '10 tests')
            resumed = qa.Report(directory)
            resumed.add('android.ready', 'blocked', 'Unlock the phone')
            data = json.loads(Path(directory, 'report.json').read_text())
            self.assertIn('contract', data['checks'])
            self.assertFalse(data['strictBindingSwitchAllowed'])
            self.assertEqual('needs_verification', data['storeAcceptance'])
            with self.assertRaises(qa.QaError):
                qa.Report(directory, 'https://other.example.com')

    def test_notification_coordinates_come_from_xml_and_route_must_match_package(self):
        tree = ET.fromstring('<hierarchy><node text="qa-event-123456" bounds="[10,20][110,120]" package="com.android.systemui"/><node text="Expected screen" package="other.app"/></hierarchy>')
        self.assertEqual(('60', '70'), qa.center(qa.marker_nodes(tree, 'qa-event-123456')[0]))
        self.assertEqual([], qa.marker_nodes(tree, 'Expected screen', 'com.petmagic.app'))

    def test_ambiguous_or_offscreen_notification_cannot_be_guessed(self):
        node = ET.fromstring('<node bounds="[0,0][0,0]"/>')
        with self.assertRaises(qa.QaError):
            qa.center(node)

    def test_replay_cannot_credit_an_unsettled_order(self):
        from types import SimpleNamespace
        class Api:
            calls = []
            def __init__(self, origin):
                pass
            def request(self, path, body=None):
                self.calls.append(body)
                return dict(PaymentsPushQaTests().order(), status='pending')
        with tempfile.TemporaryDirectory() as directory:
            report = qa.Report(directory, 'https://api.example.com')
            args = SimpleNamespace(order_id=ORDER, phase='replay', receipt_file='must-not-be-read.json')
            with patch.object(qa, 'Api', Api), patch.object(qa, 'ledger', return_value=[]):
                with self.assertRaises(qa.QaError):
                    qa.check_purchase(args, report)
            self.assertEqual([None], Api.calls)

    def test_actual_replay_detects_a_second_credit_and_does_not_export_receipt(self):
        from types import SimpleNamespace
        class Api:
            calls = []
            def __init__(self, origin):
                pass
            def request(self, path, body=None):
                self.calls.append(body)
                return PaymentsPushQaTests().order()
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory, 'private.json')
            receipt.write_text(json.dumps({'paymentProvider': 'google_play', 'productId': 'pack',
                                           'serverVerificationData': 'SECRET_RECEIPT'}))
            report = qa.Report(directory, 'https://api.example.com')
            args = SimpleNamespace(order_id=ORDER, phase='replay', receipt_file=str(receipt))
            with patch.object(qa, 'Api', Api), patch.object(qa, 'ledger', side_effect=[
                    [self.entry()], [self.entry(), dict(self.entry(), entryId='two')]]):
                with self.assertRaises(qa.QaError):
                    qa.check_purchase(args, report)
            self.assertEqual(1, sum(body is not None for body in Api.calls))
            report.save()
            self.assertNotIn('SECRET_RECEIPT', report.path.read_text())

    def test_android_fresh_push_tap_and_terminated_process_are_observed(self):
        from types import SimpleNamespace
        class Android:
            calls = []
            package = 'com.petmagic.app'
            def __init__(self, *args):
                self.screens = iter([
                    '<hierarchy/>',
                    '<hierarchy><node text="qa-event-123456" bounds="[10,20][110,120]"/></hierarchy>',
                    '<hierarchy><node text="Expected destination" package="com.petmagic.app"/></hierarchy>'])
            def ready(self):
                return {'versionCode': '43'}
            def run(self, *args):
                self.calls.append(args)
                return ''
            def ui(self):
                return ET.fromstring(next(self.screens))
        with tempfile.TemporaryDirectory() as directory:
            report = qa.Report(directory, 'https://api.example.com')
            report.data['android'] = {'serial': 'test', 'package': 'com.petmagic.app', 'versionCode': '43'}
            args = SimpleNamespace(device_ready=True, marker='qa-event-123456', route_marker='Expected destination',
                                   adb=None, lifecycle='terminated', timeout=15)
            with patch.object(qa, 'Android', Android):
                qa.observe_push(args, report)
            self.assertEqual('passed', report.data['checks']['android.push.terminated']['status'])
            self.assertIn(('shell', 'am', 'kill', 'com.petmagic.app'), Android.calls)
            self.assertIn(('shell', 'input', 'tap', '60', '70'), Android.calls)
            self.assertNotIn('force-stop', str(Android.calls))
            self.assertNotIn('qa-event-123456', report.path.read_text())

    def test_existing_notification_is_not_accepted_as_new_delivery(self):
        from types import SimpleNamespace
        class Android:
            def __init__(self, *args):
                pass
            def ready(self):
                return {'versionCode': '43'}
            def run(self, *args):
                return ''
            def ui(self):
                return ET.fromstring('<hierarchy><node text="qa-event-123456"/></hierarchy>')
        with tempfile.TemporaryDirectory() as directory:
            report = qa.Report(directory, 'https://api.example.com')
            report.data['android'] = {'serial': 'test', 'package': 'com.petmagic.app', 'versionCode': '43'}
            args = SimpleNamespace(device_ready=True, marker='qa-event-123456', route_marker='destination', adb=None)
            with patch.object(qa, 'Android', Android), self.assertRaises(qa.QaError):
                qa.observe_push(args, report)
            self.assertEqual({}, report.data['checks'])

    def test_concurrent_run_cannot_overwrite_report(self):
        with tempfile.TemporaryDirectory() as directory:
            lock = Path(directory, '.qa.lock')
            lock.write_text('another-process')
            self.assertEqual(2, qa.main(['run', '--api-base-url', 'https://api.example.com', '--run-dir', directory]))
            self.assertEqual('another-process', lock.read_text())
            self.assertFalse(Path(directory, 'report.json').exists())

    def test_zero_or_skipped_contract_tests_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            trx = Path(directory, 'tests.trx')
            for total, passed in [(0, 0), (5, 4)]:
                trx.write_text(f'<TestRun><Counters total="{total}" passed="{passed}"/></TestRun>')
                with self.assertRaises(qa.QaError):
                    qa.passing_tests(trx)
            trx.write_text('<TestRun xmlns="urn:test"><Counters total="5" passed="5"/></TestRun>')
            self.assertEqual(5, qa.passing_tests(trx))


if __name__ == '__main__':
    unittest.main()
