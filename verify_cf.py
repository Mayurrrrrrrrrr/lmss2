import requests
import warnings
warnings.filterwarnings('ignore')

r = requests.get('https://lms2.yuktaa.com/main.dart.js', verify=False, timeout=15)
text = r.text
old_count = text.count('lms.yuktaa.com') - text.count('lms2.yuktaa.com')
new_count = text.count('lms2.yuktaa.com')

print(f"Status: {r.status_code}")
print(f"Size: {len(text)} bytes")
print(f"Old URL count (lms.yuktaa.com only): {old_count}")
print(f"New URL count (lms2.yuktaa.com): {new_count}")
print(f"CF-Cache-Status: {r.headers.get('cf-cache-status', 'N/A')}")
print(f"Cache-Control: {r.headers.get('cache-control', 'N/A')}")
print(f"Age: {r.headers.get('age', 'N/A')}")

# Also test login
r2 = requests.post('https://lms2.yuktaa.com/api/v2/auth/login', 
    json={'username':'admin','password':'Pass123'}, verify=False, timeout=15)
print(f"\nLogin test: {r2.status_code}")
print(f"Login response: {r2.text[:300]}")
