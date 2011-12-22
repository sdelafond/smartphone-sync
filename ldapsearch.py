import base64, re, subprocess, sys

regex = re.compile(r'^(dn|cn|givenName|displayName|sn)(?::[:\s]+)(.*)$')

def unbase64(s):
  try:
    t = base64.decodestring(s)
    t.decode('utf-8')
    s = t
  except:
    pass
  return s

cmd = ["ldapsearch",] + sys.argv[1:]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE)

while True:
  l = p.stdout.readline()
  if not l:
    break

  l = l.strip()

  print regex.sub(lambda x: "%s: %s" % (x.groups()[0],
                                        unbase64(x.groups()[1])),
                  l)
