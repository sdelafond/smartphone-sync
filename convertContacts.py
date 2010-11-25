#!/usr/bin/python2.5
import re
import sys
import codecs
import getopt

class VCFToCSVConverter:
  """
  todo: add comments to this mess
  """
  def __output( self, text ):
    if( self.quote == True ):
      self.output += '"'
    self.output += text
    if( self.quote == True ):
      self.output += '"'
    self.output += self.delimiter

  def __resetRow( self ):
    array = {}
    for k in self.columns:
      array[ k ] = ''
    array['Address 1 - Type'] = 'Home'
    array['E-mail 1 - Type'] = '*'    
    array['Phone 1 - Type'] = 'Mobile'
    array['Phone 2 - Type'] = 'Home'
    array['Phone 3 - Type'] = 'Work'    
    return array

  def __setitem__(self, k, v ):
    self.data[ k ] = v

  def __getitem__(self, k):
    return self.data[ k ]

  def __endLine( self ):
    for k in self.columns:
      try:
        self.__output( self.data[ k ] )
      except KeyError:
        self.output += self.delimiter
    self.output += "\n"
    self.data = self.__resetRow()

  def __parseFile(self):
    try:
      inFile = codecs.open( self.inputFile , 'r', 'utf-8', 'ignore' )
      theLine = inFile.readline()
      for theLine in inFile:
        self.__parseLine( theLine )
      inFile.close()
    except IOError:
      print "error opening file.\n"
      sys.exit(2)
    outFile = codecs.open( self.outputFile, 'w', 'utf-8', 'ignore' )
    outFile.write( self.output )
    outFile.close()

  def __parseLine( self, theLine ):
    theLine = theLine.strip()
    if len( theLine ) < 1:
      pass
    elif re.match( '^BEGIN:VCARD', theLine ):
      pass
    elif re.match( '^END:VCARD', theLine ):
      self.__endLine()
    else:
      self.__processLine( theLine.split(":") )

  def __processLine( self, pieces ):
    if pieces[0] == 'ADR;TYPE=HOME':
      self.__process_address( pieces[1] )
    elif pieces[0] == 'N':
      self.__process_name( pieces[1] )
    elif pieces[0] == 'NICKNAME':
      self.__process_nickname( pieces[1] )
    elif pieces[0] == 'BDAY':
      self.__process_bday( pieces[1] )
    elif pieces[0].split(";")[0] == "TEL":
      self.__process_phone( pieces[0].split(";")[1], pieces[1] )
    elif pieces[0].split(";")[0] == "EMAIL":
      self.__process_email( pieces[1] )
    elif pieces[0] == 'FN':
      self.__process_display_name( pieces[1] )

  def __process_display_name( self, nameLine ):
#    if nameLine != "%s %s" % ( self.data['First Name'], self.data['Last Name'] ):
    self.data['Display Name'] = nameLine.strip()

  def __process_nickname( self, nameLine ):
    self.data['Nickname'] = nameLine.strip()

  def __process_bday( self, nameLine ):
    self.data['Birthday'] = nameLine.strip()

  def __process_email( self, emailLine ):
    self.data['Email'] = emailLine

  def __process_address( self, addressLine ):
    try:
      ( self.data['Notes'], self.data['Address'], self.data['City'], self.data['State'], self.data['Zip'], self.data['Country'] ) = addressLine.split( ";" )
    except ValueError:
      print "ERROR %s " % addressLine

  def __process_name( self, nameLine ):
    temp = []
    try:
      ( temp ) = nameLine.split( ";" )
    except ValueError:
      print "ERROR %s " % nameLine
    if len( temp ) > 1:
      self.data['Last Name'] = temp[0]
      self.data['First Name'] = temp[1]

  def __process_phone( self, phoneType, phoneLine ):
    phoneType = phoneType.replace("TYPE=",'')
    if phoneType == 'CELL':
      self.data['Phone 1 - Value'] = phoneLine
    elif phoneType == 'HOME':
      self.data['Phone 2 - Value'] = phoneLine
    elif phoneType == 'WORK':
      self.data['Phone 3 - Value'] = phoneLine
    else:
      self.data['Other Phone'] = phoneLine

  def __init__( self, inputFileName, outputFileName, delimiter, quote):
    self.data = {}
    self.quote = quote
    self.delimiter = delimiter
    self.output = ''
    self.inputFile = inputFileName
    self.outputFile = outputFileName
    self.columns = {  #'First Name' : None,
                      #'Last Name' : None,
                      'Display Name' : 'Name',
                      'Notes' : None,
                      'Nickname' : None,
                      'Birthday' : None,
                      'Email' : 'E-mail 1 - Value',
                      'E-mail 1 - Type' : None,
                      'Address 1 - Type' : None,
                      'Address' : 'Address 1 - Value',
                      'Phone 1 - Type' : None,
                      'Phone 2 - Type' : None,
                      'Phone 3 - Type' : None,
#                       'City' : None,
#                       'State' : None,
#                       'Zip' : None,
#                       'Country' : None,
                      'Phone 1 - Value' : None,
                      'Phone 2 - Value' : None,
                      'Phone 3 - Value' : None,
#                      'Other Phone' : None,
#                       'Extension' : None,
#                       'Messenger' : None,
                      }

    self.data = self.__resetRow()
    for k,v in self.columns.iteritems():
      self.__output( v or k )
    self.output += "\n"
    self.__parseFile()

def usage():
  print "options \n-h|--help this menu\n-i input file (VCS) *required\n-o output file (TAB) *required\n-d [comma|tab|semicolon] delimiter (tab is default)\n-q double values"

def main():
  try:
      opts, args = getopt.getopt(sys.argv[1:], "ho:i:d:q", ["help"])
  except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)
  input_file = None
  output_file = None
  quote = False
  delimiter = "\t"
  delimiter_string = "tab"
  for option, value in opts:
    if option == "-i":
      input_file = value
    elif option == "-o":
      output_file = value
    elif option == "-q":
      quote = True
    elif option == "-d":
      if value == "comma":
        delimiter = ","
        delimiter_string = "comma"
      elif value == "semicolon":
        delimiter = ";"
        delimiter_string = "semicolon"
      else:
        delimiter = "\t"
        delimiter_string = "tab"
    elif option in ("-h", "--help"):
      usage()
      sys.exit(2)
    else:
      print "unhandled option %s" % option
      sys.exit(2)
  if input_file == None or output_file == None:
    print "missing required parameters"
    usage()
    sys.exit(2)
  print "converting %s > %s (%s delimited)" % ( input_file, output_file, delimiter_string )
  VCFToCSVConverter( input_file, output_file, delimiter, quote )
  sys.exit(0)

if __name__ == "__main__":
  main()
