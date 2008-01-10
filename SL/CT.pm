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

use Data::Dumper;

use SL::CVar;
use SL::DBUtils;

sub get_tuple {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  my $cv = $form->{db} eq "customer" ? "customer" : "vendor";

  my $dbh   = $form->dbconnect($myconfig);
  my $query =
    qq|SELECT ct.*, b.id AS business, cp.* | .
    qq|FROM $cv ct | .
    qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
    qq|LEFT JOIN contacts cp ON (ct.id = cp.cp_cv_id) | .
    qq|WHERE (ct.id = ?) | .
    qq|ORDER BY cp.cp_id LIMIT 1|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{id});

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  if ( $form->{salesman_id} ) {
    my $query =
      qq|SELECT ct.name AS salesman | .
      qq|FROM $cv ct | .
      qq|WHERE ct.id = ?|;
    ($form->{salesman}) =
      selectrow_query($form, $dbh, $query, $form->{salesman_id});
  }

  # check if it is orphaned
  my $arap = ( $form->{db} eq 'customer' ) ? "ar" : "ap";
  $query =
    qq|SELECT a.id | .
    qq|FROM $arap a | .
    qq|JOIN $cv ct ON (a.${cv}_id = ct.id) | .
    qq|WHERE ct.id = ? | .
    qq|UNION | .
    qq|SELECT a.id | .
    qq|FROM oe a | .
    qq|JOIN $cv ct ON (a.${cv}_id = ct.id) | .
    qq|WHERE ct.id = ?|;
  my ($dummy) = selectrow_query($form, $dbh, $query, $form->{id}, $form->{id});
  $form->{status} = "orphaned" unless ($dummy);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub populate_drop_down_boxes {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $provided_dbh) = @_;

  my $dbh = $provided_dbh ? $provided_dbh : $form->dbconnect($myconfig);

  # get business types
  $query = qq|SELECT id, description FROM business ORDER BY id|;
  $form->{all_business} = selectall_hashref_query($form, $dbh, $query);

  # get shipto address
  $query =
    qq|SELECT shipto_id, shiptoname, shiptodepartment_1 | .
    qq|FROM shipto WHERE (trans_id = ?) AND (module = 'CT')|;
  $form->{SHIPTO} = selectall_hashref_query($form, $dbh, $query, $form->{id});

  # get contacts
  $query  = qq|SELECT cp_id, cp_name FROM contacts WHERE cp_cv_id = ?|;
  $form->{CONTACTS} = selectall_hashref_query($form, $dbh, $query, $form->{id});

  # get languages
  $query = qq|SELECT id, description FROM language ORDER BY id|;
  $form->{languages} = selectall_hashref_query($form, $dbh, $query);

  # get payment terms
  $query = qq|SELECT id, description FROM payment_terms ORDER BY sortkey|;
  $form->{payment_terms} = selectall_hashref_query($form, $dbh, $query);

  $dbh->disconnect() unless ($provided_dbh);

  $main::lxdebug->leave_sub();
}

sub query_titles_and_greetings {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;
  my ( %tmp,  $ref );

  my $dbh = $form->dbconnect($myconfig);

  $query =
    qq|SELECT DISTINCT(cp_greeting) | .
    qq|FROM contacts | .
    qq|WHERE cp_greeting ~ '[a-zA-Z]' | .
    qq|ORDER BY cp_greeting|;
  $form->{GREETINGS} = [ selectall_array_query($form, $dbh, $query) ];

  $query =
    qq|SELECT DISTINCT(greeting) | .
    qq|FROM customer | .
    qq|WHERE greeting ~ '[a-zA-Z]' | .
    qq|UNION | .
    qq|SELECT DISTINCT(greeting) | .
    qq|FROM vendor | .
    qq|WHERE greeting ~ '[a-zA-Z]' | .
    qq|ORDER BY greeting|;
  my %tmp;
  map({ $tmp{$_} = 1; } selectall_array_query($form, $dbh, $query));
  $form->{COMPANY_GREETINGS} = [ sort(keys(%tmp)) ];

  $query =
    qq|SELECT DISTINCT(cp_title) | .
    qq|FROM contacts | .
    qq|WHERE cp_title ~ '[a-zA-Z]'|;
  $form->{TITLES} = [ selectall_array_query($form, $dbh, $query) ];

  $query =
    qq|SELECT DISTINCT(cp_abteilung) | .
    qq|FROM contacts | .
    qq|WHERE cp_abteilung ~ '[a-zA-Z]'|;
  $form->{DEPARTMENT} = [ selectall_array_query($form, $dbh, $query) ];

  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}

