#!/usr/bin/env python3
"""Failure-path tests; no PostgreSQL, Docker, R2 or production settings are accessed."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / 'deploy/vps/scripts/postgres-backups.py'
SPEC = importlib.util.spec_from_file_location('postgres_backups', SOURCE)
backups = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backups)


class BackupSafetyTests(unittest.TestCase):
    def test_provider_error_does_not_expose_stderr(self):
        result = subprocess.CompletedProcess(['restic'], 1, b'', b'credential=private-value')
        with patch.object(backups.subprocess, 'run', return_value=result):
            with self.assertRaisesRegex(RuntimeError, 'restic operation failed') as caught:
                backups.run(['restic', 'snapshots'])
        self.assertNotIn('private-value', str(caught.exception))

    def test_failed_upload_preserves_local_dump_without_success_marker(self):
        def fake_run(args, **kwargs):
            if args[:2] == ['docker', 'exec']:
                kwargs['stdout'].write(b'local-dump')
            elif args[:2] == ['restic', 'backup']:
                raise RuntimeError('Simulated unavailable object storage')
            return b''

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(backups, 'ROOT', Path(directory)), \
                patch.object(backups, 'database_size', return_value=1024), \
                patch.object(backups, 'run', side_effect=fake_run), \
                patch.object(backups, 'write_status') as status:
            with self.assertRaisesRegex(RuntimeError, 'unavailable'):
                backups.backup({}, 'synthetic-postgres')
            status.assert_not_called()
            self.assertEqual(len(list(Path(directory).rglob('*.custom.dump'))), 1)
            self.assertFalse(list(Path(directory).rglob('*.partial')))

    def test_success_marker_follows_offsite_upload_and_retention_is_scoped(self):
        calls = []

        def fake_run(args, **kwargs):
            calls.append(args)
            if args[:2] == ['docker', 'exec']:
                kwargs['stdout'].write(b'local-dump')
            elif args[:2] == ['restic', 'backup']:
                self.assertFalse((backups.ROOT / 'status/postgres-frequent.json').exists())
                return b'{"message_type":"summary","snapshot_id":"synthetic-snapshot"}\n'
            return b''

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(backups, 'ROOT', Path(directory)), \
                patch.object(backups, 'database_size', return_value=1024), \
                patch.object(backups, 'run', side_effect=fake_run):
            backups.backup({}, 'synthetic-postgres')
            status = json.loads((Path(directory) / 'status/postgres-frequent.json').read_text())
            self.assertEqual(status['snapshot_id'], 'synthetic-snapshot')
        retention = next(args for args in calls if args[:2] == ['restic', 'forget'])
        self.assertEqual(retention[retention.index('--tag') + 1], 'postgres-frequent')
        self.assertEqual(retention[retention.index('--group-by') + 1], 'host,tags')
        self.assertEqual(retention[retention.index('--keep-within') + 1], '24h')

    def test_lock_contention_does_not_enter_maintenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with backups.maintenance_locks(root):
                with self.assertRaises(BlockingIOError):
                    with backups.maintenance_locks(root):
                        self.fail('Concurrent maintenance acquired an exclusive lock')
            with backups.maintenance_locks(root):
                pass

    def test_stale_or_future_success_marker_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(backups, 'ROOT', Path(directory)):
            backups.write_status('postgres-frequent', {'completed_at': 10000})
            backups.write_status('postgres-nightly', {'completed_at': 10000})
            backups.write_status('postgres-restore', {'completed_at': 10000})
            backups.check_freshness(now=10001)
            for now in (9999, 13000):
                with self.assertRaisesRegex(RuntimeError, 'stale'):
                    backups.check_freshness(now=now)

    def test_stale_full_backup_fails_even_when_database_backups_are_fresh(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(backups, 'ROOT', Path(directory)):
            backups.write_status('postgres-frequent', {'completed_at': 200000})
            backups.write_status('postgres-restore', {'completed_at': 200000})
            backups.write_status('postgres-nightly', {'completed_at': 1})
            with self.assertRaisesRegex(RuntimeError, 'postgres-nightly is stale'):
                backups.check_freshness(now=200001)

    def test_corrupt_restored_dump_cannot_start_a_database(self):
        calls = []

        def fake_run(args, **kwargs):
            calls.append(args)
            if args[:2] == ['restic', 'snapshots']:
                return b'[{"id":"synthetic","time":"2026-09-05T00:00:00Z"}]'
            if args[:2] == ['restic', 'restore']:
                destination = Path(args[args.index('--target') + 1])
                destination.mkdir()
                (destination / 'test.custom.dump').write_bytes(b'corrupted')
                (destination / 'test.custom.dump.sha256').write_text('incorrect-hash  test.custom.dump\n')
            return b''

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(backups, 'ROOT', Path(directory)), \
                patch.object(backups, 'database_size', return_value=1024), \
                patch.object(backups, 'run', side_effect=fake_run):
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                backups.verify({}, 'synthetic-postgres')
            self.assertFalse(list(Path(directory).glob('restore-check-*')))
        self.assertFalse(any(args[:2] == ['docker', 'run'] for args in calls))


if __name__ == '__main__':
    unittest.main()
