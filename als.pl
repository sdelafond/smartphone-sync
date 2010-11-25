#!/usr/bin/perl -w
#
# Copyright 2005, Michael Donnelly
#
# als	Advanced LDAP Search originally written by Michael Donnelly.
#
#	Unlike the standard LDAP search binary, this version is designed
#	to just plain work (no bind dn, base dn, or server names required.
#	Of course, you can use the standard ldapsearch parameters to
#	override these settings if you wish.
#
# Written by Michael Donnelly with contributions by Erick Mechler
# 
# Recent feature additions
# 2005	- V-card output format
#	- ldapi, ldaps and URI connection support

use Net::LDAP;
use Net::LDAPS;
use Net::LDAP::Extra;
use Getopt::Std;
use Unicode::String qw(latin1);
use strict;

use vars qw($uri $port $base $scope $LDAP $mesg @attribs $filter $delim
		@entries $entry %rtn $attr %opt $att_reset $binddn $bindpw
		@default_attribs $debug);

##############################
# Variables you can customize
#
#$uri = "ldapi://%2Fvar%2Frun%2Fldapi";		# Connect UNIX socket
#$uri = "ldaps://directory.domain.com";		# Connect remote host via LDAPS
$uri = "ldap://127.0.0.1";			# Connect localhost via TCP
$base = "";
$scope = "sub";
$binddn = "";
$bindpw = "";
$delim = "";

# return attributes we're interested in
@default_attribs = ( 
	"objectclass",
	"uid", 
	"givenname",
	"xmozillanickname",
	"sn",
	"cn", 
	"uidnumber",
	"gidnumber",
	"mail",
	"mailRoutingAddress",
	"mailAlternateAddress",
	"mailLocalAddress",
	"mailHost",
	"workPhone",
	"pager",
	"homePhone",
	"cellPhone",
	"ou", 
	"roomnumber", 
	"manager",
	"description",
	"owner",
	"description",
	"uniquemember",
	"mgrprfc822mailmember",
        "birthDate",
#	"userPassword",
#	"messageStoreUserFilter"
	);
#
##############################

# main logic
&getoptions;

if ($opt{'d'})
{
	print "DEBUG: $debug\n";
	print "HOST URI: $uri\n";
	if ($binddn) 
	{
		print "BIND: $binddn\n";
	}
	else
	{
		print "BIND: anonymous\n";
	}
	print "FILTER: $filter\n";
	if ($debug > 3)
	{
  		if ($opt{a})
		{
			print "ATTRIBS: <all>\n";
		}
		else
		{
			print "ATTRIBS:\n";
			print "\t$_\n" foreach (@attribs);
		}
	}
	print "\n";
}


$LDAP =NewLDAPconnection($uri,$binddn,$bindpw);

if (@attribs)
{
	$mesg = $LDAP->search(filter => $filter,
		attrs => \@attribs,
		scope => $scope,
		base => $base);
}
else
{
	$mesg = $LDAP->search(filter => $filter,
		scope => $scope,
		base => $base);
}

# sort return entries based on DN
@entries = $mesg->entries;
if (@entries == 0)
{
	$LDAP->unbind();
	print "No entries found.\n" if $debug;
	exit 0;
} 
else
{
	foreach (@entries)
	{
		$rtn{$_->dn} = $_;
	}
}

if ($opt{'H'})
{
	if ($delim) 
	{
		foreach (@attribs)
		{
			print "$_$delim";
		}
		print "\n";
	}
	elsif ($opt{'c'})
	{
		my $temp = "";
		foreach (@attribs)
		{
			$temp = "$temp\"$_\",";
		}
		chop $temp; 	# strip trailing comma
		print "$temp\n";
	}
}

$LDAP->unbind();

