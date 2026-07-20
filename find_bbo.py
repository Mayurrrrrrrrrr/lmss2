import sys
text = open('/var/www/lms-web/main.dart.js').read()
idx = text.find('bOI(){')
if idx != -1:
    print(text[max(0, idx-50):idx+200])
else:
    print("Not found")
