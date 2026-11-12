"""Scan the proposed evidence and nested ZIP contents without printing values."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

FOLDER = Path(__file__).resolve().parent
REPORT = FOLDER / 'sensitive-scan.json'
RULES = {
    'github_token': r'\b(?:gh[pousr]_[A-Za-z0-9]{16,255}|github_pat_[A-Za-z0-9_]{30,255})\b',
    'aws_access_key': r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
    'slack_token': r'\bxox[baprs]-[A-Za-z0-9-]{15,}\b',
    'private_key': r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'jwt': r'\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{16,}\b',
    'url_user_password': r'https?://[^/\s:@\x22\x27]{1,100}:([^@\s/\x22\x27]{1,250})@',
    'authorization_value': r'(?i)authorization[\x22\x27]?\s*[:=]\s*[\x22\x27]?(?:basic|bearer)\s+([^\s\x22\x27<>]+)',
    'secret_assignment': r'(?i)(?:^|[;\s{\x22\x27])(?:github_token|gh_token|access_token|client_secret|password|passwd|api_key|token)[\x22\x27]?\s*[:=]\s*[\x22\x27]?([^\s\x22\x27<>;,}]{8,})',
    'signed_url_credential': r'(?i)[?&](?:access_token|token|x-amz-signature|x-amz-credential|sig|signature)=([^&\s\x22\x27<>]+)',
}
PATTERNS = {name: re.compile(pattern, re.MULTILINE) for name, pattern in RULES.items()}


def masked(value):
    return bool(re.fullmatch(r'[\*xX]+', value)) or value.startswith(('${', '$(', 'secrets.', 'github.token')) or value in {'REDACTED', '<redacted>', '[REDACTED]'}


def scan():
    counts = Counter()
    hits = []
    ignored = Counter()
    top_files = []

    def visit(name, raw, depth=0):
        assert depth <= 6 and len(raw) <= 32 * 1024 * 1024
        counts['objects'] += 1
        counts['bytes'] += len(raw)
        assert counts['bytes'] <= 256 * 1024 * 1024
        if raw.startswith(b'PK\x03\x04'):
            counts['zip_archives'] += 1
            with zipfile.ZipFile(io.BytesIO(raw)) as z:
                assert z.testzip() is None
                for entry in z.infolist():
                    if not entry.is_dir():
                        assert entry.file_size <= 32 * 1024 * 1024
                        visit(name + '!' + entry.filename, z.read(entry), depth + 1)
            return
        counts['payloads'] += 1
        text = raw.decode('utf-8', errors='replace')
        for rule, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                value = match.group(1) if match.lastindex else match.group()
                if masked(value):
                    ignored[rule] += 1
                    continue
                hits.append({'path': name, 'line': text.count('\n', 0, match.start()) + 1, 'rule': rule})

    paths = sorted(p for p in FOLDER.rglob('*') if p.is_file() and p.name not in {'manifest.json', REPORT.name})
    paths.append(FOLDER.parents[2] / 'validation-report-v0.2.0.md')
    for p in paths:
        raw = p.read_bytes()
        name = p.relative_to(FOLDER.parents[3]).as_posix()
        top_files.append({'file': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
        visit(name, raw)
    return {'status': 'no_unmasked_matches' if not hits else 'requires_review',
            'scanned_at_utc': datetime.now(timezone.utc).isoformat(), 'top_files': top_files,
            'counts': dict(counts), 'rules': list(RULES), 'masked_or_reference_matches': dict(ignored),
            'findings': hits,
            'scope': 'Proposed remote evidence files, recursively including raw logs and artifact ZIPs, plus validation-report-v0.2.0.md. Manifest metadata and this generated receipt are excluded.',
            'boundary': 'Pattern scan plus review of reported locations; not proof of absence of every possible secret. No environment, credential files, or token values are printed.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='record the scan receipt locally')
    args = parser.parse_args()
    result = scan()
    if args.write:
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'no_unmasked_matches' else 2)