sub save_customer {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  # set pricegroup to default
  $form->{klass} = 0 unless ($form->{klass});

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  map( {
    $form->{"cp_${_}"} = $form->{"selected_cp_${_}"}
    if ( $form->{"selected_cp_${_}"} );
       } qw(title greeting abteilung) );
  $form->{"greeting"} = $form->{"selected_company_greeting"}
  if ( $form->{"selected_company_greeting"} );

  # assign value discount, terms, creditlimit
  $form->{discount} = $form->parse_amount( $myconfig, $form->{discount} );
  $form->{discount} /= 100;
  $form->{creditlimit} = $form->parse_amount( $myconfig, $form->{creditlimit} );

  my ( $query, $sth, $f_id );

  if ( $form->{id} ) {
    $query = qq|SELECT id FROM customer WHERE customernumber = ?|;
    ($f_id) = selectrow_query($form, $dbh, $query, $form->{customernumber});

    if (($f_id ne $form->{id}) && ($f_id ne "")) {
      $main::lxdebug->leave_sub();
      return 3;
    }

  } else {
    if (!$form->{customernumber} && $form->{business}) {
      $form->{customernumber} =
        $form->update_business($myconfig, $form->{business}, $dbh);
    }
    if (!$form->{customernumber}) {
      $form->{customernumber} =
        $form->update_defaults($myconfig, "customernumber", $dbh);
    }

    $query  = qq|SELECT c.id FROM customer c WHERE c.customernumber = ?|;
    ($f_id) = selectrow_query($form, $dbh, $query, $form->{customernumber});
    if ($f_id ne "") {
      $main::lxdebug->leave_sub();
      return 3;
    }

    $query = qq|SELECT nextval('id')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO customer (id, name) VALUES (?, '')|;
    do_query($form, $dbh, $query, $form->{id});
  }

  $query = qq|UPDATE customer SET | .
    qq|customernumber = ?, | .
    qq|name = ?, | .
    qq|greeting = ?, | .
    qq|department_1 = ?, | .
    qq|department_2 = ?, | .
    qq|street = ?, | .
    qq|zipcode = ?, | .
    qq|city = ?, | .
    qq|country = ?, | .
    qq|homepage = ?, | .
    qq|contact = ?, | .
    qq|phone = ?, | .
    qq|fax = ?, | .
    qq|email = ?, | .
    qq|cc = ?, | .
    qq|bcc = ?, | .
    qq|notes = ?, | .
    qq|discount = ?, | .
    qq|creditlimit = ?, | .
    qq|terms = ?, | .
    qq|business_id = ?, | .
    qq|taxnumber = ?, | .
    qq|sic_code = ?, | .
    qq|language = ?, | .
    qq|account_number = ?, | .
    qq|bank_code = ?, | .
    qq|bank = ?, | .
    qq|obsolete = ?, | .
    qq|ustid = ?, | .
    qq|username = ?, | .
    qq|salesman_id = ?, | .
    qq|language_id = ?, | .
    qq|payment_id = ?, | .
    qq|taxzone_id = ?, | .
    qq|user_password = ?, | .
    qq|c_vendor_id = ?, | .
    qq|klass = ? | .
    qq|WHERE id = ?|;
  my @values = (
    $form->{customernumber},
    $form->{name},
    $form->{greeting},
    $form->{department_1},
    $form->{department_2},
    $form->{street},
    $form->{zipcode},
    $form->{city},
    $form->{country},
    $form->{homepage},
    $form->{contact},
    $form->{phone},
    $form->{fax},
    $form->{email},
    $form->{cc},
    $form->{bcc},
    $form->{notes},
    $form->{discount},
    $form->{creditlimit},
    conv_i($form->{terms}),
    conv_i($form->{business}),
    $form->{taxnumber},
    $form->{sic},
    $form->{language},
    $form->{account_number},
    $form->{bank_code},
    $form->{bank},
    $form->{obsolete} ? 't' : 'f',
    $form->{ustid},
    $form->{username},
    conv_i($form->{salesman_id}),
    conv_i($form->{language_id}),
    conv_i($form->{payment_id}),
    conv_i($form->{taxzone_id}, 0),
    $form->{user_password},
    $form->{c_vendor_id},
    conv_i($form->{klass}),
    $form->{id}
    );
  do_query( $form, $dbh, $query, @values );

  $query = undef;
  if ( $form->{cp_id} ) {
    $query = qq|UPDATE contacts SET | .
      qq|cp_greeting = ?, | .
      qq|cp_title = ?,  | .
      qq|cp_givenname = ?, | .
      qq|cp_name = ?, | .
      qq|cp_email = ?, | .
      qq|cp_phone1 = ?, | .
      qq|cp_phone2 = ?, | .
      qq|cp_abteilung = ?, | .
      qq|cp_fax = ?, | .
      qq|cp_mobile1 = ?, | .
      qq|cp_mobile2 = ?, | .
      qq|cp_satphone = ?, | .
      qq|cp_satfax = ?, | .
      qq|cp_project = ?, | .
      qq|cp_privatphone = ?, | .
      qq|cp_privatemail = ?, | .
      qq|cp_birthday = ? | .
      qq|WHERE cp_id = ?|;
    @values = (
      $form->{cp_greeting},
      $form->{cp_title},
      $form->{cp_givenname},
      $form->{cp_name},
      $form->{cp_email},
      $form->{cp_phone1},
      $form->{cp_phone2},
      $form->{cp_abteilung},
      $form->{cp_fax},
      $form->{cp_mobile1},
      $form->{cp_mobile2},
      $form->{cp_satphone},
      $form->{cp_satfax},
      $form->{cp_project},
      $form->{cp_privatphone},
      $form->{cp_privatemail},
      $form->{cp_birthday},
      $form->{cp_id}
      );
  } elsif ( $form->{cp_name} || $form->{cp_givenname} ) {
    $query =
      qq|INSERT INTO contacts ( cp_cv_id, cp_greeting, cp_title, cp_givenname,  | .
      qq|  cp_name, cp_email, cp_phone1, cp_phone2, cp_abteilung, cp_fax, cp_mobile1, | .
      qq|  cp_mobile2, cp_satphone, cp_satfax, cp_project, cp_privatphone, cp_privatemail, | .
      qq|  cp_birthday) | .
      qq|VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
    @values = (
      $form->{id},
      $form->{cp_greeting},
      $form->{cp_title},
      $form->{cp_givenname},
      $form->{cp_name},
      $form->{cp_email},
      $form->{cp_phone1},
      $form->{cp_phone2},
      $form->{cp_abteilung},
      $form->{cp_fax},
      $form->{cp_mobile1},
      $form->{cp_mobile2},
      $form->{cp_satphone},
      $form->{cp_satfax},
      $form->{cp_project},
      $form->{cp_privatphone},
      $form->{cp_privatemail},
      $form->{cp_birthday}
      );
  }
  do_query( $form, $dbh, $query, @values ) if ($query);

  # add shipto
  $form->add_shipto( $dbh, $form->{id}, "CT" );

  CVar->save_custom_variables('dbh'       => $dbh,
                              'module'    => 'CT',
                              'trans_id'  => $form->{id},
                              'variables' => $form);

  $rc = $dbh->commit();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();
  return $rc;
}

