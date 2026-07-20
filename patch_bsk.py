import sys

text = open('/var/www/lms-web/main.dart.js').read()

original = 'p=$.bBO()\no=A.q(p.T(0,0,p.dM(0,".",p.b9(0,".").ak(0,1))))\nreturn new A.b3a(s,r,q,n,"Dart/"+o+" (dart:io)")}'

replacement = 'return new A.b3a(s,r,q,n,"Dart/android (dart:io)")}'

if original in text:
    text = text.replace(original, replacement)
    open('/var/www/lms-web/main.dart.js', 'w').write(text)
    print('Successfully patched bsK!')
else:
    print('Failed to find original bsK text')
    
