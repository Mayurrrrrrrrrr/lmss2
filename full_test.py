import requests
import warnings
warnings.filterwarnings('ignore')

# Simulate what the Flutter app does step by step:

BASE = 'https://lms2.yuktaa.com'

# 1. Load the page
r = requests.get(BASE + '/', verify=False, timeout=15)
print(f"1. GET / => {r.status_code}, size={len(r.text)}")

# 2. Load main.dart.js
r = requests.get(BASE + '/main.dart.js?v=1784450403', verify=False, timeout=15)
print(f"2. GET main.dart.js => {r.status_code}, size={len(r.text)}")

# 3. OPTIONS preflight for login
r = requests.options(BASE + '/api/v2/auth/login', 
    headers={
        'Origin': BASE,
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'content-type,accept,authorization,x-client-type'
    }, verify=False, timeout=15)
print(f"3. OPTIONS /api/v2/auth/login => {r.status_code}")
for k,v in r.headers.items():
    if 'access' in k.lower():
        print(f"   {k}: {v}")

# 4. Actual login POST (JSON body like Flutter sends)
r = requests.post(BASE + '/api/v2/auth/login',
    json={'username': 'admin', 'password': 'Pass123', 'app_version': '2.0.0'},
    headers={
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Type': 'Browser',
        'Origin': BASE
    },
    verify=False, timeout=15)
print(f"4. POST /api/v2/auth/login => {r.status_code}")
print(f"   Body: {r.text[:200]}")
for k,v in r.headers.items():
    if 'access' in k.lower():
        print(f"   {k}: {v}")