sub save_vendor {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  $form->{taxzone_id} *= 1;
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  map( {
    $form->{"cp_${_}"} = $form->{"selected_cp_${_}"}
    if ( $form->{"selected_cp_${_}"} );
       } qw(title greeting abteilung) );
  $form->{"greeting"} = $form->{"selected_company_greeting"}
  if ( $form->{"selected_company_greeting"} );

  $form->{discount} = $form->parse_amount( $myconfig, $form->{discount} );
  $form->{discount} /= 100;
  $form->{creditlimit} = $form->parse_amount( $myconfig, $form->{creditlimit} );

  my $query;

  if ( $form->{id} ) {
    $query = qq|DELETE FROM shipto WHERE (trans_id = ?) AND (module = 'CT')|;
    do_query($form, $dbh, $query, $form->{id});

  } else {
    $query = qq|SELECT nextval('id')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO vendor (id, name) VALUES (?, '')|;
    do_query($form, $dbh, $query, $form->{id});

    if ( !$form->{vendornumber} ) {
      $form->{vendornumber} = $form->update_defaults( $myconfig, "vendornumber", $dbh );
    }
  }

  $query =
    qq|UPDATE vendor SET | .
    qq|  vendornumber = ?, | .
    qq|  name = ?, | .
    qq|  greeting = ?, | .
    qq|  department_1 = ?, | .
    qq|  department_2 = ?, | .
    qq|  street = ?, | .
    qq|  zipcode = ?, | .
    qq|  city = ?, | .
    qq|  country = ?, | .
    qq|  homepage = ?, | .
    qq|  contact = ?, | .
    qq|  phone = ?, | .
    qq|  fax = ?, | .
    qq|  email = ?, | .
    qq|  cc = ?, | .
    qq|  bcc = ?, | .
    qq|  notes = ?, | .
    qq|  terms = ?, | .
    qq|  discount = ?, | .
    qq|  creditlimit = ?, | .
    qq|  business_id = ?, | .
    qq|  taxnumber = ?, | .
    qq|  sic_code = ?, | .
    qq|  language = ?, | .
    qq|  account_number = ?, | .
    qq|  bank_code = ?, | .
    qq|  bank = ?, | .
    qq|  obsolete = ?, | .
    qq|  ustid = ?, | .
    qq|  payment_id = ?, | .
    qq|  taxzone_id = ?, | .
    qq|  language_id = ?, | .
    qq|  username = ?, | .
    qq|  user_password = ?, | .
    qq|  v_customer_id = ? | .
    qq|WHERE id = ?|;
  @values = (
    $form->{vendornumber},
    $form->{name},
    $form->{greeting},
    $form->{department_1},
    $form->{department_2},
    $form->{street},
    $form->{zipcode},
    $form->{city},
    $form->{country},
    $form->{homepage},
    $form->{contact},
    $form->{phone},
    $form->{fax},
    $form->{email},
    $form->{cc},
    $form->{bcc},
    $form->{notes},
    conv_i($form->{terms}),
    $form->{discount},
    $form->{creditlimit},
    conv_i($form->{business}),
    $form->{taxnumber},
    $form->{sic},
    $form->{language},
    $form->{account_number},
    $form->{bank_code},
    $form->{bank},
    $form->{obsolete} ? 't' : 'f',
    $form->{ustid},
    conv_i($form->{payment_id}),
    conv_i($form->{taxzone_id}, 0),
    conv_i( $form->{language_id}),
    $form->{username},
    $form->{user_password},
    $form->{v_customer_id},
    $form->{id}
    );
  do_query($form, $dbh, $query, @values);

  $query = undef;
  if ( $form->{cp_id} ) {
    $query = qq|UPDATE contacts SET | .
      qq|cp_greeting = ?, | .
      qq|cp_title = ?,  | .
      qq|cp_givenname = ?, | .
      qq|cp_name = ?, | .
      qq|cp_email = ?, | .
      qq|cp_phone1 = ?, | .
      qq|cp_phone2 = ?, | .
      qq|cp_abteilung = ?, | .
      qq|cp_fax = ?, | .
      qq|cp_mobile1 = ?, | .
      qq|cp_mobile2 = ?, | .
      qq|cp_satphone = ?, | .
      qq|cp_satfax = ?, | .
      qq|cp_project = ?, | .
      qq|cp_privatphone = ?, | .
      qq|cp_privatemail = ?, | .
      qq|cp_birthday = ? | .
      qq|WHERE cp_id = ?|;
    @values = (
      $form->{cp_greeting},
      $form->{cp_title},
      $form->{cp_givenname},
      $form->{cp_name},
      $form->{cp_email},
      $form->{cp_phone1},
      $form->{cp_phone2},
      $form->{cp_abteilung},
      $form->{cp_fax},
      $form->{cp_mobile1},
      $form->{cp_mobile2},
      $form->{cp_satphone},
      $form->{cp_satfax},
      $form->{cp_project},
      $form->{cp_privatphone},
      $form->{cp_privatemail},
      $form->{cp_birthday},
      $form->{cp_id}
      );
  } elsif ( $form->{cp_name} || $form->{cp_givenname} ) {
    $query =
      qq|INSERT INTO contacts ( cp_cv_id, cp_greeting, cp_title, cp_givenname,  | .
      qq|  cp_name, cp_email, cp_phone1, cp_phone2, cp_abteilung, cp_fax, cp_mobile1, | .
      qq|  cp_mobile2, cp_satphone, cp_satfax, cp_project, cp_privatphone, cp_privatemail, | .
      qq|  cp_birthday) | .
      qq|VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
    @values = (
      $form->{id},
      $form->{cp_greeting},
      $form->{cp_title},
      $form->{cp_givenname},
      $form->{cp_name},
      $form->{cp_email},
      $form->{cp_phone1},
      $form->{cp_phone2},
      $form->{cp_abteilung},
      $form->{cp_fax},
      $form->{cp_mobile1},
      $form->{cp_mobile2},
      $form->{cp_satphone},
      $form->{cp_satfax},
      $form->{cp_project},
      $form->{cp_privatphone},
      $form->{cp_privatemail},
      $form->{cp_birthday}
      );
  }
  do_query($form, $dbh, $query, @values) if ($query);

  # add shipto
  $form->add_shipto( $dbh, $form->{id}, "CT" );

  CVar->save_custom_variables('dbh'       => $dbh,
                              'module'    => 'CT',
                              'trans_id'  => $form->{id},
                              'variables' => $form);

  $rc = $dbh->commit();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();
  return $rc;
}

