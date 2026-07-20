import sys
text = open('/var/www/lms-web/main.dart.js').read()
idx = text.find('p.b9(0,".")')
if idx != -1:
    print(text[max(0, idx-200):idx+200])
else:
    print("Not found")
