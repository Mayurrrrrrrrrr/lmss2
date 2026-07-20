import sys
text = open('/var/www/lms-web/main.dart.js').read()
text = text.replace('n.d="Could not reach server. Check your internet connection."', 'n.d="Err: "+A.q(A.a5(h))')
open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched main.dart.js')
