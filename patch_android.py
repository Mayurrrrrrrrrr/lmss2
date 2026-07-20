import sys

text = open('/var/www/lms-web/main.dart.js').read()

# Replace "Web" with "android" to bypass hardcoded OS checks
text = text.replace('return "Web"', 'return "android"')

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched "Web" to "android" in main.dart.js')
