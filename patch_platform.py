import sys
text = open('/var/www/lms-web/main.dart.js').read()
old_code = 'if($.bka())p="Android App"\nelse p=$.bpx()?"iOS App":"Browser"'
new_code = 'p="Browser"'
text = text.replace(old_code, new_code)

old_code_2 = 'if($.bka())p="Android App"\\nelse p=$.bpx()?"iOS App":"Browser"'
text = text.replace(old_code_2, new_code)

# just in case it's in a single line
old_code_3 = 'if($.bka())p="Android App";else p=$.bpx()?"iOS App":"Browser"'
text = text.replace(old_code_3, new_code)

open('/var/www/lms-web/main.dart.js', 'w').write(text)
print('Patched Platform.isAndroid in main.dart.js')
