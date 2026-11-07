"""S0 evidence acquisition; developer-only, network required."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.cache'
CACHE.mkdir(exist_ok=True)

def fetch(item):
    name, url = item
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'MoonXPT-research/0.1.0'})
        with urllib.request.urlopen(req, timeout=60) as response:
            data = response.read()
        path = CACHE / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return {'name': name, 'url': url, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'status': 'downloaded', 'xpt_v5': data.startswith(b'HEADER RECORD*******LIBRARY')}
    except Exception as error:
        return {'name': name, 'url': url, 'status': 'failed', 'error': str(error)}

items = [(f'corpus/{n}.xpt', f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/{n}.xpt') for n in ['DEMO_J', 'BMX_J', 'GLU_J']]
items += [
 ('layout.pdf', 'https://www.sas.com/content/dam/sasdam/documents/20260302/record-layout-of-a-sas-version-5-or-6-data-set-in-sas-transport-xport-format.pdf'),
 ('readstat-version.json', 'https://api.github.com/repos/WizardMac/ReadStat/commits/dev'),
 ('moon-home.html', 'https://mooncakes.io/'),
 ('contest.html', 'https://moonbitlang.github.io/Hackathon2026/'),
 ('data-agreement.html', 'https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overview.aspx?BeginYear=2017'),
]
for term in ['xpt', 'xport', '"sas transport"', 'readstat', '"statistical data"']:
    from urllib.parse import quote
    slug = term.replace('"', '').replace(' ', '-')
    items.append((f'dedup-{slug}.json', 'https://api.github.com/search/repositories?q=' + quote(term + ' language:MoonBit')))
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    results = list(pool.map(fetch, items))
(CACHE / 'research.json').write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
