import sys, re

text = open('/var/www/lms-web/main.dart.js').read()

# Replace $.bka() and $.bpx() with false
text = re.sub(r'\$\.bka\(\)', 'false', text)
text = re.sub(r'\$\.bpx\(\)', 'false', text)

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched bka and bpx (Platform.isAndroid/isIOS) in main.dart.js')
