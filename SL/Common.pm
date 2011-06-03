#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package Common;

use utf8;
use strict;

use Time::HiRes qw(gettimeofday);
use Data::Dumper;

use SL::DBUtils;

use vars qw(@db_encodings %db_encoding_to_charset %charset_to_db_encoding);

@db_encodings = (
  { "label" => "ASCII",          "dbencoding" => "SQL_ASCII", "charset" => "ASCII" },
  { "label" => "UTF-8 Unicode",  "dbencoding" => "UNICODE",   "charset" => "UTF-8" },
  { "label" => "ISO 8859-1",     "dbencoding" => "LATIN1",    "charset" => "ISO-8859-1" },
  { "label" => "ISO 8859-2",     "dbencoding" => "LATIN2",    "charset" => "ISO-8859-2" },
  { "label" => "ISO 8859-3",     "dbencoding" => "LATIN3",    "charset" => "ISO-8859-3" },
  { "label" => "ISO 8859-4",     "dbencoding" => "LATIN4",    "charset" => "ISO-8859-4" },
  { "label" => "ISO 8859-5",     "dbencoding" => "LATIN5",    "charset" => "ISO-8859-5" },
  { "label" => "ISO 8859-15",    "dbencoding" => "LATIN9",    "charset" => "ISO-8859-15" },
  { "label" => "KOI8-R",         "dbencoding" => "KOI8",      "charset" => "KOI8-R" },
  { "label" => "Windows CP1251", "dbencoding" => "WIN",       "charset" => "CP1251" },
  { "label" => "Windows CP866",  "dbencoding" => "ALT",       "charset" => "CP866" },
);

%db_encoding_to_charset = map { $_->{dbencoding}, $_->{charset} } @db_encodings;
%charset_to_db_encoding = map { $_->{charset}, $_->{dbencoding} } @db_encodings;

use constant DEFAULT_CHARSET => 'ISO-8859-15';

sub unique_id {
  my ($a, $b) = gettimeofday();
  return "${a}-${b}-${$}";
}

sub tmpname {
  return "/tmp/lx-office-tmp-" . unique_id();
}

sub retrieve_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);

  foreach (qw(partnumber description ean)) {
    next unless $form->{$_};

    $filter .= qq| AND ($_ ILIKE ?)|;
    push @filter_values, '%' . $form->{$_} . '%';
  }

  if ($form->{no_assemblies}) {
    $filter .= qq| AND (NOT COALESCE(assembly, FALSE))|;
  }
  if ($form->{assemblies}) {
    $filter .= qq| AND assembly=TRUE|;
  }

  if ($form->{no_services}) {
    $filter .= qq| AND (inventory_accno_id is not NULL or assembly=TRUE)|; # @mb hier nochmal optimieren ... nach kurzer ruecksprache alles i.o.
  }

  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq|SELECT id, partnumber, description, ean | .
    qq|FROM parts $filter | .
    qq|ORDER BY $order_by $order_dir|;
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $parts = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$parts}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $parts;
}

sub retrieve_projects {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"projectnumber"}) {
    $filter .= qq| AND (projectnumber ILIKE ?)|;
    push(@filter_values, '%' . $form->{"projectnumber"} . '%');
  }
  if ($form->{"description"}) {
    $filter .= qq| AND (description ILIKE ?)|;
    push(@filter_values, '%' . $form->{"description"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq|SELECT id, projectnumber, description | .
    qq|FROM project $filter | .
    qq|ORDER BY $order_by $order_dir|;
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $projects = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$projects}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $projects;
}

sub retrieve_employees {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= qq| AND (name ILIKE ?)|;
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq|SELECT id, name | .
    qq|FROM employee $filter | .
    qq|ORDER BY $order_by $order_dir|;
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $employees = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$employees}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $employees;
}

sub retrieve_customers_or_vendors {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir, $is_vendor, $allow_both) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " AND (TABLE.name ILIKE ?)";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  if (!$form->{"obsolete"}) {
    $filter .= " AND NOT TABLE.obsolete";
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my (@queries, @query_parameters);

  if ($allow_both || !$is_vendor) {
    my $c_filter = $filter;
    $c_filter =~ s/TABLE/c/g;
    push(@queries, qq|SELECT
                        c.id, c.name, 0 AS customer_is_vendor,
                        c.street, c.zipcode, c.city,
                        ct.cp_gender, ct.cp_title, ct.cp_givenname, ct.cp_name
                      FROM customer c
                      LEFT JOIN contacts ct ON (c.id = ct.cp_cv_id)
                      $c_filter|);
    push(@query_parameters, @filter_values);
  }

  if ($allow_both || $is_vendor) {
    my $v_filter = $filter;
    $v_filter =~ s/TABLE/v/g;
    push(@queries, qq|SELECT
                        v.id, v.name, 1 AS customer_is_vendor,
                        v.street, v.zipcode, v.city,
                        ct.cp_gender, ct.cp_title, ct.cp_givenname, ct.cp_name
                      FROM vendor v
                      LEFT JOIN contacts ct ON (v.id = ct.cp_cv_id)
                      $v_filter|);
    push(@query_parameters, @filter_values);
  }

  my $query = join(" UNION ", @queries) . " ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@query_parameters) || $form->dberror($query . " (" . join(", ", @query_parameters) . ")");
  my $customers = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$customers}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $customers;
}

