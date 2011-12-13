ORG_DIR := ~/org

LDAP_BASE := "dc=befour,dc=org"
LDAP_DN := "cn=admin,$(LDAP_BASE)"
LDAP_PASSWD := meh # override via CL args
LDIF_FILE := ./contacts.ldif

ADDRESSBOOK_TEMPLATE := $(ORG_DIR)/addressbook
ALIASES_FILE := ~/.mutt-private/aliases
ADDRESSBOOK_FILE := $(ADDRESSBOOK_TEMPLATE).org
BITLBEE_FILE := ./seb.xml

ADDRESSBOOK_HTML_FILE := $(ADDRESSBOOK_TEMPLATE).html
VCF_ADDRESSBOOK_FILE := $(ORG_DIR)/phones.vcf
CSV_ADDRESSBOOK_FILE := $(ORG_DIR)/phones.csv

ICAL_FILE := $(ORG_DIR)/org.ics

all: delete addressbook # calendar

ldif: $(LDIF_FILE)

$(LDIF_FILE):
	python aliases-to-ldif.py $(ALIASES_FILE) $(ADDRESSBOOK_FILE) $(BITLBEE_FILE) $(LDIF_FILE)

ldap: ldif
	ldapadd -c -x -D $(LDAP_DN) -f $(LDIF_FILE) -w $(LDAP_PASSWD)

delete:
	ldapsearch -x -b $(LDAP_BASE) | perl -ne 'if (! m/(admin|^dn: dc)/ &&  m/^dn:[:\s]+(.*)$$/) { print `echo $$1 | base64 -d 2> /dev/null || echo $$1` . "\n" }'  | ldapdelete -c -x -D $(LDAP_DN) -w $(LDAP_PASSWD) || true
	rm -f $(LDIF_FILE) $(VCF_ADDRESSBOOK_FILE) $(ADDRESSBOOK_HTML_FILE) $(CSV_ADDRESSBOOK_FILE)

vcf: $(VCF_ADDRESSBOOK_FILE)
$(VCF_ADDRESSBOOK_FILE): ldap
	LC_ALL=en_US.utf8 perl als.pl -b dc=befour,dc=org -V '(|(cellPhone=*)(workPhone=*)(homePhone=*))' >| $(VCF_ADDRESSBOOK_FILE)
	perl -i -pe 's/^\n$$//' $(VCF_ADDRESSBOOK_FILE)

addressbook: $(ADDRESSBOOK_HTML_FILE)
$(ADDRESSBOOK_HTML_FILE): vcf
	emacs -nw --eval '(progn (org-mode) (find-file "$(ADDRESSBOOK_FILE)") (org-export-as-html "$(ADDRESSBOOK_HTML_FILE)") (kill-emacs))'

csv: $(CSV_ADDRESSBOOK_FILE)
$(CSV_ADDRESSBOOK_FILE): vcf
	rm -f $(CSV_ADDRESSBOOK_FILE)
	python convertContacts.py -i $(VCF_ADDRESSBOOK_FILE) -o $(CSV_ADDRESSBOOK_FILE) -d comma -q

calendar:
	emacs -nw --eval '(progn (org-mode) (org-export-icalendar-combine-agenda-files) (save-buffers-kill-emacs t))'
	python fix-ical.py $(ICAL_FILE)
	recode ..utf16 $(ICAL_FILE)