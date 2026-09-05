#!/usr/bin/env python3
"""Online PostgreSQL backups and isolated off-site restore verification."""

import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path('/opt/petmagic/shared/backups')
ENV_FILE = Path('/opt/petmagic/shared/env/.env.vps')
PASSWORD_FILE = Path('/opt/petmagic/shared/env/restic-password')
DEPLOY_ROOT = Path('/opt/petmagic/current')
TAG = 'postgres-frequent'


def run(args, *, env=None, stdout=subprocess.PIPE, timeout=600):
    result = subprocess.run(args, env=env, stdout=stdout, stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        # Provider output can contain connection details. Never emit it to journals.
        raise RuntimeError(f'{args[0]} operation failed (exit {result.returncode})')
    return result.stdout


def restic_environment():
    for path in (ENV_FILE, PASSWORD_FILE):
        if path.stat().st_uid != 0 or path.stat().st_mode & 0o777 != 0o600:
            raise RuntimeError('Backup configuration must be root-owned and mode 0600')
    values = {}
    for line in ENV_FILE.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep and key and not key.startswith('#'):
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                value = value[1:-1]
            values[key] = value
    access = values.get('PETMAGIC_BACKUP_R2_ACCESS_KEY') or values['R2_ACCESS_KEY']
    secret = values.get('PETMAGIC_BACKUP_R2_SECRET_KEY') or values['R2_SECRET_KEY']
    env = os.environ.copy()
    env.update(AWS_ACCESS_KEY_ID=access, AWS_SECRET_ACCESS_KEY=secret,
               AWS_DEFAULT_REGION='auto', RESTIC_PASSWORD_FILE=str(PASSWORD_FILE),
               RESTIC_REPOSITORY='s3:https://' + values['R2_ACCOUNT_ID'] +
               '.r2.cloudflarestorage.com/' + values['PETMAGIC_BACKUP_R2_BUCKET'] + '/petmagic-vps')
    return env


@contextlib.contextmanager
def maintenance_locks(lock_root=Path('/run/petmagic')):
    # Same order as a release followed by a backup; never overlap a nightly copy.
    with contextlib.ExitStack() as stack:
        for name in ('release.lock', 'backup-job.lock'):
            handle = stack.enter_context(open(lock_root / name, 'a'))
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def postgres_container():
    run(['systemctl', 'is-active', '--quiet', 'petmagic-compose.service'])
    args = ['docker', 'compose', '--env-file', str(ENV_FILE), '-f',
            str(DEPLOY_ROOT / 'docker-compose.yml'), '-f',
            str(DEPLOY_ROOT / 'deploy/vps/compose.vps.yaml'), 'ps', '-q', 'postgres']
    container = run(args).decode().strip()
    if not container or '\n' in container:
        raise RuntimeError('Expected exactly one running production PostgreSQL container')
    return container


def database_size(container):
    return int(run(['docker', 'exec', container, 'psql', '-XAt', '-U', 'petmagic_user',
                    '-d', 'petmagic_db', '-c', "SELECT pg_database_size('petmagic_db');"]))


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def write_status(name, data):
    directory = ROOT / 'status'
    directory.mkdir(mode=0o700, exist_ok=True)
    path = directory / (name + '.json')
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data) + '\n')
    temporary.replace(path)


def retention_args():
    # Filenames contain timestamps: grouping by paths would retain every snapshot.
    return ['forget', '--tag', TAG, '--host', socket.gethostname(), '--group-by', 'host,tags',
            '--keep-within', '24h', '--keep-daily', '14', '--keep-weekly', '8', '--keep-monthly', '12']


def backup(env, container):
    directory = ROOT / 'postgres-frequent'
    directory.mkdir(mode=0o700, exist_ok=True)
    size = database_size(container)
    if shutil.disk_usage(directory).free < size * 2 + 512 * 1024**2:
        raise RuntimeError('Insufficient disk space for PostgreSQL backup')
    name = dt.datetime.now(dt.timezone.utc).strftime('petmagic-%Y%m%dT%H%M%S%fZ.custom.dump')
    dump = directory / name
    partial = dump.with_suffix('.partial')
    try:
        with partial.open('wb') as stream:
            run(['docker', 'exec', container, 'pg_dump', '-U', 'petmagic_user', '-d', 'petmagic_db',
                 '--format=custom', '--no-owner', '--no-privileges', '--lock-wait-timeout=30s'], stdout=stream)
        if partial.stat().st_size == 0:
            raise RuntimeError('PostgreSQL produced an empty dump')
        run(['pg_restore', '--list', str(partial)])
        partial.replace(dump)
        checksum = sha256(dump)
        checksum_file = Path(str(dump) + '.sha256')
        checksum_file.write_text(checksum + '  ' + dump.name + '\n')
        output = run(['restic', 'backup', '--json', '--tag', TAG, '--tag', socket.gethostname(),
                      '--group-by', 'host,tags', str(dump), str(checksum_file)], env=env)
        summaries = [json.loads(line) for line in output.splitlines()]
        snapshot = next(item['snapshot_id'] for item in summaries if item.get('message_type') == 'summary')
        write_status('postgres-frequent', {'completed_at': time.time(), 'snapshot_id': snapshot,
                                          'database_bytes': size, 'dump_sha256': checksum})
        run(['restic', *retention_args()], env=env)
        # Local retention runs only after a successful encrypted off-site upload.
        cutoff = time.time() - 3 * 86400
        for candidate in directory.glob('petmagic-*.custom.dump*'):
            if candidate.is_file() and not candidate.is_symlink() and candidate.stat().st_mtime < cutoff:
                candidate.unlink()
        print('Online PostgreSQL backup uploaded and verified: snapshot=' + snapshot, flush=True)
    finally:
        partial.unlink(missing_ok=True)


