import sys

text = open('/var/www/lms-web/main.dart.js').read()

text = text.replace('n.d="Err: "+A.q(A.a5(h))', 'n.d="Err: "+String(A.a5(h).stack)')

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched main.dart.js to print stack trace')
