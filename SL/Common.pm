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

use Carp;
use English qw(-no_match_vars);
use Time::HiRes qw(gettimeofday);
use Data::Dumper;
use File::Copy ();
use File::stat;
use File::Slurp;
use File::Spec;
use List::MoreUtils qw(apply);
use POSIX ();
use Encode qw(decode);

use SL::DBUtils;
use SL::DB;

sub unique_id {
  my ($a, $b) = gettimeofday();
  return "${a}-${b}-${$}";
}

sub tmpname {
  return "/tmp/kivitendo-tmp-" . unique_id();
}

sub truncate {
  my ($text, %params) = @_;

  $params{at}       //= 50;
  $params{at}         =  3 if 3 > $params{at};

  $params{strip}    //= '';

  $text =~ s/[\r\n]+$//g if $params{strip} =~ m/^(?: 1 | newlines? | full )$/x;
  $text =~ s/[\r\n]+/ /g if $params{strip} =~ m/^(?:     newlines? | full )$/x;

  return $text if length($text) <= $params{at};
  return substr($text, 0, $params{at} - 3) . '...';
}

sub retrieve_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = SL::DB->client->dbh;

  my (@filter_values, $filter);

  foreach (qw(partnumber description ean)) {
    next unless $form->{$_};

    $filter .= qq| AND ($_ ILIKE ?)|;
    push @filter_values, like($form->{$_});
  }

  if ($form->{no_assemblies}) {
    $filter .= qq| AND (NOT part_type = 'assembly')|;
  }
  if ($form->{assemblies}) {
    $filter .= qq| AND part_type = 'assembly'|;
  }

  if ($form->{no_services}) {
    $filter .= qq| AND NOT (part_type = 'service' OR part_type = 'assembly')|;
  }

  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query =
    qq|SELECT id, partnumber, description, ean, | .
    qq|       warehouse_id, bin_id | .
    qq|FROM parts $filter | .
    qq|ORDER BY $order_by $order_dir|;
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $parts = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$parts}, $ref);
  }
  $sth->finish();

  $main::lxdebug->leave_sub();

  return $parts;
}

sub retrieve_customers_or_vendors {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir, $is_vendor, $allow_both) = @_;

  my $dbh = SL::DB->client->dbh;

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " AND (TABLE.name ILIKE ?)";
    push(@filter_values, like($form->{"name"}));
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

  $main::lxdebug->leave_sub();

  return $customers;
}

sub retrieve_delivery_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = SL::DB->client->dbh;

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= qq| (name ILIKE ?) AND|;
    push(@filter_values, like($form->{"name"}));
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

  $main::lxdebug->leave_sub();

  return $delivery_customers;
}

sub retrieve_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = SL::DB->client->dbh;

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= qq| (name ILIKE ?) AND|;
    push(@filter_values, like($form->{"name"}));
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
    unless ($::instance_conf->get_webdav && $form->{id});



  $form->{WEBDAV} = [];

  my ($path, $number) = get_webdav_folder($form);
  return $main::lxdebug->leave_sub() unless ($path && $number);

  if (!-d $path) {
    mkdir_with_parents($path);

  } else {
    my $base_path = $ENV{'SCRIPT_NAME'};
    $base_path =~ s|[^/]+$||;
    if (opendir my $dir, $path) {
      foreach my $file (sort { lc $a cmp lc $b } map { decode("UTF-8", $_) } readdir $dir) {
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

  my $dbh = SL::DB->client->dbh;

  my $query;

  $query =
    qq|SELECT
         vc.*,
         pt.description AS payment_terms,
         b.description AS business,
         l.description AS language,
         dt.description AS delivery_terms
       FROM ${vc} vc
       LEFT JOIN payment_terms pt ON (vc.payment_id = pt.id)
       LEFT JOIN business b ON (vc.business_id = b.id)
       LEFT JOIN language l ON (vc.language_id = l.id)
       LEFT JOIN delivery_terms dt ON (vc.delivery_term_id = dt.id)
       WHERE vc.id = ?|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, $vc_id);

  if (!$ref) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  map { $form->{$_} = $form->format_amount($myconfig, $form->{$_} * 1) } qw(discount creditlimit);

  $query = qq|SELECT * FROM shipto WHERE (trans_id = ?)|;
  $form->{SHIPTO} = selectall_hashref_query($form, $dbh, $query, $vc_id);

  $query = qq|SELECT * FROM contacts WHERE (cp_cv_id = ?)|;
  $form->{CONTACTS} = selectall_hashref_query($form, $dbh, $query, $vc_id);

  # Only show default pricegroup for customer, not vendor, which is why this is outside the main query
  ($form->{pricegroup}) = selectrow_query($form, $dbh, qq|SELECT pricegroup FROM pricegroup WHERE id = ?|, $form->{pricegroup_id});

  $main::lxdebug->leave_sub();

  return 1;
}

sub get_shipto_by_id {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $shipto_id, $prefix) = @_;

  $prefix ||= "";

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT * FROM shipto WHERE shipto_id = ?|;
  my $ref   = selectfirst_hashref_query($form, $dbh, $query, $shipto_id);

  map { $form->{"${prefix}${_}"} = $ref->{$_} } keys %{ $ref } if $ref;

  my $cvars = CVar->get_custom_variables(
    dbh      => $dbh,
    module   => 'ShipTo',
    trans_id => $shipto_id,
  );
  $form->{"${prefix}shiptocvar_$_->{name}"} = $_->{value} for @{ $cvars };

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

  } elsif ($form->{script} eq 'do.pl') {
    $table = 'delivery_orders';
  }

  return $main::lxdebug->leave_sub() if (!$form->{id} || !$table || !$form->{formname});

  SL::DB->client->with_transaction(sub {
    $dbh = SL::DB->client->dbh;

    my ($intnotes) = selectrow_query($form, $dbh, qq|SELECT intnotes FROM $table WHERE id = ?|, $form->{id});

    $intnotes =~ s|\r||g;
    $intnotes =~ s|\n$||;

    $intnotes .= "\n\n" if ($intnotes);

    my $cc  = $form->{cc}  ? $main::locale->text('Cc') . ": $form->{cc}\n"   : '';
    my $bcc = $form->{bcc} ? $main::locale->text('Bcc') . ": $form->{bcc}\n" : '';
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
    1;
  }) or do { die SL::DB->client->error };

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