foreach (sort(keys %rtn)) {
	$entry = $rtn{$_};

	if ($opt{'V'})	# Vcard output
	{
		my ($full) = $entry->get_value("cn");
		next unless ($full);

		my ($last) = $entry->get_value("sn");
		$last || ($last =$full);

		my ($first) = $entry->get_value("givenname");
		$first || ($first="");

		my ($org) = $entry->get_value("o");
		my ($dept) = $entry->get_value("ou");
		my ($addr2) = $entry->get_value("roomnumber");
		my ($addr) = $entry->get_value("postalAddress");
		my ($city) = $entry->get_value("l");
		my ($birthday) = $entry->get_value("birthDate");
		my ($nickname) = $entry->get_value("xmozillanickname");
		my ($state) = $entry->get_value("st");
		my ($zip) = $entry->get_value("postalCode");
		my ($country) = $entry->get_value("c");
		my ($mail) = $entry->get_value("mail");
		my ($title) = $entry->get_value("title");
		my ($worktel) = $entry->get_value("workPhone");
		my ($faxtel) = $entry->get_value("facsimiletelephonenumber");
		my ($hometel) = $entry->get_value("homePhone");
		my ($mobile) = $entry->get_value("cellPhone");
		my ($pager) = $entry->get_value("pager");
		my ($url) = $entry->get_value("seeAlso");

		print "BEGIN:VCARD\n";
		print "VERSION:2.1\n";
		print "FN:$full\n";
		print "N:$last;$first\n";
		if ($org || $dept)
		{
			$org || ($org ="");
			$dept || ($dept ="");
			print "ORG:$org;$dept\n";
		}	
		if ($addr2 || $addr || $city || $state || $zip || $country)
		{
			$addr2  || ($addr2 = "");
			$addr  || ($addr = "");
			$city  || ($city = "");
			$state || ($state = "");
			$zip   || ($zip = "");
			$country || ($country = "");
			print "ADR;TYPE=HOME:;$addr;$city;$state;$zip;$country\n";
		}
		print "NOTE:$addr2\n" if ($addr2);
		foreach my $email ($entry->get_value("mailAlternateAddress")) {
		    print "EMAIL;INTERNET;OTHER:$email\n";
		}
		print "EMAIL;INTERNET;HOME:$mail\n" if ($mail);
		print "TITLE:$title\n" if ($title);
		print "TEL;WORK:$worktel\n" if ($worktel);
		print "TEL;FAX:$faxtel\n" if ($faxtel);
		print "TEL;CELL:$mobile\n" if ($mobile);
		print "TEL;HOME:$hometel\n" if ($hometel);
		print "TEL;PAGER:$pager\n" if ($pager);
		print "NICKNAME:$nickname\n" if ($nickname);
		print "BDAY:$birthday\n" if ($birthday);
		print "URL:$url\n" if ($url);
		print "END:VCARD\n";
	}
	elsif ($delim)	# Tab delimited output
	{
		foreach my $attr (@attribs)
		{
			if ($opt{'m'})
			{
				my @val = $entry->get_value($attr);
				print join($opt{'m'},@val);
				print "$delim";
				next;
			} 
			else
			{
				my ($val) = $entry->get_value($attr);
				$val or ($val = "");
				print "$val$delim";
				next;
			}
		}
	} 
	elsif ($opt{'c'})	#CSV output
	{
		my $i = 0;
		foreach my $attr (@attribs)
		{
			if ($entry->get_value($attr))
			{
				print "\"";
				if ($opt{'m'})
				{
					print join( $opt{'m'}, 
						$entry->get_value($attr) );
				}
				else
				{
					my ($val) = $entry->get_value($attr);
					$val or ($val = "");
					print $val;
				}
				print "\"";
			} 
			else
			{
				print "\"\"";
			}
			print "," if ($#attribs != $i);
			$i++;
			next;
		}
	} 
	else    # Standard LDIF output
	{
		print "dn: " . $entry->dn() . "\n";
		if ($opt{'a'})
		{
			print "OPTION A\n";
			foreach my $a (sort $entry->attributes)
			{
				# already printed the dn, so keep going
				foreach my $v ($entry->get_value($a))
				{
					print join(": ",$a, $v),"\n";
				}
			}
		}
		else 
		{
			foreach my $a (sort @attribs)
			{
				# next if ($a =~/^dn$/i);
				# already printed the dn, so keep going
				foreach my $v ($entry->get_value($a))
				{
					print join(": ",$a, $v),"\n";
				}
			}
		}
	}
	print "\n";
}

exit 0;

sub getoptions
# Process command-line arguments
{
	&showhelp if (! @ARGV);

	getopts("h:b:s:D:w:Wd:m:ctT:HaV", \%opt) == 1
		or &showhelp;

	&showhelp if $opt{'e'};
	&getpass if $opt{'W'};
	$uri = $opt{'h'} if $opt{'h'};
	$scope = $opt{'s'} if $opt{'s'};
	$base = $opt{'b'} if $opt{'b'};
	$delim = $opt{'T'} if $opt{'T'};
	$delim = "\t" if $opt{'t'};
	$binddn = $opt{'D'} if $opt{'D'};
	$bindpw = $opt{'w'} if $opt{'w'};
	$debug = $opt{'d'} if $opt{'d'};
	$debug || ($debug = 0);

	# the user needs to give us more
	showhelp() unless (@ARGV);

	# get search filter and return attributes
	if ($ARGV[0] =~ /=/)
	{
		$filter = shift @ARGV;
	} else {
			$filter = "(|" .
				"(uid=$ARGV[0])" .
				"(cn=$ARGV[0])" .
				"(mail=$ARGV[0])" .
				"(mailLocalAddress=$ARGV[0])" .
				"(mailRoutingAddress=$ARGV[0])" .
				")";
			shift @ARGV;
	}

	return if ($opt{'a'});

	if ($opt{'V'})
	{
		@default_attribs = qw ( cn sn givenname 
			o ou 
                        birthDate xmozillanickname mailAlternateAddress
			roomnumber postaladdress l st postalcode c 
			mail title 
			telephoneNumber homePhone facsimileTelephoneNumber 
			pager mobile seeAlso description );
	}

	@attribs = (@ARGV) if (@ARGV);
	@attribs ||( @attribs = @default_attribs);
}

sub getpass
# Reads in the user's password from the CLI if necessary.  The -W
# option only applies if we have -D set as well.
{
	if (! $opt{'D'})
	{
		return;
	}
	
	use Term::ReadKey;

	print "Enter LDAP Password: ";
	ReadMode(2);
	$bindpw = ReadLine(0);
	chomp $bindpw;
	print "\n";
	ReadMode(0);
}
#
##############################  

##############################
# sub showhelp
#
sub showhelp
{
	print '
Usage: als [options] name [attribute1 attribute2 ... attribute-n]
Usage: als [options] search-filter [attribute1 attribute2 ... attribute-n]
 
Supported options:

  Connection options:
  -h <host-uri>   LDAP server URI (default: $uri)
  -b <basedn>     Base DN for search (default: $base)
  -s <scope>      One of base, one, or sub (default: $scope)
  -D <binddn>     Bind DN (bind anonymously if not supplied)
  -w <password>   Password to use with -D (not used with anonymous binds)
  -W              Prompt for bind password (only used with -D; takes
                  precedence over -w)

  Operation control:
  -d <debug_lvl>  Enables debugging output.  Higher debug values result
                  in more output.
  -a              Return all standard attribute values, instead of the
                  default list of returned attributes.  This mode is 
		  overridden when formatted output is requested
		  (-c, -t, -T modes).

  Output formatting (-c, -t, and -T are not used in combination):
  -c              Display output in CSV format
  -t              Tab-delimited output (default is LDIF format)
  -T <delimiter>  Delimiter to use instead of tab with -t and/or -m

  -H              (used only with -c, -t, or -T) Shows headers on first line
  -m <concat_dlm> (used only with -c, -t, or -T) Forces concatenated 
                  output of multiple-value attribute pairs.  If the -m 
		  option is not used, only the primary entry will be returned.  
  -V              Output in vcard format.  (To collect vcard information, also
                  overrides its default attribute list.)

Mode 1: Simple Mode

  The first mode of operation for als expects no more than a login, name, 
  or email address of a directory entry.  A list of commonly requested
  attributes will be automatically chosen if no return attributes are 
  supplied.

  Examples of use:

  als donnelly
    Lists entry for "(|(uid=donnelly)(cn=donnelly)(mailLocalAddress=donnelly))"

  als mail=yoga@mydomain.com
    Lists entry for mail alias "yoga@mydomain.com"

  als "Mike D*"
    Lists all entries having name starting with "Mike D"


Note: To output in tab delimited format, you MUST specify the attributes you 
      would like in the output.

Examples of use:

  als cn=Michael Donnelly
    Returns all information about any entries where the common name is
    "Michael Donnelly".  Output is in LDIF format.

  als \'(&(objectclass=person)(mail=*))\' mail mailhost cn -t 
    Returns a tab-delimited output of all users with a mail attribute.
    The tab delimited list shows:
    	mail	mailhost	cn
    
    Note the use of the single-quotes to prevent globbing.

  als -b ou=employees,dc=mydomain,dc=com \"cn=*\" uid telephonenumber cn -t -H
    Generates a tab delimited (with headers) list of all employee entries
    in the company\'s phone directory, login name, phone number and full name.
';
	exit 1;
}


sub NewLDAPconnection 
{
        my ($uri, $dn, $password) = @_;
        my ($LDAP,$result,$error);
        $LDAP = Net::LDAP->new($uri);
        if (! $LDAP) 
        {
                ExitNow (3,"Error: Unable to connect to directory $uri\n");
        }
        
        if ($dn)  
        {
                $result = $LDAP->bind(dn => $dn,
                        password => $password ,
                        version => 3 );
        } 
        else
        {
                $result = $LDAP->bind();
        }

        if ($result->code)
        {
                ExitNow (3,"Error # ". $result->code .
                        " connecting to $uri as $dn -- " .
                        $result->error . "\n");
        }
        return $LDAP;
}


sub ExitNow
{
        # Exit codes:
        # 0 - success
        # 1 - incorrect usage
        # 2 - Non-fatal errors during processing - check dirsync output
        # 3 - Unable to connect to directory server
        # 4 - During reconciliation phase, too many deletions were detected.
        # 5 - Error during an LDAP search / update operation

        my ($code,$string) = @_;
        $LDAP->unbind if ($LDAP);

        if ($string)
        {
                print "$string\n";
        }
        if ($code)
        {
                exit ($code);
        }
        exit (0);
}

sub convert
{
    my $p = shift;
    if ($p =~ m/[\x80-\xFF]/) {
	return Unicode::String::utf8($p)->latin1;  # convert from UTF-8 to latin1
    }
    return $p;
}
