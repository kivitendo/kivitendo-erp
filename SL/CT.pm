#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# backend code for customers and vendors
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================

package CT;

sub get_tuple {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh   = $form->dbconnect($myconfig);
  my $query = qq|SELECT ct.*, b.id AS business, s.*, cp.*
                 FROM $form->{db} ct
		 LEFT JOIN business b on ct.business_id = b.id
		 LEFT JOIN shipto s on ct.id = s.trans_id
                 LEFT JOIN contacts cp on ct.id = cp.cp_cv_id
		 WHERE ct.id = $form->{id}  order by cp.cp_id limit 1|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  if ($form->{salesman_id}) {
    my $query = qq|SELECT ct.name AS salesman
                  FROM $form->{db} ct
                  WHERE ct.id = $form->{salesman_id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($ref) = $sth->fetchrow_array();

    $form->{salesman} = $ref;

    $sth->finish;
  }

  # check if it is orphaned
  my $arap = ($form->{db} eq 'customer') ? "ar" : "ap";
  $query = qq|SELECT a.id
              FROM $arap a
	      JOIN $form->{db} ct ON (a.$form->{db}_id = ct.id)
	      WHERE ct.id = $form->{id}
	    UNION
	      SELECT a.id
	      FROM oe a
	      JOIN $form->{db} ct ON (a.$form->{db}_id = ct.id)
	      WHERE ct.id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  unless ($sth->fetchrow_array) {
    $form->{status} = "orphaned";
  }
  $sth->finish;

  # get tax labels
  $query = qq|SELECT c.accno, c.description
              FROM chart c
	      JOIN tax t ON (t.chart_id = c.id)
	      WHERE c.link LIKE '%CT_tax%'
	      ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{tax}{ $ref->{accno} }{description} = $ref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # get taxes for customer/vendor
  $query = qq|SELECT c.accno
              FROM chart c
	      JOIN $form->{db}tax t ON (t.chart_id = c.id)
	      WHERE t.$form->{db}_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{tax}{ $ref->{accno} }{taxable} = 1;
  }
  $sth->finish;

  # get business types
  $query = qq|SELECT id, description
              FROM business
	      ORDER BY 1|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_business} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

## LINET
sub query_titles_and_greetings {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my (%tmp,  $ref);

  my $dbh = $form->dbconnect($myconfig);

  $query =
    "SELECT DISTINCT(c.cp_greeting) FROM contacts c WHERE c.cp_greeting LIKE '%'";
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    next unless ($ref->{cp_greeting} =~ /[a-zA-Z]/);
    $tmp{ $ref->{cp_greeting} } = 1;
  }
  $sth->finish();

  @{ $form->{GREETINGS} } = sort(keys(%tmp));

  %tmp = ();

  $query =
    "SELECT DISTINCT(c.cp_title) FROM contacts c WHERE c.cp_title LIKE '%'";
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    next unless ($ref->{cp_title} =~ /[a-zA-Z]/);
    $tmp{ $ref->{cp_title} } = 1;
  }
  $sth->finish();

  @{ $form->{TITLES} } = sort(keys(%tmp));

  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}
## /LINET

sub taxaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  # get tax labels
  my $query = qq|SELECT accno, description
                 FROM chart c, tax t
		 WHERE c.link LIKE '%CT_tax%'
	         AND c.id = t.chart_id
		 ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{tax}{ $ref->{accno} }{description} = $ref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # this is just for the selection for type of business
  $query = qq|SELECT id, description
              FROM business|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_business} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # set pricegroup to default
  if ($form->{klass}) { }
  else { $form->{klass} = 0; }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
##LINET
  map({
      $form->{"cp_${_}"} = $form->{"selected_cp_${_}"}
        if ($form->{"selected_cp_${_}"});
  } qw(title greeting));

  #
  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g }
    qw(customernumber name street zipcode city country homepage contact notes cp_title cp_greeting language pricegroup);