sub retrieve_delivery_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= qq| (name ILIKE ?) AND|;
    push(@filter_values, '%' . $form->{"name"} . '%');
  }

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq!SELECT id, name, customernumber, (street || ', ' || zipcode || city) AS address ! .
    qq!FROM customer ! .
    qq!WHERE $filter business_id = (SELECT id FROM business WHERE description = 'Endkunde') ! .
    qq!ORDER BY $order_by $order_dir!;
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) ||
    $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $delivery_customers = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$delivery_customers}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $delivery_customers;
}

sub retrieve_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= qq| (name ILIKE ?) AND|;
    push(@filter_values, '%' . $form->{"name"} . '%');
  }

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq!SELECT id, name, customernumber, (street || ', ' || zipcode || city) AS address FROM customer ! .
    qq!WHERE $filter business_id = (SELECT id FROM business WHERE description = ?') ! .
    qq!ORDER BY $order_by $order_dir!;
  push @filter_values, $::locale->{iconv_utf8}->convert('Händler');
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) ||
    $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $vendors = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$vendors}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $vendors;
}

sub mkdir_with_parents {
  $main::lxdebug->enter_sub();

  my ($full_path) = @_;

  my $path = "";

  $full_path =~ s|/+|/|;

  foreach my $part (split(m|/|, $full_path)) {
    $path .= "/" if ($path);
    $path .= $part;

    die("Could not create directory '$path' because a file exists with " .
        "the same name.\n") if (-f $path);

    if (! -d $path) {
      mkdir($path, 0770) || die("Could not create the directory '$path'. " .
                                "OS error: $!\n");
    }
  }

  $main::lxdebug->leave_sub();
}

sub webdav_folder {
  $main::lxdebug->enter_sub();

  my ($form) = @_;

  return $main::lxdebug->leave_sub()
    unless ($::lx_office_conf{features}->{webdav} && $form->{id});

  my ($path, $number);

  $form->{WEBDAV} = [];

  if ($form->{type} eq "sales_quotation") {
    ($path, $number) = ("angebote", $form->{quonumber});
  } elsif ($form->{type} eq "sales_order") {
    ($path, $number) = ("bestellungen", $form->{ordnumber});
  } elsif ($form->{type} eq "request_quotation") {
    ($path, $number) = ("anfragen", $form->{quonumber});
  } elsif ($form->{type} eq "purchase_order") {
    ($path, $number) = ("lieferantenbestellungen", $form->{ordnumber});
  } elsif ($form->{type} eq "sales_delivery_order") {
    ($path, $number) = ("verkaufslieferscheine", $form->{donumber});
  } elsif ($form->{type} eq "purchase_delivery_order") {
    ($path, $number) = ("einkaufslieferscheine", $form->{donumber});
  } elsif ($form->{type} eq "credit_note") {
    ($path, $number) = ("gutschriften", $form->{invnumber});
  } elsif ($form->{vc} eq "customer") {
    ($path, $number) = ("rechnungen", $form->{invnumber});
  } else {
    ($path, $number) = ("einkaufsrechnungen", $form->{invnumber});
  }

  return $main::lxdebug->leave_sub() unless ($path && $number);

  $number =~ s|[/\\]|_|g;

  $path = "webdav/${path}/${number}";

  if (!-d $path) {
    mkdir_with_parents($path);

  } else {
    my $base_path = $ENV{'SCRIPT_NAME'};
    $base_path =~ s|[^/]+$||;
    # wo kommt der wert für dir her? es wird doch gar nichts übergeben? fix für strict my $dir jb 21.2.
    if (opendir my $dir, $path) {
      foreach my $file (sort { lc $a cmp lc $b } readdir $dir) {
        next if (($file eq '.') || ($file eq '..'));

        my $fname = $file;
        $fname  =~ s|.*/||;

        my $is_directory = -d "$path/$file";

        $file  = join('/', map { $form->escape($_) } grep { $_ } split m|/+|, "$path/$file");
        $file .=  '/' if ($is_directory);

        push @{ $form->{WEBDAV} }, {
          'name' => $fname,
          'link' => $base_path . $file,
          'type' => $is_directory ? $main::locale->text('Directory') : $main::locale->text('File'),
        };
      }

      closedir $dir;
    }
  }

  $main::lxdebug->leave_sub();
}

