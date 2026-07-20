import sys, re

text = open('/var/www/lms-web/main.dart.js').read()

# Patch all Platform._ methods that throw exceptions
text = re.sub(r'throw A\.f\(A\.bf\("Platform\._[a-zA-Z]+"\)\)', 'return "Web"', text)

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched all Platform._ methods in main.dart.js')