##/LINET
  # assign value discount, terms, creditlimit
  $form->{discount} = $form->parse_amount($myconfig, $form->{discount});
  $form->{discount} /= 100;
  $form->{terms}       *= 1;
  $form->{taxincluded} *= 1;
  $form->{obsolete}    *= 1;
  $form->{business}    *= 1;
  $form->{salesman_id} *= 1;
  $form->{creditlimit} = $form->parse_amount($myconfig, $form->{creditlimit});

  my ($query, $sth, $f_id);

  if ($form->{id}) {

    $query = qq|SELECT id FROM customer
                WHERE customernumber = '$form->{customernumber}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    (${f_id}) = $sth->fetchrow_array;
    $sth->finish;
    if ((${f_id} ne $form->{id}) and (${f_id} ne "")) {

      $main::lxdebug->leave_sub();
      return 3;
    }
    $query = qq|DELETE FROM customertax
                WHERE customer_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  } else {

    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);
    if (!$form->{customernumber} && $form->{business}) {
      $form->{customernumber} =
        $form->update_business($myconfig, $form->{business});
    }
    if (!$form->{customernumber}) {
      $form->{customernumber} =
        $form->update_defaults($myconfig, "customernumber");
    }

    $query = qq|SELECT c.id FROM customer c
                WHERE c.customernumber = '$form->{customernumber}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    (${f_id}) = $sth->fetchrow_array;
    $sth->finish;
    if (${f_id} ne "") {
      $main::lxdebug->leave_sub();
      return 3;
    }

    $query = qq|INSERT INTO customer (name)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT c.id FROM customer c
                WHERE c.name = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }
  $query = qq|UPDATE customer SET
              customernumber = '$form->{customernumber}',
	      name = '$form->{name}',
              department_1 = '$form->{department_1}',
              department_2 = '$form->{department_2}',
	      street = '$form->{street}',
	      zipcode = '$form->{zipcode}',
	      city = '$form->{city}',
	      country = '$form->{country}',
	      homepage = '$form->{homepage}',
	      contact = '$form->{contact}',
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = '$form->{notes}',
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
	      terms = $form->{terms},
	      taxincluded = '$form->{taxincluded}',
	      business_id = $form->{business},
	      taxnumber = '$form->{taxnumber}',
	      sic_code = '$form->{sic}',
              language = '$form->{language}',
              account_number = '$form->{account_number}',
              bank_code = '$form->{bank_code}',
              bank = '$form->{bank}',
              obsolete = '$form->{obsolete}',
              ustid = '$form->{ustid}',
              username = '$form->{username}',
              salesman_id = '$form->{salesman_id}',
              user_password = | . $dbh->quote($form->{user_password}) . qq|,
              c_vendor_id = '$form->{c_vendor_id}',
              klass = '$form->{klass}'
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{cp_id}) {
    $query = qq|UPDATE contacts SET
		cp_greeting = '$form->{cp_greeting}',
		cp_title = '$form->{cp_title}',
		cp_givenname = '$form->{cp_givenname}',
		cp_name = '$form->{cp_name}',
		cp_email = '$form->{cp_email}',
		cp_phone1 = '$form->{cp_phone1}',
		cp_phone2 = '$form->{cp_phone2}'
		WHERE cp_id = $form->{cp_id}|;
  } elsif ($form->{cp_name} || $form->{cp_givenname}) {
    $query =
      qq|INSERT INTO contacts ( cp_cv_id, cp_greeting, cp_title, cp_givenname, cp_name, cp_email, cp_phone1, cp_phone2)
		  VALUES ($form->{id}, '$form->{cp_greeting}','$form->{cp_title}','$form->{cp_givenname}','$form->{cp_name}','$form->{cp_email}','$form->{cp_phone1}','$form->{cp_phone2}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  # save taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$item"}) {
      $query = qq|INSERT INTO customertax (customer_id, chart_id)
		  VALUES ($form->{id}, (SELECT c.id
				        FROM chart c
				        WHERE c.accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # add shipto
  $form->add_shipto($dbh, $form->{id});

  $rc = $dbh->disconnect;

  $main::lxdebug->leave_sub();
  return $rc;
}

sub save_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
##LINET
  map({
      $form->{"cp_${_}"} = $form->{"selected_cp_${_}"}
        if ($form->{"selected_cp_${_}"});
  } qw(title greeting));

  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g }
    qw(vendornumber name street zipcode city country homepage contact notes cp_title cp_greeting language);
##/LINET
  $form->{discount} = $form->parse_amount($myconfig, $form->{discount});
  $form->{discount} /= 100;
  $form->{terms}       *= 1;
  $form->{taxincluded} *= 1;
  $form->{obsolete}    *= 1;
  $form->{business}    *= 1;
  $form->{creditlimit} = $form->parse_amount($myconfig, $form->{creditlimit});

  my $query;

  if ($form->{id}) {
    $query = qq|DELETE FROM vendortax
                WHERE vendor_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  } else {
    my $uid = time;
    $uid .= $form->{login};
    my $uid = rand() . time;
    $uid .= $form->{login};
    $uid = substr($uid, 2, 75);
    $query = qq|INSERT INTO vendor (name)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT v.id FROM vendor v
                WHERE v.name = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
    if (!$form->{vendornumber}) {
      $form->{vendornumber} =
        $form->update_defaults($myconfig, "vendornumber");
    }

  }

##LINET
  $query = qq|UPDATE vendor SET
              vendornumber = '$form->{vendornumber}',
	      name = '$form->{name}',
              department_1 = '$form->{department_1}',
              department_2 = '$form->{department_2}',
	      street = '$form->{street}',
	      zipcode = '$form->{zipcode}',
	      city = '$form->{city}',
	      country = '$form->{country}',
	      homepage = '$form->{homepage}',
	      contact = '$form->{contact}',
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = '$form->{notes}',
	      terms = $form->{terms},
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
	      taxincluded = '$form->{taxincluded}',
	      gifi_accno = '$form->{gifi_accno}',
	      business_id = $form->{business},
	      taxnumber = '$form->{taxnumber}',
	      sic_code = '$form->{sic}',
              language = '$form->{language}',
              account_number = '$form->{account_number}',
              bank_code = '$form->{bank_code}',
              bank = '$form->{bank}',
              obsolete = '$form->{obsolete}',
              ustid = '$form->{ustid}',
              username = '$form->{username}',
              user_password = '$form->{user_password}',
              v_customer_id = '$form->{v_customer_id}'
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{cp_id}) {
    $query = qq|UPDATE contacts SET
		cp_greeting = '$form->{cp_greeting}',
		cp_title = '$form->{cp_title}',
		cp_givenname = '$form->{cp_givenname}',
		cp_name = '$form->{cp_name}',
		cp_email = '$form->{cp_email}',
		cp_phone1 = '$form->{cp_phone1}',
		cp_phone2 = '$form->{cp_phone2}'
		WHERE cp_id = $form->{cp_id}|;
  } elsif ($form->{cp_name} || $form->{cp_givenname}) {
    $query =
      qq|INSERT INTO contacts ( cp_cv_id, cp_greeting, cp_title, cp_givenname, cp_name, cp_email, cp_phone1, cp_phone2)
		  VALUES ($form->{id}, '$form->{cp_greeting}','$form->{cp_title}','$form->{cp_givenname}','$form->{cp_name}','$form->{cp_email}','$form->{cp_phone1}','$form->{cp_phone2}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  # save taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$item"}) {
      $query = qq|INSERT INTO vendortax (vendor_id, chart_id)
		  VALUES ($form->{id}, (SELECT c.id
				        FROM chart c
				        WHERE c.accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # add shipto
  $form->add_shipto($dbh, $form->{id});

  $rc = $dbh->disconnect;

  $main::lxdebug->leave_sub();
  return $rc;
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # delete vendor
  my $query = qq|DELETE FROM $form->{db}
	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = "1 = 1";
  $form->{sort} = "name" unless ($form->{sort});

  if ($form->{"$form->{db}number"}) {
    my $companynumber = $form->like(lc $form->{"$form->{db}number"});
    $where .= " AND lower(ct.$form->{db}number) LIKE '$companynumber'";
  }
  if ($form->{name}) {
    my $name = $form->like(lc $form->{name});
    $where .= " AND lower(ct.name) LIKE '$name'";
  }
  if ($form->{contact}) {
    my $contact = $form->like(lc $form->{contact});
    $where .= " AND lower(ct.contact) LIKE '$contact'";
  }
  if ($form->{email}) {
    my $email = $form->like(lc $form->{email});
    $where .= " AND lower(ct.email) LIKE '$email'";
  }

  if ($form->{status} eq 'orphaned') {
    $where .= qq| AND ct.id NOT IN (SELECT o.$form->{db}_id
                                    FROM oe o, $form->{db} cv
		 	            WHERE cv.id = o.$form->{db}_id)|;
    if ($form->{db} eq 'customer') {
      $where .= qq| AND ct.id NOT IN (SELECT a.customer_id
                                      FROM ar a, customer cv
				      WHERE cv.id = a.customer_id)|;
    }
    if ($form->{db} eq 'vendor') {
      $where .= qq| AND ct.id NOT IN (SELECT a.vendor_id
                                      FROM ap a, vendor cv
				      WHERE cv.id = a.vendor_id)|;
    }
    $form->{l_invnumber} = $form->{l_ordnumber} = $form->{l_quonumber} = "";
  }

  my $query = qq|SELECT ct.*, b.description AS business
                 FROM $form->{db} ct
	      LEFT JOIN business b ON (ct.business_id = b.id)
                 WHERE $where|;

  # redo for invoices, orders and quotations
  if ($form->{l_invnumber} || $form->{l_ordnumber} || $form->{l_quonumber}) {

    my ($ar, $union, $module);
    $query = "";

    if ($form->{l_invnumber}) {
      $ar     = ($form->{db} eq 'customer') ? 'ar' : 'ap';
      $module = ($ar         eq 'ar')       ? 'is' : 'ir';

      $query = qq|SELECT ct.*, b.description AS business,
                  a.invnumber, a.ordnumber, a.quonumber, a.id AS invid,
		  '$module' AS module, 'invoice' AS formtype,
		  (a.amount = a.paid) AS closed
		  FROM $form->{db} ct
		JOIN $ar a ON (a.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND a.invoice = '1'|;

      $union = qq|
              UNION|;

    }

    if ($form->{l_ordnumber}) {
      $query .= qq|$union
                  SELECT ct.*, b.description AS business,
		  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		  'oe' AS module, 'order' AS formtype,
		  o.closed
		  FROM $form->{db} ct
		JOIN oe o ON (o.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND o.quotation = '0'|;

      $union = qq|
              UNION|;
    }

    if ($form->{l_quonumber}) {
      $query .= qq|$union
                  SELECT ct.*, b.description AS business,
		  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		  'oe' AS module, 'quotation' AS formtype,
		  o.closed
		  FROM $form->{db} ct
		JOIN oe o ON (o.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND o.quotation = '1'|;

    }
  }

  $query .= qq|
		 ORDER BY $form->{sort}|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
##LINET
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{address} = "";
    map { $ref->{address} .= "$ref->{$_} "; } qw(street zipcode city country);
    push @{ $form->{CT} }, $ref;
  }
##/LINET
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

