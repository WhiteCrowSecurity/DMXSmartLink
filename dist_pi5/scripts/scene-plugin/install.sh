#!/bin/sh
set -eu
exec python3 - "$@" <<'DMXSL_SCENE_PY'
"""Checked, reversible replacement of Govee scene-readback runtime files."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import uuid

FILES = ('lib/device/light.js', 'lib/utils/custom-chars.js', 'lib/utils/scene-readback.js', 'lib/utils/device-context.js')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def validate(root, manifest, content):
    """Return original/patched only for a complete matching set; reject mixtures."""
    root = Path(root).resolve()
    package = json.loads((root / 'package.json').read_text(encoding='utf-8'))
    if package.get('name') != '@homebridge-plugins/homebridge-govee' or package.get('version') != manifest['version']:
        raise ValueError('Installed plugin package/version mismatch')
    if set(content) != set(FILES):
        raise ValueError('Unexpected candidate files')
    original, patched = True, True
    for name in FILES:
        path = root / name
        if path.is_symlink() or root not in path.resolve().parents:
            raise ValueError('Unexpected plugin path')
        expected = manifest['files'][name]
        actual = sha(path)
        original = original and actual == expected['original_sha256']
        patched = patched and actual == expected['patched_sha256']
        if hashlib.sha256(content[name]).hexdigest() != expected['patched_sha256']:
            raise ValueError('Candidate file differs: ' + name)
    if patched:
        return 'patched'
    if original:
        return 'original'
    raise ValueError('Installed plugin differs or has mixed original/patched files')


def replace(path, data, metadata=None):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('xb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, metadata['mode'] if metadata else 0o644)
        if metadata and hasattr(os, 'chown'):
            os.chown(temporary, metadata['uid'], metadata['gid'])
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def install(root, manifest, content, backup, *, stop, start, healthy):
    """Callbacks operate one already-running container; failures restore changed files.

    The caller must gate live activity and select the intended host/container.
    Backups and recovery receipts remain even after a failure; never auto-retry.
    """
    root, backup = Path(root).resolve(), Path(backup).resolve()
    if validate(root, manifest, content) == 'patched':
        # No lifecycle action or backup overwrite on a repeated update. This is
        # file-state verification, not a new claim about process health.
        return {'root':str(root), 'state':'already_installed', 'changed':[]}
    if backup.exists() or backup == root or root in backup.parents:
        raise ValueError('Backup must be a new directory outside the plugin')
    backup.mkdir(parents=True)
    metadata = {}
    for name in FILES:
        path = root / name
        if path.exists():
            st = path.stat()
            metadata[name] = {'mode':st.st_mode & 0o7777,'uid':st.st_uid,'gid':st.st_gid}
            saved = backup / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
        else:
            metadata[name] = None
    receipt = {'root':str(root),'manifest':manifest,'metadata':metadata,'state':'prepared','changed':[]}
    receipt_path = backup / 'receipt.json'
    def record():
        replace(receipt_path, json.dumps(receipt,indent=2).encode())
    record()
    try:
        stop()
        if validate(root, manifest, content) != 'original':
            raise ValueError('Plugin changed after preflight')
        for name in FILES:
            # Include a path before replacement so failures after rename are recoverable.
            receipt['changed'].append(name)
            record()
            replace(root / name, content[name], metadata[name])
        for name in FILES:
            if sha(root / name) != manifest['files'][name]['patched_sha256']:
                raise ValueError('Installed candidate hash mismatch')
        start()
        if not healthy():
            raise RuntimeError('Candidate did not become healthy')
        receipt['state'] = 'installed'
        record()
        return receipt
    except Exception as error:
        receipt['error_type'] = type(error).__name__
        try:
            # Do not replace imported modules while the failed candidate is running.
            stop()
            for name in reversed(receipt['changed']):
                previous = manifest['files'][name]['original_sha256']
                if previous is None:
                    (root / name).unlink(missing_ok=True)
                else:
                    saved = backup / name
                    if sha(saved) != previous:
                        raise ValueError('Backup hash mismatch')
                    replace(root / name, saved.read_bytes(), metadata[name])
            start()
            if not healthy():
                raise RuntimeError('Original plugin did not recover')
            receipt['state'] = 'rolled_back'
        except Exception as recovery_error:
            receipt['state'] = 'recovery_required'
            receipt['recovery_error_type'] = type(recovery_error).__name__
        record()
        raise RuntimeError('Plugin installation failed: ' + receipt['state'] + '; receipt: ' + str(receipt_path)) from None

"""Read the pinned scene-plugin bundle without extracting archive paths."""
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile


MAX_BYTES = 1024 * 1024


def load_bundle(path, expected_sha256):
    """The expected digest must come from the release, not from the archive."""
    if not re.fullmatch('[0-9a-f]{64}', expected_sha256 or ''):
        raise ValueError('Expected pinned bundle SHA256')
    with Path(path).open('rb') as stream:
        raw = stream.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError('Bundle too large')
    if hashlib.sha256(raw).hexdigest() != expected_sha256:
        raise ValueError('Bundle SHA256 mismatch')
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        infos = archive.infolist()
        allowed = set(FILES) | {'manifest.json', 'LICENSE'}
        if len(infos) != len(allowed) or {i.filename for i in infos} != allowed:
            raise ValueError('Unexpected or duplicate bundle entries')
        if sum(i.file_size for i in infos) > MAX_BYTES:
            raise ValueError('Expanded bundle too large')
        for info in infos:
            if info.is_dir() or (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError('Unexpected bundle entry type')
        manifest = json.loads(archive.read('manifest.json'))
        if manifest.get('format') != 1 or manifest.get('package') != '@homebridge-plugins/homebridge-govee' or manifest.get('version') != '11.39.0':
            raise ValueError('Unsupported bundle identity')
        if not re.fullmatch('[0-9a-f]{40}', manifest.get('candidate_commit', '')):
            raise ValueError('Expected immutable candidate')
        if set(manifest.get('files', {})) != set(FILES):
            raise ValueError('Unexpected manifest file set')
        content = {name: archive.read(name) for name in FILES}
        for name, data in content.items():
            if hashlib.sha256(data).hexdigest() != manifest['files'][name]['patched_sha256']:
                raise ValueError('Runtime hash mismatch: ' + name)
        license_text = archive.read('LICENSE')
        if not license_text.strip() or hashlib.sha256(license_text).hexdigest() != manifest.get('license_sha256'):
            raise ValueError('License hash mismatch')
    return manifest, content

"""Linux Docker adapter for the verified scene bundle; explicit --apply required."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.request
import uuid