sub get_webdav_folder {
  $main::lxdebug->enter_sub();

  my ($form) = @_;

  croak "No client set in \$::auth" unless $::auth->client;

  my ($path, $number);

  # dispatch table
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
  } elsif ($form->{type} eq "letter") {
    ($path, $number) = ("briefe", $form->{letternumber} );
  } elsif ($form->{vc} eq "customer") {
    ($path, $number) = ("rechnungen", $form->{invnumber});
  } elsif ($form->{vc} eq "vendor") {
    ($path, $number) = ("einkaufsrechnungen", $form->{invnumber});
  } else {
    $main::lxdebug->leave_sub();
    return undef;
  }

  $number =~ s|[/\\]|_|g;

  $path = "webdav/" . $::auth->client->{id} . "/${path}/${number}";

  $main::lxdebug->leave_sub();

  return ($path, $number);
}

sub copy_file_to_webdav_folder {
  $::lxdebug->enter_sub();

  my ($form) = @_;
  my ($last_mod_time, $latest_file_name, $complete_path);

  # checks
  foreach my $item (qw(tmpdir tmpfile type)){
    next if $form->{$item};
    $::lxdebug->message(LXDebug::WARN(), 'Missing parameter:' . $item);
    $::lxdebug->leave_sub();
    return $::locale->text("Missing parameter for WebDAV file copy");
  }

  my ($webdav_folder, $document_name) =  get_webdav_folder($form);

  if (! $webdav_folder){
    $::lxdebug->message(LXDebug::WARN(), 'Cannot check correct WebDAV folder');
    $::lxdebug->leave_sub();
    return $::locale->text("Cannot check correct WebDAV folder")
  }

  $complete_path =  File::Spec->catfile($form->{cwd},  $webdav_folder);

  # maybe the path does not exist (automatic printing), see #2446
  if (!-d $complete_path) {
    # we need a chdir and restore old dir
    my $current_dir = POSIX::getcwd();
    chdir("$form->{cwd}");
    mkdir_with_parents($webdav_folder);
    chdir($current_dir);
  }

  my $dh;
  if (!opendir $dh, $complete_path) {
    $::lxdebug->leave_sub();
    return "Could not open $complete_path: $!";
  }

  my ($newest_name, $newest_time);
  while ( defined( my $file = readdir( $dh ) ) ) {
    my $path = File::Spec->catfile( $complete_path, $file );
    next if -d $path; # skip directories, or anything else you like
    ( $newest_name, $newest_time ) = ( $file, -M _ ) if( ! defined $newest_time or -M $path < $newest_time );
  }

  closedir $dh;

  $latest_file_name    = File::Spec->catfile($complete_path, $newest_name);
  my $filesize         = stat($latest_file_name)->size;

  my $current_file     = File::Spec->catfile($form->{tmpdir}, apply { s:.*/:: } $form->{tmpfile});
  my $current_filesize = -f $current_file ? stat($current_file)->size : 0;

  if ($current_filesize == $filesize) {
    $::lxdebug->leave_sub();
    return;
  }

  my $timestamp =  get_current_formatted_time();
  my $new_file  =  File::Spec->catfile($form->{cwd}, $webdav_folder, $form->generate_attachment_filename());
  $new_file =~ s{(.*)\.}{$1$timestamp\.};

  if (!File::Copy::copy($current_file, $new_file)) {
    $::lxdebug->message(LXDebug::WARN(), "Copy file from $current_file to $new_file failed: $ERRNO");
    $::lxdebug->leave_sub();
    return $::locale->text("Copy file from #1 to #2 failed: #3", $current_file, $new_file, $ERRNO);
  }

  return;
  $::lxdebug->leave_sub();
}

sub get_current_formatted_time {
  return POSIX::strftime('_%Y%m%d_%H%M%S', localtime());
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

Common - Common routines used in a lot of places.

=head1 SYNOPSIS

  my $short_text = Common::truncate($long_text, at => 10);

=head1 FUNCTIONS

=over 4

=item C<truncate $text, %params>

Truncates C<$text> at a position and insert an ellipsis if the text is
longer. The maximum number of characters to return is given with the
paramter C<at> which defaults to 50.

The optional parameter C<strip> can be used to remove unwanted line
feed/carriage return characters from the text before truncation. It
can be set to C<1> (only strip those at the end of C<$text>) or
C<full> (replace consecutive line feed/carriage return characters in
the middle by a single space and remove tailing line feed/carriage
return characters).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
