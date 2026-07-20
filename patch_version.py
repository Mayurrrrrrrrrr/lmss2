import sys

text = open('/var/www/lms-web/main.dart.js').read()

# Patch Platform._version
text = text.replace('throw A.f(A.bf("Platform._version"))', 'return "Web"')

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched Platform._version in main.dart.js')