def verify(env, container):
    size = database_size(container)
    if shutil.disk_usage(ROOT).free < size * 4 + 1024**3:
        raise RuntimeError('Insufficient disk space for an isolated restore')
    run(['restic', 'check', '--read-data'], env=env, timeout=1800)
    snapshots = json.loads(run(['restic', 'snapshots', '--json', '--tag', TAG,
                               '--host', socket.gethostname()], env=env))
    if not snapshots:
        raise RuntimeError('No frequent off-site PostgreSQL snapshot exists')
    snapshot = max(snapshots, key=lambda item: item['time'])
    name = 'petmagic-backup-verify-' + str(os.getpid())
    created = False
    with tempfile.TemporaryDirectory(prefix='restore-check-', dir=ROOT) as temporary:
        scratch = Path(temporary)
        restored = scratch / 'restored'
        run(['restic', 'restore', snapshot['id'], '--verify', '--target', str(restored)], env=env)
        dumps = list(restored.rglob('*.custom.dump'))
        if len(dumps) != 1:
            raise RuntimeError('Expected exactly one restored PostgreSQL dump')
        dump = dumps[0]
        if sha256(dump) != Path(str(dump) + '.sha256').read_text().split()[0]:
            raise RuntimeError('Restored PostgreSQL dump checksum mismatch')
        data = scratch / 'postgres'
        data.mkdir(mode=0o700)
        image = run(['docker', 'inspect', container, '--format', '{{.Image}}']).decode().strip()
        try:
            run(['docker', 'run', '-d', '--rm', '--name', name, '--network', 'none', '--memory', '1g',
                 '--cpus', '1', '--mount', f'type=bind,src={restored},dst=/restore,readonly',
                 '--mount', f'type=bind,src={data},dst=/var/lib/postgresql/data',
                 '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_USER=petmagic_user',
                 '-e', 'POSTGRES_DB=petmagic_restore', image])
            created = True
            for attempt in range(60):
                ready = subprocess.run(['docker', 'exec', name, 'pg_isready', '-U', 'petmagic_user',
                                        '-d', 'petmagic_restore'], capture_output=True, timeout=10)
                if ready.returncode == 0:
                    break
                time.sleep(1)
            else:
                raise RuntimeError('Isolated PostgreSQL did not become ready')
            path = '/restore/' + dump.relative_to(restored).as_posix()
            run(['docker', 'exec', name, 'pg_restore', '--exit-on-error', '--no-owner',
                 '--no-privileges', '-U', 'petmagic_user', '-d', 'petmagic_restore', path])
            query = ('SELECT count(*) FROM information_schema.tables WHERE table_schema=\'public\'; '
                     'SELECT count(*) FROM "__EFMigrationsHistory";')
            counts = run(['docker', 'exec', name, 'psql', '-XAt', '-v', 'ON_ERROR_STOP=1',
                          '-U', 'petmagic_user', '-d', 'petmagic_restore', '-c', query]).decode().splitlines()
            tables, migrations = map(int, counts)
            if min(tables, migrations) <= 0:
                raise RuntimeError('Restored database contains no application schema')
            write_status('postgres-restore', {'completed_at': time.time(), 'snapshot_id': snapshot['id'],
                                             'tables': tables, 'migrations': migrations})
            print(f'Off-site restore passed: tables={tables}, migrations={migrations}', flush=True)
        finally:
            if created:
                run(['docker', 'stop', '-t', '30', name], timeout=45)


def check_freshness(now=None):
    now = time.time() if now is None else now
    for name, age in (('postgres-frequent', 45 * 60), ('postgres-nightly', 30 * 3600),
                      ('postgres-restore', 8 * 86400)):
        status = json.loads((ROOT / 'status' / (name + '.json')).read_text())
        if not 0 <= now - status['completed_at'] <= age:
            raise RuntimeError(name + ' is stale')


def interrupted(signum, frame):
    raise RuntimeError('Backup operation interrupted; incomplete work is not marked successful')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('backup', 'verify', 'check'))
    action = parser.parse_args().action
    if os.geteuid() != 0 or socket.gethostname() != 'vps-fea3ac06':
        raise RuntimeError('Run as root on the dedicated PetMagic VPS')
    os.umask(0o077)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    if action == 'check':
        check_freshness()
        print('PostgreSQL off-site backup and restore verification are fresh')
        return
    with maintenance_locks():
        env = restic_environment()
        container = postgres_container()
        (backup if action == 'backup' else verify)(env, container)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        print('PostgreSQL backup operation failed: ' + type(error).__name__ +
              (': ' + str(error) if isinstance(error, RuntimeError) else ''), file=sys.stderr)
        sys.exit(1)
