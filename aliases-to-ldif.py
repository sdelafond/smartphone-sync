import logging, os, os.path, re, sys, urllib, xml.dom.minidom
#import latscii

logger = logging.getLogger("aliases-to-ldif")
logger.setLevel(logging.DEBUG)
# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
# create formatter
formatter = logging.Formatter("%(asctime)s %(levelname)7s: %(message)s")
# add formatter to ch
ch.setFormatter(formatter)
# add ch to logger
logger.addHandler(ch)

muttAliasREObj = re.compile(r"""
  alias
  \s+
  (?P<nickName> [^\s]+ )
  \s+
  (?P<firstName> [^\s]+)
  \s*
  (?P<lastName> [^<]+)?
  \s+
  < (?P<emailAddress> [^\s]+) >
  """,
  re.VERBOSE)

ldifNicknameTemplate = "xmozillanickname: %s\n"
ldifMailTemplate = "mail: %s\n"
ldifAlternateMailTemplate = "mailAlternateAddress: %s\n"
ldifTemplate = \
"""dn: cn=%s,dc=befour,dc=org
objectClass: top
objectClass: person
objectClass: inetOrgPerson
objectClass: contact
cn: %s
displayName: %s
sn: %s
gn: %s
"""

realProtocols = { "jabber" : "gtalk", "oscar" : "aim" }
protocolsToEmail = { "yahoo" : "@yahoo.com", "aim" : "@aol.com" }

def bailOut(msg):
  logger.error("%s" % msg)
  sys.exit(1)

class Person:
  def __init__(self, firstName, lastName, nickName = None, emailAddress = None):
    self.firstName = firstName
    self.lastName = lastName
    self.fullName = "%s %s" % (firstName, lastName)
    self.emailAddress = {}
    if nickName:
      self.emailAddress[nickName] = emailAddress
    self.phones = []
    self.imIDs = []
    self.birthDate = None
    self.address = None
    self.code = None    
    logger.debug("  --> new person")

  def setBirthDate(self, birthDate):
    self.birthDate = birthDate
    logger.info("  --> birthdate = %s" % (birthDate,))

  def setAddress(self, address):
    self.address = address
    logger.info("  --> address = %s" % (self.address,))

  def setCode(self, code):
    self.code = code
    logger.info("  --> code = %s" % (self.code,))

  def getBirthDate(self):
    return self.birthDate

  def addPhone(self, number, location):
    self.phones.append( (location, number) )
    logger.info("  --> new phone number = %s for %s" % (number, location))    
  
  def addEmailAddress(self, nickName, emailAddress):
    self.emailAddress[nickName] = emailAddress
    logger.info("  --> new email address = %s" % emailAddress)

  def addImID(self, protocol, id):
    self.imIDs.append( (protocol, id) )
    logger.info("  --> new IM ID = %s for %s" % (id, protocol))

  def getPrimaryEmailAddress(self):
    if not self.emailAddress:
      return None
    nicks = [ nickname for nickname in self.emailAddress.keys() ]
    nicks.sort()
    return self.emailAddress[nicks[0]]

  def getSecondaryEmailAddresses(self):
    return [ x for x in self.emailAddress.values()
             if not x == self.getPrimaryEmailAddress() ]

  def getEmails(self):
    return self.emailAddress.values()

  def getNickName(self):
    if not self.emailAddress:
      return None
    nicks = [ nickname for nickname in self.emailAddress.keys() ]
    nicks.sort()
    return nicks[0]

  def getFullName(self):
    return self.fullName

  def getFullNameWithoutAccents(self):
    return self.fullName #.decode('latscii').encode('latin-1')

  def getLDIF(self):
    string = ldifTemplate % (self.getFullNameWithoutAccents(),
                             self.getFullNameWithoutAccents(),
                             self.getFullName(),
                             self.lastName,
                             self.firstName)

    if self.getNickName():
      string += ldifNicknameTemplate % self.getNickName()

    if self.getPrimaryEmailAddress():
      mail = ldifMailTemplate % self.getPrimaryEmailAddress()
      for m in self.getSecondaryEmailAddresses():
        mail += ldifAlternateMailTemplate % m

      string += mail

    if self.phones:
      phones = ""
      for location, number in self.phones:
        if location == 'work':
          ldifSnippet = 'workPhone: %s\n' % number
        elif location == 'home':
          ldifSnippet = 'homePhone: %s\n' % number
        else:
          ldifSnippet = 'cellPhone: %s\n' % number
          
        phones += ldifSnippet

      string += phones

    if self.imIDs:
      imIDs = ""
      for i in self.imIDs:
        imIDs += "%sID: %s\n" % i

      string += str(imIDs)

    if self.birthDate:
      string += "birthDate: %s\n" % self.birthDate

    if self.address:
      string += "postalAddress: %s\n" % self.address

    if self.code:
      string += "roomNumber: %s\n" % self.code

    string += '\n'

    return string #.decode('latin-1').encode('utf-8')

  def __str__(self):
    s = '%s %s' % (self.firstName, self.lastName)
    s += '\t%s' % self.getPrimaryEmailAddress()
    if len(self.emailAddress) > 1:
      s += '\n\t%s' % (self.getSecondaryEmailAddresses(), )
    return s