sub get_vc_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $vc, $vc_id) = @_;

  $vc = $vc eq "customer" ? "customer" : "vendor";

  my $dbh = $form->dbconnect($myconfig);

  my $query;

  $query =
    qq|SELECT
         vc.*,
         pt.description AS payment_terms,
         b.description AS business,
         l.description AS language
       FROM ${vc} vc
       LEFT JOIN payment_terms pt ON (vc.payment_id = pt.id)
       LEFT JOIN business b ON (vc.business_id = b.id)
       LEFT JOIN language l ON (vc.language_id = l.id)
       WHERE vc.id = ?|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, $vc_id);

  if (!$ref) {
    $dbh->disconnect();
    $main::lxdebug->leave_sub();
    return 0;
  }

  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  map { $form->{$_} = $form->format_amount($myconfig, $form->{$_} * 1) } qw(discount creditlimit);

  $query = qq|SELECT * FROM shipto WHERE (trans_id = ?)|;
  $form->{SHIPTO} = selectall_hashref_query($form, $dbh, $query, $vc_id);

  $query = qq|SELECT * FROM contacts WHERE (cp_cv_id = ?)|;
  $form->{CONTACTS} = selectall_hashref_query($form, $dbh, $query, $vc_id);

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return 1;
}

sub get_shipto_by_id {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $shipto_id, $prefix) = @_;

  $prefix ||= "";

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT * FROM shipto WHERE shipto_id = ?|;
  my $ref   = selectfirst_hashref_query($form, $dbh, $query, $shipto_id);

  map { $form->{"${prefix}${_}"} = $ref->{$_} } keys %{ $ref } if $ref;

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub save_email_status {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($table, $query, $dbh);

  if ($form->{script} eq 'oe.pl') {
    $table = 'oe';

  } elsif ($form->{script} eq 'is.pl') {
    $table = 'ar';

  } elsif ($form->{script} eq 'ir.pl') {
    $table = 'ap';

  }

  return $main::lxdebug->leave_sub() if (!$form->{id} || !$table || !$form->{formname});

  $dbh = $form->get_standard_dbh($myconfig);

  my ($intnotes) = selectrow_query($form, $dbh, qq|SELECT intnotes FROM $table WHERE id = ?|, $form->{id});

  $intnotes =~ s|\r||g;
  $intnotes =~ s|\n$||;

  $intnotes .= "\n\n" if ($intnotes);

  my $cc  = $main::locale->text('Cc') . ": $form->{cc}\n"   if $form->{cc};
  my $bcc = $main::locale->text('Bcc') . ": $form->{bcc}\n" if $form->{bcc};
  my $now = scalar localtime;

  $intnotes .= $main::locale->text('[email]') . "\n"
    . $main::locale->text('Date') . ": $now\n"
    . $main::locale->text('To (email)') . ": $form->{email}\n"
    . "${cc}${bcc}"
    . $main::locale->text('Subject') . ": $form->{subject}\n\n"
    . $main::locale->text('Message') . ": $form->{message}";

  $intnotes =~ s|\r||g;

  do_query($form, $dbh, qq|UPDATE $table SET intnotes = ? WHERE id = ?|, $intnotes, $form->{id});

  $form->save_status($dbh);

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub check_params {
  my $params = shift;

  foreach my $key (@_) {
    if ((ref $key eq '') && !defined $params->{$key}) {
      my $subroutine = (caller(1))[3];
      $main::lxdebug->message(LXDebug->BACKTRACE_ON_ERROR, "[Common::check_params] failed, params object dumped below");
      $main::lxdebug->message(LXDebug->BACKTRACE_ON_ERROR, Dumper($params));
      $main::form->error($main::locale->text("Missing parameter #1 in call to sub #2.", $key, $subroutine));

    } elsif (ref $key eq 'ARRAY') {
      my $found = 0;
      foreach my $subkey (@{ $key }) {
        if (defined $params->{$subkey}) {
          $found = 1;
          last;
        }
      }

      if (!$found) {
        my $subroutine = (caller(1))[3];
        $main::lxdebug->message(LXDebug->BACKTRACE_ON_ERROR, "[Common::check_params] failed, params object dumped below");
        $main::lxdebug->message(LXDebug->BACKTRACE_ON_ERROR, Dumper($params));
        $main::form->error($main::locale->text("Missing parameter (at least one of #1) in call to sub #2.", join(', ', @{ $key }), $subroutine));
      }
    }
  }
}

sub check_params_x {
  my $params = shift;

  foreach my $key (@_) {
    if ((ref $key eq '') && !exists $params->{$key}) {
      my $subroutine = (caller(1))[3];
      $main::form->error($main::locale->text("Missing parameter #1 in call to sub #2.", $key, $subroutine));

    } elsif (ref $key eq 'ARRAY') {
      my $found = 0;
      foreach my $subkey (@{ $key }) {
        if (exists $params->{$subkey}) {
          $found = 1;
          last;
        }
      }

      if (!$found) {
        my $subroutine = (caller(1))[3];
        $main::form->error($main::locale->text("Missing parameter (at least one of #1) in call to sub #2.", join(', ', @{ $key }), $subroutine));
      }
    }
  }
}

1;
