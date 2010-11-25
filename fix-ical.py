import re, sys, vobject

regexObject = re.compile(r'^(DESCRIPTION:.*)', re.MULTILINE)
regexObject1 = re.compile(r'CEST')

fileName = sys.argv[1]

ical = vobject.readOne(file(fileName))

s = ical.serialize()
s = regexObject.sub(r'\1' + '\nLAST-MODIFIED:20090429T113704Z', s)
s = regexObject1.sub('Europe/Paris', s)

open(fileName, 'w').write(s)