## main
logger.debug("starting")
persons  = {}

# work on the .mutt/aliases file
logger.debug("working on mutt-aliases")
f = open(sys.argv[1])
for line in [ line for line in f.readlines() if line.strip() and not line.count(',') ]:
  if line.startswith('#'):
    continue
  logger.debug("examining mutt-aliases line: '%s'" % line.strip())
  m = muttAliasREObj.match(line)
  if m:
    d1 = m.groupdict()
    logger.debug("  --> dict = %s" % d1)
    fn = "%s %s" % (d1['firstName'], d1['lastName'])
    if fn in persons:
      persons[fn].addEmailAddress(d1['nickName'], d1['emailAddress'])
    else:
      persons[fn] = Person(d1['firstName'], d1['lastName'],
                           d1['nickName'], d1['emailAddress'])
  else:
    bailOut("couldn't parse line")

f.close()

# work on the phonelist file
logger.debug("working on phonelist")
f = open(sys.argv[2])
for line in f.readlines()[2:]:
  logger.debug("examining phonelist line: '%s'" % line.strip())
  splitted = [ x.strip() for x in re.split(r'\s*\|\s*', line)[1:-1] ]
  logger.debug(splitted)
  lastName, firstName, cell, home, work, birthday, address, code  = splitted

  fn = "%s %s" % (firstName, lastName)
  logger.info("  --> fullname = %s" % fn)
  if not fn in persons:
    persons[fn] = Person(firstName, lastName)

  for phoneType in 'cell', 'home', 'work':
    number = globals()[phoneType]
    if number:
      persons[fn].addPhone(number, phoneType)
      
#   if cell:
#     persons[fn].addPhone(cell, 'cell')
#   if home:
#     persons[fn].addPhone(home, 'home')
#   if work:
#     persons[fn].addPhone(work, 'work')    

  if address:
    persons[fn].setAddress(address)

  if code:
    persons[fn].setCode(code)    

  if birthday:
    array = birthday.split('/')
    array.reverse()
    persons[fn].setBirthDate("-".join(array))

f.close()

# work on bitlbee contacts
logger.debug("working on bitlbee list")

bitlbeeXmlFile = sys.argv[3]
if os.path.isfile(bitlbeeXmlFile):
  bbDom = xml.dom.minidom.parse(bitlbeeXmlFile)

  for account in bbDom.getElementsByTagName("account"):
    protocol = account.getAttribute("protocol")
    if protocol in realProtocols:
      protocol = realProtocols[protocol]

    for buddy in account.getElementsByTagName("buddy"):
      imID = urllib.unquote(buddy.getAttribute("handle"))
      nick = urllib.unquote(buddy.getAttribute("nick"))
      if protocol in protocolsToEmail:
        email = imID + protocolsToEmail[protocol]
      else:
        email = imID

      found = False

      for person in persons.values():
        if email in person.getEmails(): # \
    #       or email.count(person.lastName.lower()):
          found = person
          break

      if not found:
        if email.count('befour07'):
          continue
        else:
          bailOut("person not found: %s" % email)
      else:
    #    print "%s -> %s (%s)" % (found.fullName, email, imID)
        found.addImID(protocol, imID)
else:
  logger.warn("Couldn't read '%s', no IM info will be added." % (bitlbeeXmlFile,))

keys = persons.keys()
keys.sort()

f = open(sys.argv[4], 'w')
for v in [ persons[k] for k in keys ]:
   f.write(v.getLDIF())