PINNED_SHA256 = 'def32266added41e3ad402335224181293ce89111f0b9fd2dabe0207aa9ef5df'


def command(args, timeout=20):
    r = subprocess.run(args, capture_output=True, timeout=timeout)
    if r.returncode:
        raise RuntimeError('Homebridge container operation failed')
    return r.stdout


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--container', default='homebridge')
    p.add_argument('--apply', action='store_true')
    a = p.parse_args()
    manifest, content = load_bundle(a.bundle, PINNED_SHA256)
    # Parse only needed Docker fields; never publish environment/config secrets.
    details = json.loads(command(['docker', 'inspect', a.container]))[0]
    if not details['State']['Running']:
        raise ValueError('Homebridge must already be running')
    mounts = [m for m in details['Mounts'] if m.get('Destination') == '/homebridge' and m.get('Type') == 'bind']
    if len(mounts) != 1:
        raise ValueError('Expected one Homebridge bind mount')
    data_root = Path(mounts[0]['Source']).resolve(strict=True)
    root = data_root / 'node_modules/@homebridge-plugins/homebridge-govee'
    if data_root not in root.resolve().parents:
        raise ValueError('Plugin outside Homebridge data mount')
    state = validate(root, manifest, content)
    result = {'preflight_passed': True, 'installed_state': state, 'applied': False}
    if a.apply:
        import fcntl
        # One installer owns the entire stop/replace/start/recovery transaction.
        with (data_root / '.dmxsmartlink-scene-install.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            container_id = details['Id']
            def stop(): command(['docker', 'stop', '--time', '10', container_id], 25)
            def start(): command(['docker', 'start', container_id])
            def healthy():
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    try:
                        current = json.loads(command(['docker', 'inspect', container_id]))[0]
                        if not current['State']['Running']: return False
                        with urllib.request.urlopen('http://127.0.0.1:8581/', timeout=2) as response:
                            if response.status == 200: return True
                    except Exception: pass
                    time.sleep(1)
                return False
            backup = data_root / 'dmxsmartlink-plugin-backups' / ('scene-' + uuid.uuid4().hex)
            receipt = install(root, manifest, content, backup, stop=stop, start=start, healthy=healthy)
            result.update(state=receipt['state'], applied=receipt['state'] == 'installed',
                          backup=str(backup) if receipt['state'] == 'installed' else None)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
DMXSL_SCENE_PY