sub delete {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # delete vendor
  my $cv = $form->{db} eq "customer" ? "customer" : "vendor";
  my $query = qq|DELETE FROM $cv WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $cv = $form->{db} eq "customer" ? "customer" : "vendor";

  my $where = "1 = 1";
  my @values;

  my %allowed_sort_columns =
    map({ $_, 1 } qw(id customernumber name address contact phone fax email
                     taxnumber sic_code business invnumber ordnumber quonumber));
  $sortorder =
    $form->{sort} && $allowed_sort_columns{$form->{sort}} ?
    $form->{sort} : "name";
  $form->{sort} = $sortorder;
  $sortorder = "country,city,street" if ($sortorder eq "address");

  if ($form->{"${cv}number"}) {
    $where .= " AND ct.${cv}number ILIKE ?";
    push(@values, '%' . $form->{"${cv}number"} . '%');
  }

  foreach my $key (qw(name contact email)) {
    if ($form->{$key}) {
      $where .= " AND ct.$key ILIKE ?";
      push(@values, '%' . $form->{$key} . '%');
    }
  }

  if ( $form->{status} eq 'orphaned' ) {
    $where .=
      qq| AND ct.id NOT IN | .
      qq|   (SELECT o.${cv}_id FROM oe o, $cv cv WHERE cv.id = o.${cv}_id)|;
    if ($cv eq 'customer') {
      $where .=
        qq| AND ct.id NOT IN | .
        qq| (SELECT a.customer_id FROM ar a, customer cv | .
        qq|  WHERE cv.id = a.customer_id)|;
    }
    if ($cv eq 'vendor') {
      $where .=
        qq| AND ct.id NOT IN | .
        qq| (SELECT a.vendor_id FROM ap a, vendor cv | .
        qq|  WHERE cv.id = a.vendor_id)|;
    }
    $form->{l_invnumber} = $form->{l_ordnumber} = $form->{l_quonumber} = "";
  }

  if ($form->{obsolete} eq "Y") {
    $where .= qq| AND obsolete|;
  } elsif ($form->{obsolete} eq "N") {
    $where .= qq| AND NOT obsolete|;
  }

  if ($form->{business_id}) {
    $where .= qq| AND (business_id = ?)|;
    push(@values, conv_i($form->{business_id}));
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'CT',
                                                            'trans_id_field' => 'ct.id',
                                                            'filter'         => $form);

  if ($cvar_where) {
    $where .= qq| AND ($cvar_where)|;
    push @values, @cvar_values;
  }

  my $query =
    qq|SELECT ct.*, b.description AS business | .
    qq|FROM $cv ct | .
    qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
    qq|WHERE $where|;

  my @saved_values = @values;
  # redo for invoices, orders and quotations
  if ($form->{l_invnumber} || $form->{l_ordnumber} || $form->{l_quonumber}) {
    my ($ar, $union, $module);
    $query = "";

    if ($form->{l_invnumber}) {
      my $ar = $cv eq 'customer' ? 'ar' : 'ap';
      my $module = $ar eq 'ar' ? 'is' : 'ir';

      $query =
        qq|SELECT ct.*, b.description AS business, | .
        qq|  a.invnumber, a.ordnumber, a.quonumber, a.id AS invid, | .
        qq|  '$module' AS module, 'invoice' AS formtype, | .
        qq|  (a.amount = a.paid) AS closed | .
        qq|FROM $cv ct | .
        qq|JOIN $ar a ON (a.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|WHERE $where AND (a.invoice = '1')|;

      $union = qq|UNION|;
    }

    if ( $form->{l_ordnumber} ) {
      if ($union eq "UNION") {
        push(@values, @saved_values);
      }
      $query .=
        qq| $union | .
        qq|SELECT ct.*, b.description AS business,| .
        qq|  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid, | .
        qq|  'oe' AS module, 'order' AS formtype, o.closed | .
        qq|FROM $cv ct | .
        qq|JOIN oe o ON (o.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|WHERE $where AND (o.quotation = '0')|;

      $union = qq|UNION|;
    }

    if ( $form->{l_quonumber} ) {
      if ($union eq "UNION") {
        push(@values, @saved_values);
      }
      $query .=
        qq| $union | .
        qq|SELECT ct.*, b.description AS business, | .
        qq|  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid, | .
        qq|  'oe' AS module, 'quotation' AS formtype, o.closed | .
        qq|FROM $cv ct | .
        qq|JOIN oe o ON (o.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|WHERE $where AND (o.quotation = '1')|;
    }
  }

  $query .= qq| ORDER BY $sortorder|;

  $form->{CT} = selectall_hashref_query($form, $dbh, $query, @values);
  map({ my $ref = $_; $ref->{address} = join(" ", map({ $ref->{$_} } qw(street zipcode city country))); }
      @{ $form->{CT} });

  $main::lxdebug->leave_sub();
}

sub get_contact {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;
  my $dbh   = $form->dbconnect($myconfig);
  my $query =
    qq|SELECT * FROM contacts c | .
    qq|WHERE cp_id = ? ORDER BY cp_id limit 1|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{cp_id});
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_shipto {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;
  my $dbh   = $form->dbconnect($myconfig);
  my $query = qq|SELECT * FROM shipto WHERE shipto_id = ?|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{shipto_id});

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_delivery {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;
  my $dbh = $form->dbconnect($myconfig);

  my $arap = $form->{db} eq "vendor" ? "ap" : "ar";
  my $db = $form->{db} eq "customer" ? "customer" : "vendor";

  my $where = " WHERE 1=1 ";
  my @values;

  if ($form->{shipto_id} && ($arap eq "ar")) {
    $where .= "AND ${arap}.shipto_id = ?";
    push(@values, $form->{shipto_id});
  } else {
    $where .= "AND ${arap}.${db}_id = ?";
    push(@values, $form->{id});
  }

  if ($form->{from}) {
    $where .= "AND ${arap}.transdate >= ?";
    push(@values, conv_date($form->{from}));
  }
  if ($form->{to}) {
    $where .= "AND ${arap}.transdate <= ?";
    push(@values, conv_date($form->{to}));
  }
  my $query =
    qq|SELECT s.shiptoname, i.qty, | .
    qq|  ${arap}.transdate, ${arap}.invnumber, ${arap}.ordnumber, | .
    qq|  i.description, i.unit, i.sellprice | .
    qq|FROM $arap | .
    qq|LEFT JOIN shipto s ON | .
    ($arap eq "ar"
     ? qq|(ar.shipto_id = s.shipto_id) |
     : qq|(ap.id = s.trans_id) |) .
    qq|LEFT JOIN invoice i ON (${arap}.id = i.trans_id) | .
    qq|LEFT join parts p ON (p.id = i.parts_id) | .
    $where .
    qq|ORDER BY ${arap}.transdate DESC LIMIT 15|;

  $form->{DELIVERY} = selectall_hashref_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
