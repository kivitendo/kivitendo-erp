#=====================================================================
# kivitendo ERP
# Copyright (c) 2004
#
#  Author: Philip Reetz
#   Email: p.reetz@linet-services.de
#     Web: http://www.lx-office.org
#
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Datev export module
#======================================================================

package SL::DATEV;

use utf8;
use strict;

use SL::DBUtils;
use SL::DATEV::KNEFile;
use SL::DATEV::CSV;
use SL::DB;
use SL::HTML::Util ();
use SL::Locale::String qw(t8);

use Data::Dumper;
use DateTime;
use Exporter qw(import);
use File::Path;
use IO::File;
use List::MoreUtils qw(any);
use List::Util qw(min max sum);
use List::UtilsBy qw(partition_by sort_by);
use Text::CSV_XS;
use Time::HiRes qw(gettimeofday);

{
  my $i = 0;
  use constant {
    DATEV_ET_BUCHUNGEN => $i++,
    DATEV_ET_STAMM     => $i++,
    DATEV_ET_CSV       => $i++,

    DATEV_FORMAT_KNE   => $i++,
    DATEV_FORMAT_OBE   => $i++,
    DATEV_FORMAT_CSV   => $i++,
  };
}

my @export_constants = qw(DATEV_ET_BUCHUNGEN DATEV_ET_STAMM DATEV_ET_CSV DATEV_FORMAT_KNE DATEV_FORMAT_OBE DATEV_FORMAT_CSV);
our @EXPORT_OK = (@export_constants);
our %EXPORT_TAGS = (CONSTANTS => [ @export_constants ]);


sub new {
  my $class = shift;
  my %data  = @_;

  my $obj = bless {}, $class;

  $obj->$_($data{$_}) for keys %data;

  $obj;
}

sub exporttype {
  my $self = shift;
  $self->{exporttype} = $_[0] if @_;
  return $self->{exporttype};
}

sub has_exporttype {
  defined $_[0]->{exporttype};
}

sub format {
  my $self = shift;
  $self->{format} = $_[0] if @_;
  return $self->{format};
}

sub has_format {
  defined $_[0]->{format};
}

sub _get_export_path {
  $main::lxdebug->enter_sub();

  my ($a, $b) = gettimeofday();
  my $path    = _get_path_for_download_token("${a}-${b}-${$}");

  mkpath($path) unless (-d $path);

  $main::lxdebug->leave_sub();

  return $path;
}

sub _get_path_for_download_token {
  $main::lxdebug->enter_sub();

  my $token = shift || '';
  my $path;

  if ($token =~ m|^(\d+)-(\d+)-(\d+)$|) {
    $path = $::lx_office_conf{paths}->{userspath} . "/datev-export-${1}-${2}-${3}/";
  }

  $main::lxdebug->leave_sub();

  return $path;
}

sub _get_download_token_for_path {
  $main::lxdebug->enter_sub();

  my $path = shift;
  my $token;

  if ($path =~ m|.*datev-export-(\d+)-(\d+)-(\d+)/?$|) {
    $token = "${1}-${2}-${3}";
  }

  $main::lxdebug->leave_sub();

  return $token;
}

sub download_token {
  my $self = shift;
  $self->{download_token} = $_[0] if @_;
  return $self->{download_token} ||= _get_download_token_for_path($self->export_path);
}

sub export_path {
  my ($self) = @_;

  return  $self->{export_path} ||= _get_path_for_download_token($self->{download_token}) || _get_export_path();
}

sub add_filenames {
  my $self = shift;
  push @{ $self->{filenames} ||= [] }, @_;
}

sub filenames {
  return @{ $_[0]{filenames} || [] };
}

sub add_error {
  my $self = shift;
  push @{ $self->{errors} ||= [] }, @_;
}

sub errors {
  return @{ $_[0]{errors} || [] };
}

sub add_net_gross_differences {
  my $self = shift;
  push @{ $self->{net_gross_differences} ||= [] }, @_;
}

sub net_gross_differences {
  return @{ $_[0]{net_gross_differences} || [] };
}

sub sum_net_gross_differences {
  return sum $_[0]->net_gross_differences;
}

sub from {
 my $self = shift;

 if (@_) {
   $self->{from} = $_[0];
 }

 return $self->{from};
}

sub to {
 my $self = shift;

 if (@_) {
   $self->{to} = $_[0];
 }

 return $self->{to};
}

sub trans_id {
  my $self = shift;

  if (@_) {
    $self->{trans_id} = $_[0];
  }

  die "illegal trans_id passed for DATEV export: " . $self->{trans_id} . "\n" unless $self->{trans_id} =~ m/^\d+$/;

  return $self->{trans_id};
}

sub warnings {
  my $self = shift;

  if (@_) {
    $self->{warnings} = [@_];
  } else {
   return $self->{warnings};
  }
}

sub use_pk {
 my $self = shift;

 if (@_) {
   $self->{use_pk} = $_[0];
 }

 return $self->{use_pk};
}

sub accnofrom {
 my $self = shift;

 if (@_) {
   $self->{accnofrom} = $_[0];
 }

 return $self->{accnofrom};
}

sub accnoto {
 my $self = shift;

 if (@_) {
   $self->{accnoto} = $_[0];
 }

 return $self->{accnoto};
}


sub dbh {
  my $self = shift;

  if (@_) {
    $self->{dbh} = $_[0];
    $self->{provided_dbh} = 1;
  }

  $self->{dbh} ||= SL::DB->client->dbh;
}

sub provided_dbh {
  $_[0]{provided_dbh};
}

sub clean_temporary_directories {
  $::lxdebug->enter_sub;

  foreach my $path (glob($::lx_office_conf{paths}->{userspath} . "/datev-export-*")) {
    next unless -d $path;

    my $mtime = (stat($path))[9];
    next if ((time() - $mtime) < 8 * 60 * 60);

    rmtree $path;
  }

  $::lxdebug->leave_sub;
}

sub _fill {
  $main::lxdebug->enter_sub();

  my $text      = shift // '';
  my $field_len = shift;
  my $fill_char = shift;
  my $alignment = shift || 'right';

  my $text_len  = length $text;

  if ($field_len < $text_len) {
    $text = substr $text, 0, $field_len;

  } elsif ($field_len > $text_len) {
    my $filler = ($fill_char) x ($field_len - $text_len);
    $text      = $alignment eq 'right' ? $filler . $text : $text . $filler;
  }

  $main::lxdebug->leave_sub();

  return $text;
}

sub get_datev_stamm {
  return $_[0]{stamm} ||= selectfirst_hashref_query($::form, $_[0]->dbh, 'SELECT * FROM datev');
}

sub save_datev_stamm {
  my ($self, $data) = @_;

  SL::DB->client->with_transaction(sub {
    do_query($::form, $self->dbh, 'DELETE FROM datev');

    my @columns = qw(beraternr beratername dfvkz mandantennr datentraegernr abrechnungsnr);

    my $query = "INSERT INTO datev (" . join(', ', @columns) . ") VALUES (" . join(', ', ('?') x @columns) . ")";
    do_query($::form, $self->dbh, $query, map { $data->{$_} } @columns);
    1;
  }) or do { die SL::DB->client->error };
}

sub export {
  my ($self) = @_;
  my $result;

  die 'no format set!' unless $self->has_format;

  if ($self->format == DATEV_FORMAT_CSV) {
    $result = $self->csv_export;
  } elsif ($self->format == DATEV_FORMAT_KNE) {
    $result = $self->kne_export;
  } elsif ($self->format == DATEV_FORMAT_OBE) {
    $result = $self->obe_export;
  } else {
    die 'unrecognized export format';
  }

  return $result;
}

sub kne_export {
  my ($self) = @_;
  my $result;

  die 'no exporttype set!' unless $self->has_exporttype;

  if ($self->exporttype == DATEV_ET_BUCHUNGEN) {
    $result = $self->kne_buchungsexport;
  } elsif ($self->exporttype == DATEV_ET_STAMM) {
    $result = $self->kne_stammdatenexport;
  } elsif ($self->exporttype == DATEV_ET_CSV) {
    $result = $self->csv_export_for_tax_accountant;
  } else {
    die 'unrecognized exporttype';
  }

  return $result;
}

sub csv_export {
  my ($self) = @_;
  my $result;

  die 'no exporttype set!' unless $self->has_exporttype;

  if ($self->exporttype == DATEV_ET_BUCHUNGEN) {

    $self->generate_datev_data(from_to => $self->fromto);
    return if $self->errors;

    my $datev_csv = SL::DATEV::CSV->new(
      datev_lines  => $self->generate_datev_lines,
      from         => $self->from,
      to           => $self->to,
      locked       => $self->locked,
    );


    my $filename = "EXTF_DATEV_kivitendo" . $self->from->ymd() . '-' . $self->to->ymd() . ".csv";

    my $csv = Text::CSV_XS->new({
                binary       => 1,
                sep_char     => ";",
                always_quote => 1,
                eol          => "\r\n",
              }) or die "Cannot use CSV: ".Text::CSV_XS->error_diag();

    my $csv_file = IO::File->new($self->export_path . '/' . $filename, '>:encoding(cp1252)') or die "Can't open: $!";
    $csv->print($csv_file, $_) for @{ $datev_csv->header };
    $csv->print($csv_file, $_) for @{ $datev_csv->lines  };
    $csv_file->close;
    $self->{warnings} = $datev_csv->warnings;

    return { download_token => $self->download_token, filenames => $filename };

  } elsif ($self->exporttype == DATEV_ET_STAMM) {
    die 'will never be implemented';
    # 'Background: Export should only contain non
    #  DATEV-Charts and DATEV import will only
    #  import new Charts.'
  } elsif ($self->exporttype == DATEV_ET_CSV) {
    $result = $self->csv_export_for_tax_accountant;
  } else {
    die 'unrecognized exporttype';
  }

  return $result;
}

sub obe_export {
  die 'not yet implemented';
}

sub fromto {
  my ($self) = @_;

  return unless $self->from && $self->to;

  return "transdate >= '" . $self->from->to_lxoffice . "' and transdate <= '" . $self->to->to_lxoffice . "'";
}

sub _sign {
  $_[0] <=> 0;
}

sub locked {
 my $self = shift;

 if (@_) {
   $self->{locked} = $_[0];
 }
 return $self->{locked};
}

sub generate_datev_data {
  $main::lxdebug->enter_sub();

  my ($self, %params)   = @_;
  my $fromto            = $params{from_to} // '';
  my $progress_callback = $params{progress_callback} || sub {};

  my $form     =  $main::form;

  my $trans_id_filter = '';
  my $ar_department_id_filter = '';
  my $ap_department_id_filter = '';
  my $gl_department_id_filter = '';
  if ( $form->{department_id} ) {
    $ar_department_id_filter = " AND ar.department_id = ? ";
    $ap_department_id_filter = " AND ap.department_id = ? ";
    $gl_department_id_filter = " AND gl.department_id = ? ";
  }

  my ($gl_itime_filter, $ar_itime_filter, $ap_itime_filter);
  if ( $form->{gldatefrom} ) {
    $gl_itime_filter = " AND gl.itime >= ? ";
    $ar_itime_filter = " AND ar.itime >= ? ";
    $ap_itime_filter = " AND ap.itime >= ? ";
  } else {
    $gl_itime_filter = "";
    $ar_itime_filter = "";
    $ap_itime_filter = "";
  }

  if ( $self->{trans_id} ) {
    # ignore dates when trans_id is passed so that the entire transaction is
    # checked, not just either the initial bookings or the subsequent payments
    # (the transdates will likely differ)
    $fromto = '';
    $trans_id_filter = 'ac.trans_id = ' . $self->trans_id;
  } else {
    $fromto      =~ s/transdate/ac\.transdate/g;
  };

  my ($notsplitindex);

  my $filter   = '';            # Useful for debugging purposes

  my %all_taxchart_ids = selectall_as_map($form, $self->dbh, qq|SELECT DISTINCT chart_id, TRUE AS is_set FROM tax|, 'chart_id', 'is_set');

  my $ar_accno = "c.accno";
  my $ap_accno = "c.accno";
  if ( $self->use_pk ) {
    $ar_accno = "CASE WHEN ac.chart_link = 'AR' THEN ct.customernumber ELSE c.accno END as accno";
    $ap_accno = "CASE WHEN ac.chart_link = 'AP' THEN ct.vendornumber   ELSE c.accno END as accno";
  }

  my $query    =
    qq|SELECT ac.acc_trans_id, ac.transdate, ac.gldate, ac.trans_id,ar.id, ac.amount, ac.taxkey, ac.memo,
         ar.invnumber, ar.duedate, ar.amount as umsatz, ar.deliverydate, ar.itime::date,
         ct.name, ct.ustid, ct.customernumber AS vcnumber, ct.id AS customer_id, NULL AS vendor_id,
         $ar_accno, c.description AS accname, c.taxkey_id as charttax, c.datevautomatik, c.id, ac.chart_link AS link,
         ar.invoice,
         t.rate AS taxrate, t.taxdescription,
         'ar' as table,
         tc.accno AS tax_accno, tc.description AS tax_accname,
         ar.department_id,
         ar.notes,
         project.projectnumber as projectnumber, project.description as projectdescription,
         department.description as departmentdescription
       FROM acc_trans ac
       LEFT JOIN ar          ON (ac.trans_id    = ar.id)
       LEFT JOIN customer ct ON (ar.customer_id = ct.id)
       LEFT JOIN chart c     ON (ac.chart_id    = c.id)
       LEFT JOIN tax t       ON (ac.tax_id      = t.id)
       LEFT JOIN chart tc    ON (t.chart_id     = tc.id)
       LEFT JOIN department  ON (department.id  = ar.department_id)
       LEFT JOIN project     ON (project.id     = ar.globalproject_id)
       WHERE (ar.id IS NOT NULL)
         AND $fromto
         $trans_id_filter
         $ar_itime_filter
         $ar_department_id_filter
         $filter

       UNION ALL

       SELECT ac.acc_trans_id, ac.transdate, ac.gldate, ac.trans_id,ap.id, ac.amount, ac.taxkey, ac.memo,
         ap.invnumber, ap.duedate, ap.amount as umsatz, ap.deliverydate, ap.itime::date,
         ct.name, ct.ustid, ct.vendornumber AS vcnumber, NULL AS customer_id, ct.id AS vendor_id,
         $ap_accno, c.description AS accname, c.taxkey_id as charttax, c.datevautomatik, c.id, ac.chart_link AS link,
         ap.invoice,
         t.rate AS taxrate, t.taxdescription,
         'ap' as table,
         tc.accno AS tax_accno, tc.description AS tax_accname,
         ap.department_id,
         ap.notes,
         project.projectnumber as projectnumber, project.description as projectdescription,
         department.description as departmentdescription
       FROM acc_trans ac
       LEFT JOIN ap        ON (ac.trans_id  = ap.id)
       LEFT JOIN vendor ct ON (ap.vendor_id = ct.id)
       LEFT JOIN chart c   ON (ac.chart_id  = c.id)
       LEFT JOIN tax t     ON (ac.tax_id    = t.id)
       LEFT JOIN chart tc    ON (t.chart_id     = tc.id)
       LEFT JOIN department  ON (department.id  = ap.department_id)
       LEFT JOIN project     ON (project.id     = ap.globalproject_id)
       WHERE (ap.id IS NOT NULL)
         AND $fromto
         $trans_id_filter
         $ap_itime_filter
         $ap_department_id_filter
         $filter

       UNION ALL

       SELECT ac.acc_trans_id, ac.transdate, ac.gldate, ac.trans_id,gl.id, ac.amount, ac.taxkey, ac.memo,
         gl.reference AS invnumber, gl.transdate AS duedate, ac.amount as umsatz, NULL as deliverydate, gl.itime::date,
         gl.description AS name, NULL as ustid, '' AS vcname, NULL AS customer_id, NULL AS vendor_id,
         c.accno, c.description AS accname, c.taxkey_id as charttax, c.datevautomatik, c.id, ac.chart_link AS link,
         FALSE AS invoice,
         t.rate AS taxrate, t.taxdescription,
         'gl' as table,
         tc.accno AS tax_accno, tc.description AS tax_accname,
         gl.department_id,
         gl.notes,
         '' as projectnumber, '' as projectdescription,
         department.description as departmentdescription
       FROM acc_trans ac
       LEFT JOIN gl      ON (ac.trans_id  = gl.id)
       LEFT JOIN chart c ON (ac.chart_id  = c.id)
       LEFT JOIN tax t   ON (ac.tax_id    = t.id)
       LEFT JOIN chart tc    ON (t.chart_id     = tc.id)
       LEFT JOIN department  ON (department.id  = gl.department_id)
       WHERE (gl.id IS NOT NULL)
         AND $fromto
         $trans_id_filter
         $gl_itime_filter
         $gl_department_id_filter
         $filter

       ORDER BY trans_id, acc_trans_id|;

  my @query_args;
  if ( $form->{gldatefrom} or $form->{department_id} ) {

    for ( 1 .. 3 ) {
      if ( $form->{gldatefrom} ) {
        my $glfromdate = $::locale->parse_date_to_object($form->{gldatefrom});
        die "illegal data" unless ref($glfromdate) eq 'DateTime';
        push(@query_args, $glfromdate);
      }
      if ( $form->{department_id} ) {
        push(@query_args, $form->{department_id});
      }
    }
  }

  my $sth = prepare_execute_query($form, $self->dbh, $query, @query_args);
  $self->{DATEV} = [];

  my $counter = 0;
  my $continue = 1; #
  my $name;
  while ( $continue && (my $ref = $sth->fetchrow_hashref("NAME_lc")) ) {
    last unless $ref;  # for single transactions
    $counter++;
    if (($counter % 500) == 0) {
      $progress_callback->($counter);
    }

    my $trans    = [ $ref ];

    my $count    = $ref->{amount};
    my $firstrun = 1;

    # if the amount of a booking in a group is smaller than 0.02, any tax
    # amounts will likely be smaller than 1 cent, so go into subcent mode
    my $subcent  = abs($count) < 0.02;

    # records from acc_trans are ordered by trans_id and acc_trans_id
    # first check for unbalanced ledger inside one trans_id
    # there may be several groups inside a trans_id, e.g. the original booking and the payment
    # each group individually should be exactly balanced and each group
    # individually needs its own datev lines

    # keep fetching new acc_trans lines until the end of a balanced group is reached
    while (abs($count) > 0.01 || $firstrun || ($subcent && abs($count) > 0.005)) {
      my $ref2 = $sth->fetchrow_hashref("NAME_lc");
      unless ( $ref2 ) {
        $continue = 0;
        last;
      };

      # check if trans_id of current acc_trans line is still the same as the
      # trans_id of the first line in group, i.e. we haven't finished a 0-group
      # before moving on to the next trans_id, error will likely be in the old
      # trans_id.

      if ($ref2->{trans_id} != $trans->[0]->{trans_id}) {
        require SL::DB::Manager::AccTransaction;
        if ( $trans->[0]->{trans_id} ) {
          my $acc_trans_obj  = SL::DB::Manager::AccTransaction->get_first(where => [ trans_id => $trans->[0]->{trans_id} ]);
          $self->add_error(t8("Export error in transaction #1: Unbalanced ledger before next transaction (#2)",
                              $acc_trans_obj->transaction_name, $ref2->{trans_id})
          );
        };
        return;
      }

      push @{ $trans }, $ref2;

      $count    += $ref2->{amount};
      $firstrun  = 0;
    }

    foreach my $i (0 .. scalar(@{ $trans }) - 1) {
      my $ref        = $trans->[$i];
      my $prev_ref   = 0 < $i ? $trans->[$i - 1] : undef;
      if (   $all_taxchart_ids{$ref->{id}}
          && ($ref->{link} =~ m/(?:AP_tax|AR_tax)/)
          && (   ($prev_ref && $prev_ref->{taxkey} && (_sign($ref->{amount}) == _sign($prev_ref->{amount})))
              || $ref->{invoice})) {
        $ref->{is_tax} = 1;
      }

      if (   !$ref->{invoice}   # we have a non-invoice booking (=gl)
          &&  $ref->{is_tax}    # that has "is_tax" set
          && !($prev_ref->{is_tax})  # previous line wasn't is_tax
          &&  (_sign($ref->{amount}) == _sign($prev_ref->{amount}))) {  # and sign same as previous sign
        $trans->[$i - 1]->{tax_amount} = $ref->{amount};
      }
    }

    my $absumsatz     = 0;
    if (scalar(@{$trans}) <= 2) {
      push @{ $self->{DATEV} }, $trans;
      next;
    }

    # determine at which array position the reference value (called absumsatz) is
    # and which amount it has

    for my $j (0 .. (scalar(@{$trans}) - 1)) {

      # Three cases:
      # 1: gl transaction (Dialogbuchung), invoice is false, no double split booking allowed

      # 2: sales or vendor invoice (Verkaufs- und Einkaufsrechnung): invoice is
      # true, instead of absumsatz use link AR/AP (there should only be one
      # entry)

      # 3. AR/AP transaction (Kreditoren- und Debitorenbuchung): invoice is false,
      # instead of absumsatz use link AR/AP (there should only be one, so jump
      # out of search as soon as you find it )

      # case 1 and 2
      # for gl-bookings no split is allowed and there is no AR/AP account, so we always use the maximum value as a reference
      # for ap/ar bookings we can always search for AR/AP in link and use that
      if ( ( not $trans->[$j]->{'invoice'} and abs($trans->[$j]->{'amount'}) > abs($absumsatz) )
         or ($trans->[$j]->{'invoice'} and ($trans->[$j]->{'link'} eq 'AR' or $trans->[$j]->{'link'} eq 'AP'))) {
        $absumsatz     = $trans->[$j]->{'amount'};
        $notsplitindex = $j;
      }

      # case 3
      # Problem: we can't distinguish between AR and AP and normal invoices via boolean "invoice"
      # for AR and AP transaction exit the loop as soon as an AR or AP account is found
      # there must be only one AR or AP chart in the booking
      # since it is possible to do this kind of things with GL too, make sure those don't get aborted in case someone
      # manually pays an invoice in GL.
      if ($trans->[$j]->{table} ne 'gl' and ($trans->[$j]->{'link'} eq 'AR' or $trans->[$j]->{'link'} eq 'AP')) {
        $notsplitindex = $j;   # position in booking with highest amount
        $absumsatz     = $trans->[$j]->{'amount'};
        last;
      };
    }

    my $ml             = ($trans->[0]->{'umsatz'} > 0) ? 1 : -1;
    my $rounding_error = 0;
    my @taxed;

    # go through each line and determine if it is a tax booking or not
    # skip all tax lines and notsplitindex line
    # push all other accounts (e.g. income or expense) with corresponding taxkey

    for my $j (0 .. (scalar(@{$trans}) - 1)) {
      if (   ($j != $notsplitindex)
          && !$trans->[$j]->{is_tax}
          && (   $trans->[$j]->{'taxkey'} eq ""
              || $trans->[$j]->{'taxkey'} eq "0"
              || $trans->[$j]->{'taxkey'} eq "1"
              || $trans->[$j]->{'taxkey'} eq "10"
              || $trans->[$j]->{'taxkey'} eq "11")) {
        my %new_trans = ();
        map { $new_trans{$_} = $trans->[$notsplitindex]->{$_}; } keys %{ $trans->[$notsplitindex] };

        $absumsatz               += $trans->[$j]->{'amount'};
        $new_trans{'amount'}      = $trans->[$j]->{'amount'} * (-1);
        $new_trans{'umsatz'}      = abs($trans->[$j]->{'amount'}) * $ml;
        $trans->[$j]->{'umsatz'}  = abs($trans->[$j]->{'amount'}) * $ml;

        push @{ $self->{DATEV} }, [ \%new_trans, $trans->[$j] ];

      } elsif (($j != $notsplitindex) && !$trans->[$j]->{is_tax}) {

        my %new_trans = ();
        map { $new_trans{$_} = $trans->[$notsplitindex]->{$_}; } keys %{ $trans->[$notsplitindex] };

        my $tax_rate              = $trans->[$j]->{'taxrate'};
        $new_trans{'net_amount'}  = $trans->[$j]->{'amount'} * -1;
        $new_trans{'tax_rate'}    = 1 + $tax_rate;

        if (!$trans->[$j]->{'invoice'}) {
          $new_trans{'amount'}      = $form->round_amount(-1 * ($trans->[$j]->{amount} + $trans->[$j]->{tax_amount}), 2);
          $new_trans{'umsatz'}      = abs($new_trans{'amount'}) * $ml;
          $trans->[$j]->{'umsatz'}  = $new_trans{'umsatz'};
          $absumsatz               += -1 * $new_trans{'amount'};

        } else {
          my $unrounded             = $trans->[$j]->{'amount'} * (1 + $tax_rate) * -1 + $rounding_error;
          my $rounded               = $form->round_amount($unrounded, 2);

          $rounding_error           = $unrounded - $rounded;
          $new_trans{'amount'}      = $rounded;
          $new_trans{'umsatz'}      = abs($rounded) * $ml;
          $trans->[$j]->{'umsatz'}  = $new_trans{umsatz};
          $absumsatz               -= $rounded;
        }

        push @{ $self->{DATEV} }, [ \%new_trans, $trans->[$j] ];
        push @taxed, $self->{DATEV}->[-1];
      }
    }

    my $idx        = 0;
    my $correction = 0;
    while ((abs($absumsatz) >= 0.01) && (abs($absumsatz) < 1.00)) {
      if ($idx >= scalar @taxed) {
        last if (!$correction);

        $correction = 0;
        $idx        = 0;
      }

      my $transaction = $taxed[$idx]->[0];

      my $old_amount     = $transaction->{amount};
      my $old_correction = $correction;
      my @possible_diffs;

      if (!$transaction->{diff}) {
        @possible_diffs = (0.01, -0.01);
      } else {
        @possible_diffs = ($transaction->{diff});
      }

      foreach my $diff (@possible_diffs) {
        my $net_amount = $form->round_amount(($transaction->{amount} + $diff) / $transaction->{tax_rate}, 2);
        next if ($net_amount != $transaction->{net_amount});

        $transaction->{diff}    = $diff;
        $transaction->{amount} += $diff;
        $transaction->{umsatz} += $diff;
        $absumsatz             -= $diff;
        $correction             = 1;

        last;
      }

      $idx++;
    }

    $absumsatz = $form->round_amount($absumsatz, 2);
    if (abs($absumsatz) >= (0.01 * (1 + scalar @taxed))) {
      require SL::DB::Manager::AccTransaction;
      my $acc_trans_obj  = SL::DB::Manager::AccTransaction->get_first(where => [ trans_id => $trans->[0]->{trans_id} ]);
      $self->add_error(t8("Export error in transaction #1: Rounding error too large #2",
                          $acc_trans_obj->transaction_name, $absumsatz)
      );
    } elsif (abs($absumsatz) >= 0.01) {
      $self->add_net_gross_differences($absumsatz);
    }
  }

  $sth->finish();

  $::lxdebug->leave_sub;
}

sub make_kne_data_header {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;
  my ($primanota);

  my $stamm = $self->get_datev_stamm;

  my $jahr = $self->from ? $self->from->year : DateTime->today->year;

  #Header
  my $header  = "\x1D\x181";
  $header    .= _fill($stamm->{datentraegernr}, 3, ' ', 'left');
  $header    .= ($self->fromto) ? "11" : "13"; # Anwendungsnummer
  $header    .= _fill($stamm->{dfvkz}, 2, '0');
  $header    .= _fill($stamm->{beraternr}, 7, '0');
  $header    .= _fill($stamm->{mandantennr}, 5, '0');
  $header    .= _fill(($stamm->{abrechnungsnr} // '') . $jahr, 6, '0');

  $header .= $self->from ? $self->from->strftime('%d%m%y') : '';
  $header .= $self->to   ? $self->to->strftime('%d%m%y')   : '';

  if ($self->fromto) {
    $primanota = "001";
    $header .= $primanota;
  }

  $header .= _fill($stamm->{passwort}, 4, '0');
  $header .= " " x 16;       # Anwendungsinfo
  $header .= " " x 16;       # Inputinfo
  $header .= "\x79";

  #Versionssatz
  my $versionssatz  = $self->exporttype == DATEV_ET_BUCHUNGEN ? "\xB5" . "1," : "\xB6" . "1,";

  my $query         = qq|SELECT accno FROM chart LIMIT 1|;
  my $ref           = selectfirst_hashref_query($form, $self->dbh, $query);

  $versionssatz    .= length $ref->{accno};
  $versionssatz    .= ",";
  $versionssatz    .= length $ref->{accno};
  $versionssatz    .= ",SELF" . "\x1C\x79";

  $header          .= $versionssatz;

  $main::lxdebug->leave_sub();

  return $header;
}

sub datetofour {
  $main::lxdebug->enter_sub();

  my ($date, $six) = @_;

  my ($day, $month, $year) = split(/\./, $date);

  if (length($month) < 2) {
    $month = "0" . $month;
  }
  if (length($year) > 2) {
    $year = substr($year, -2, 2);
  }

  if ($six) {
    $date = $day . $month . $year;
  } else {
    $date = $day . $month;
  }

  $main::lxdebug->leave_sub();

  return $date;
}

sub trim_leading_zeroes {
  my $str = shift;

  $str =~ s/^0+//g;

  return $str;
}

sub make_ed_versionset {
  $main::lxdebug->enter_sub();

  my ($self, $header, $filename, $blockcount) = @_;

  my $versionset  = "V" . substr($filename, 2, 5);
  $versionset    .= substr($header, 6, 22);

  if ($self->fromto) {
    $versionset .= "0000" . substr($header, 28, 19);
  } else {
    my $datum = " " x 16;
    $versionset .= $datum . "001" . substr($header, 28, 4);
  }

  $versionset .= _fill($blockcount, 5, '0');
  $versionset .= "001";
  $versionset .= " 1";
  $versionset .= substr($header, -12, 10) . "    ";
  $versionset .= " " x 53;

  $main::lxdebug->leave_sub();

  return $versionset;
}

sub make_ev_header {
  $main::lxdebug->enter_sub();

  my ($self, $form, $fileno) = @_;

  my $stamm = $self->get_datev_stamm;

  my $ev_header  = _fill($stamm->{datentraegernr}, 3, ' ', 'left');
  $ev_header    .= "   ";
  $ev_header    .= _fill($stamm->{beraternr}, 7, ' ', 'left');
  $ev_header    .= _fill($stamm->{beratername}, 9, ' ', 'left');
  $ev_header    .= " ";
  $ev_header    .= (_fill($fileno, 5, '0')) x 2;
  $ev_header    .= " " x 95;

  $main::lxdebug->leave_sub();

  return $ev_header;
}

sub generate_datev_lines {
  my ($self) = @_;

  my @datev_lines = ();

  foreach my $transaction ( @{ $self->{DATEV} } ) {

    # each $transaction entry contains data from several acc_trans entries
    # belonging to the same trans_id

    my %datev_data = (); # data for one transaction
    my $trans_lines = scalar(@{$transaction});

    my $umsatz         = 0;
    my $gegenkonto     = "";
    my $konto          = "";
    my $belegfeld1     = "";
    my $datum          = "";
    my $waehrung       = "";
    my $buchungstext   = "";
    my $belegfeld2     = "";
    my $datevautomatik = 0;
    my $taxkey         = 0;
    my $charttax       = 0;
    my $ustid          ="";
    my ($haben, $soll);
    for (my $i = 0; $i < $trans_lines; $i++) {
      if ($trans_lines == 2) {
        if (abs($transaction->[$i]->{'amount'}) > abs($umsatz)) {
          $umsatz = $transaction->[$i]->{'amount'};
        }
      } else {
        if (abs($transaction->[$i]->{'umsatz'}) > abs($umsatz)) {
          $umsatz = $transaction->[$i]->{'umsatz'};
        }
      }
      if ($transaction->[$i]->{'datevautomatik'}) {
        $datevautomatik = 1;
      }
      if ($transaction->[$i]->{'taxkey'}) {
        $taxkey = $transaction->[$i]->{'taxkey'};
      }
      if ($transaction->[$i]->{'charttax'}) {
        $charttax = $transaction->[$i]->{'charttax'};
      }
      if ($transaction->[$i]->{'amount'} > 0) {
        $haben = $i;
      } else {
        $soll = $i;
      }
    }

    if ($trans_lines >= 2) {

      # Personenkontenerweiterung: accno has already been replaced if use_pk was set
      $datev_data{'gegenkonto'} = $transaction->[$haben]->{'accno'};
      $datev_data{'konto'}      = $transaction->[$soll]->{'accno'};
      if ($transaction->[$haben]->{'invnumber'} ne "") {
        $datev_data{belegfeld1} = $transaction->[$haben]->{'invnumber'};
      }
      $datev_data{datum} = $transaction->[$haben]->{'transdate'};
      $datev_data{waehrung} = 'EUR';
      $datev_data{kost1} = $transaction->[$haben]->{'departmentdescription'};
      $datev_data{kost2} = $transaction->[$haben]->{'projectdescription'};

      if ($transaction->[$haben]->{'name'} ne "") {
        $datev_data{buchungstext} = $transaction->[$haben]->{'name'};
      }
      if (($transaction->[$haben]->{'ustid'} // '') ne "") {
        $datev_data{ustid} = $transaction->[$haben]->{'ustid'};
      }
      if (($transaction->[$haben]->{'duedate'} // '') ne "") {
        $datev_data{belegfeld2} = $transaction->[$haben]->{'duedate'};
      }
    }
    $datev_data{umsatz} = abs($umsatz); # sales invoices without tax have a different sign???

    # Dies ist die einzige Stelle die datevautomatik auswertet. Was soll gesagt werden?
    # Im Prinzip hat jeder acc_trans Eintrag einen Steuerschlüssel, außer, bei gewissen Fällen
    # wie: Kreditorenbuchung mit negativen Vorzeichen, SEPA-Export oder Rechnungen die per
    # Skript angelegt werden.
    # Also falls ein Steuerschlüssel da ist und NICHT datevautomatik diesen Block hinzufügen.
    # Oder aber datevautomatik ist WAHR, aber der Steuerschlüssel in der acc_trans weicht
    # von dem in der Chart ab: Also wahrscheinlich Programmfehler (NULL übergeben, statt
    # DATEV-Steuerschlüssel) oder der Steuerschlüssel des Kontos weicht WIRKLICH von dem Eintrag in der
    # acc_trans ab. Gibt es für diesen Fall eine plausiblen Grund?
    #

    # only set buchungsschluessel if the following conditions are met:
    if (   ( $datevautomatik || $taxkey)
        && (!$datevautomatik || ($datevautomatik && ($charttax ne $taxkey)))) {
      # $datev_data{buchungsschluessel} = !$datevautomatik ? $taxkey : "4";
      $datev_data{buchungsschluessel} = $taxkey;
    }

    push(@datev_lines, \%datev_data) if $datev_data{umsatz};
  }

  # example of modifying export data:
  # foreach my $datev_line ( @datev_lines ) {
  #   if ( $datev_line{"konto"} eq '1234' ) {
  #     $datev_line{"konto"} = '9999';
  #   }
  # }
  #

  return \@datev_lines;
}


sub kne_buchungsexport {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  my $form = $::form;

  my @filenames;

  my $filename    = "ED00001";
  my $evfile      = "EV01";
  my @ed_versionset;
  my $fileno      = 1;
  my $ed_filename = $self->export_path . $filename;

  my $fromto = $self->fromto;

  $self->generate_datev_data(from_to => $self->fromto); # fetches data from db, transforms data and fills $self->{DATEV}
  return if $self->errors;

  my @datev_lines = @{ $self->generate_datev_lines };


  my $umsatzsumme = sum map { $_->{umsatz} } @datev_lines;

  # prepare kne file, everything gets stored in ED00001
  my $header = $self->make_kne_data_header($form);
  my $kne_file = SL::DATEV::KNEFile->new();
  $kne_file->add_block($header);

  my $iconv   = $::locale->{iconv_utf8};
  my %umlaute = ($iconv->convert('ä') => 'ae',
                 $iconv->convert('ö') => 'oe',
                 $iconv->convert('ü') => 'ue',
                 $iconv->convert('Ä') => 'Ae',
                 $iconv->convert('Ö') => 'Oe',
                 $iconv->convert('Ü') => 'Ue',
                 $iconv->convert('ß') => 'sz');

  # add the data from @datev_lines to the kne_file, formatting as needed
  foreach my $kne ( @datev_lines ) {
    $kne_file->add_block("+" . $kne_file->format_amount(abs($kne->{umsatz}), 0));

    # only add buchungsschluessel if it was previously defined
    $kne_file->add_block("\x6C" . $kne->{buchungsschluessel}) if defined $kne->{buchungsschluessel};

    # ($kne->{gegenkonto}) = $kne->{gegenkonto} =~ /^(\d+)/;
    $kne_file->add_block("a" . trim_leading_zeroes($kne->{gegenkonto}));

    if ( $kne->{belegfeld1} ) {
      my $invnumber = $kne->{belegfeld1};
      foreach my $umlaut (keys(%umlaute)) {
        $invnumber =~ s/${umlaut}/${umlaute{$umlaut}}/g;
      }
      $invnumber =~ s/[^0-9A-Za-z\$\%\&\*\+\-\/]//g;
      $invnumber =  substr($invnumber, 0, 12);
      $invnumber =~ s/\ *$//;
      $kne_file->add_block("\xBD" . $invnumber . "\x1C");
    }

    $kne_file->add_block("\xBE" . &datetofour($kne->{belegfeld2},1) . "\x1C");

    $kne_file->add_block("d" . &datetofour($kne->{datum},0));

    # ($kne->{konto}) = $kne->{konto} =~ /^(\d+)/;
    $kne_file->add_block("e" . trim_leading_zeroes($kne->{konto}));

    my $name = $kne->{buchungstext};
    foreach my $umlaut (keys(%umlaute)) {
      $name =~ s/${umlaut}/${umlaute{$umlaut}}/g;
    }
    $name =~ s/[^0-9A-Za-z\$\%\&\*\+\-\ \/]//g;
    $name =  substr($name, 0, 30);
    $name =~ s/\ *$//;
    $kne_file->add_block("\x1E" . $name . "\x1C");

    $kne_file->add_block("\xBA" . $kne->{'ustid'}    . "\x1C") if $kne->{'ustid'};

    $kne_file->add_block("\xB3" . $kne->{'waehrung'} . "\x1C" . "\x79");
  };

  $umsatzsumme          = $kne_file->format_amount(abs($umsatzsumme), 0);
  my $mandantenendsumme = "x" . $kne_file->format_amount($umsatzsumme / 100.0, 14) . "\x79\x7a";

  $kne_file->add_block($mandantenendsumme);
  $kne_file->flush();

  open(ED, ">", $ed_filename) or die "can't open outputfile: $!\n";
  print(ED $kne_file->get_data());
  close(ED);

  $ed_versionset[$fileno] = $self->make_ed_versionset($header, $filename, $kne_file->get_block_count());

  #Make EV Verwaltungsdatei
  my $ev_header   = $self->make_ev_header($form, $fileno);
  my $ev_filename = $self->export_path . $evfile;
  push(@filenames, $evfile);
  open(EV, ">", $ev_filename) or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach my $file (@ed_versionset) {
    print(EV $file);
  }
  close(EV);
  ###

  $self->add_filenames(@filenames);

  $main::lxdebug->leave_sub();

  return { 'download_token' => $self->download_token, 'filenames' => \@filenames };
}

sub kne_stammdatenexport {
  $main::lxdebug->enter_sub();

  my ($self) = @_;
  my $form = $::form;

  $self->get_datev_stamm->{abrechnungsnr} = "99";

  my @filenames;

  my $filename    = "ED00000";
  my $evfile      = "EV01";
  my @ed_versionset;
  my $fileno          = 1;
  my $i               = 0;
  my $blockcount      = 1;
  my $remaining_bytes = 256;
  my $total_bytes     = 256;
  my $buchungssatz    = "";
  $filename++;
  my $ed_filename = $self->export_path . $filename;
  push(@filenames, $filename);
  open(ED, ">", $ed_filename) or die "can't open outputfile: $!\n";
  my $header = $self->make_kne_data_header($form);
  $remaining_bytes -= length($header);

  my $fuellzeichen;

  my (@where, @values) = ((), ());
  if ($self->accnofrom) {
    push @where, 'c.accno >= ?';
    push @values, $self->accnofrom;
  }
  if ($self->accnoto) {
    push @where, 'c.accno <= ?';
    push @values, $self->accnoto;
  }

  my $where_str = @where ? ' WHERE ' . join(' AND ', map { "($_)" } @where) : '';

  my $query     = qq|SELECT c.accno, c.description
                     FROM chart c
                     $where_str
                     ORDER BY c.accno|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute(@values) || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    if (($remaining_bytes - length("t" . $ref->{'accno'})) <= 6) {
      $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
      $buchungssatz .= "\x00" x $fuellzeichen;
      $blockcount++;
      $total_bytes = ($blockcount) * 256;
    }
    $buchungssatz .= "t" . $ref->{'accno'};
    $remaining_bytes = $total_bytes - length($buchungssatz . $header);
    $ref->{'description'} =~ s/[^0-9A-Za-z\$\%\&\*\+\-\/]//g;
    $ref->{'description'} = substr($ref->{'description'}, 0, 40);
    $ref->{'description'} =~ s/\ *$//;

    if (
        ($remaining_bytes - length("\x1E" . $ref->{'description'} . "\x1C\x79")
        ) <= 6
      ) {
      $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
      $buchungssatz .= "\x00" x $fuellzeichen;
      $blockcount++;
      $total_bytes = ($blockcount) * 256;
    }
    $buchungssatz .= "\x1E" . $ref->{'description'} . "\x1C\x79";
    $remaining_bytes = $total_bytes - length($buchungssatz . $header);
  }

  $sth->finish;
  print(ED $header);
  print(ED $buchungssatz);
  $fuellzeichen = 256 - (length($header . $buchungssatz . "z") % 256);
  my $dateiende = "\x00" x $fuellzeichen;
  print(ED "z");
  print(ED $dateiende);
  close(ED);

  #Make EV Verwaltungsdatei
  $ed_versionset[0] =
    $self->make_ed_versionset($header, $filename, $blockcount);

  my $ev_header = $self->make_ev_header($form, $fileno);
  my $ev_filename = $self->export_path . $evfile;
  push(@filenames, $evfile);
  open(EV, ">", $ev_filename) or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach my $file (@ed_versionset) {
    print(EV $ed_versionset[$file]);
  }
  close(EV);

  $self->add_filenames(@filenames);

  $main::lxdebug->leave_sub();

  return { 'download_token' => $self->download_token, 'filenames' => \@filenames };
}

sub _format_accno {
  my ($accno) = @_;
  return $accno . ('0' x (6 - min(length($accno), 6)));
}

sub csv_export_for_tax_accountant {
  my ($self) = @_;

  $self->generate_datev_data(from_to => $self->fromto);

  foreach my $transaction (@{ $self->{DATEV} }) {
    foreach my $entry (@{ $transaction }) {
      $entry->{sortkey} = join '-', map { lc } (DateTime->from_kivitendo($entry->{transdate})->strftime('%Y%m%d'), $entry->{name}, $entry->{reference});
    }
  }

  my %transactions =
    partition_by { $_->[0]->{table} }
    sort_by      { $_->[0]->{sortkey} }
    grep         { 2 == scalar(@{ $_ }) }
    @{ $self->{DATEV} };

  my %column_defs = (
    acc_trans_id      => { 'text' => $::locale->text('ID'), },
    amount            => { 'text' => $::locale->text('Amount'), },
    credit_accname    => { 'text' => $::locale->text('Credit Account Name'), },
    credit_accno      => { 'text' => $::locale->text('Credit Account'), },
    debit_accname     => { 'text' => $::locale->text('Debit Account Name'), },
    debit_accno       => { 'text' => $::locale->text('Debit Account'), },
    invnumber         => { 'text' => $::locale->text('Reference'), },
    name              => { 'text' => $::locale->text('Name'), },
    notes             => { 'text' => $::locale->text('Notes'), },
    tax               => { 'text' => $::locale->text('Tax'), },
    taxkey            => { 'text' => $::locale->text('Taxkey'), },
    tax_accname       => { 'text' => $::locale->text('Tax Account Name'), },
    tax_accno         => { 'text' => $::locale->text('Tax Account'), },
    transdate         => { 'text' => $::locale->text('Transdate'), },
    vcnumber          => { 'text' => $::locale->text('Customer/Vendor Number'), },
  );

  my @columns = qw(
    acc_trans_id name           vcnumber
    transdate    invnumber      amount
    debit_accno  debit_accname
    credit_accno credit_accname
    tax
    tax_accno    tax_accname    taxkey
    notes
  );

  my %filenames_by_type = (
    ar => $::locale->text('AR Transactions'),
    ap => $::locale->text('AP Transactions'),
    gl => $::locale->text('GL Transactions'),
  );

  my @filenames;
  foreach my $type (qw(ap ar)) {
    my %csvs = (
      invoices   => {
        content  => '',
        filename => sprintf('%s %s - %s.csv', $filenames_by_type{$type}, $self->from->to_kivitendo, $self->to->to_kivitendo),
        csv      => Text::CSV_XS->new({
          binary   => 1,
          eol      => "\n",
          sep_char => ";",
        }),
      },
      payments   => {
        content  => '',
        filename => sprintf('Zahlungen %s %s - %s.csv', $filenames_by_type{$type}, $self->from->to_kivitendo, $self->to->to_kivitendo),
        csv      => Text::CSV_XS->new({
          binary   => 1,
          eol      => "\n",
          sep_char => ";",
        }),
      },
    );

    foreach my $csv (values %csvs) {
      $csv->{out} = IO::File->new($self->export_path . '/' . $csv->{filename}, '>:encoding(utf8)') ;
      $csv->{csv}->print($csv->{out}, [ map { $column_defs{$_}->{text} } @columns ]);

      push @filenames, $csv->{filename};
    }

    foreach my $transaction (@{ $transactions{$type} }) {
      my $is_payment     = any { $_->{link} =~ m{A[PR]_paid} } @{ $transaction };
      my $csv            = $is_payment ? $csvs{payments} : $csvs{invoices};

      my ($soll, $haben) = map { $transaction->[$_] } ($transaction->[0]->{amount} > 0 ? (1, 0) : (0, 1));
      my $tax            = defined($soll->{tax_accno})  ? $soll : $haben;
      my $amount         = defined($soll->{net_amount}) ? $soll : $haben;
      $haben->{notes}    = ($haben->{memo} || $soll->{memo}) if $is_payment;
      $haben->{notes}  //= '';
      $haben->{notes}    =  SL::HTML::Util->strip($haben->{notes});
      $haben->{notes}    =~ s{\r}{}g;
      $haben->{notes}    =~ s{\n+}{ }g;

      my %row            = (
        amount           => $::form->format_amount({ numberformat => '1000,00' }, abs($amount->{amount}), 2),
        debit_accno      => _format_accno($soll->{accno}),
        debit_accname    => $soll->{accname},
        credit_accno     => _format_accno($haben->{accno}),
        credit_accname   => $haben->{accname},
        tax              => $::form->format_amount({ numberformat => '1000,00' }, abs($amount->{amount}) - abs($amount->{net_amount}), 2),
        notes            => $haben->{notes},
        (map { ($_ => $tax->{$_})                    } qw(taxkey tax_accname tax_accno)),
        (map { ($_ => ($haben->{$_} // $soll->{$_})) } qw(acc_trans_id invnumber name vcnumber transdate)),
      );

      $csv->{csv}->print($csv->{out}, [ map { $row{$_} } @columns ]);
    }

    $_->{out}->close for values %csvs;
  }

  $self->add_filenames(@filenames);

  return { download_token => $self->download_token, filenames => \@filenames };
}

sub check_vcnumbers_are_valid_pk_numbers {
  my ($self) = @_;

  # better use a class variable and set this in sub new (also needed in DATEV::CSV)
  # calculation is also a bit more sane in sub check_valid_length_of_accounts
  my $length_of_accounts = length(SL::DB::Manager::Chart->get_first(where => [charttype => 'A'])->accno) // 4;
  my $pk_length = $length_of_accounts + 1;
  my $query = <<"SQL";
   SELECT customernumber AS vcnumber FROM customer WHERE customernumber !~ '^[[:digit:]]{$pk_length}\$'
   UNION
   SELECT vendornumber   AS vcnumber FROM vendor   WHERE vendornumber   !~ '^[[:digit:]]{$pk_length}\$'
   LIMIT 1;
SQL
  my ($has_non_pk_accounts)  = selectrow_query($::form, SL::DB->client->dbh, $query);
  return defined $has_non_pk_accounts ? 0 : 1;
}


sub check_valid_length_of_accounts {
  my ($self) = @_;

  my $query = <<"SQL";
  SELECT DISTINCT char_length (accno) FROM chart WHERE charttype='A' AND id in (select chart_id from acc_trans);
SQL

  my $accno_length = selectall_hashref_query($::form, SL::DB->client->dbh, $query);
  if (1 < scalar @$accno_length) {
    $::form->error(t8("Invalid combination of ledger account number length." .
                      " Mismatch length of #1 with length of #2. Please check your account settings. ",
                      $accno_length->[0]->{char_length}, $accno_length->[1]->{char_length}));
  }
  return 1;
}

sub DESTROY {
  clean_temporary_directories();
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DATEV - kivitendo DATEV Export module

=head1 SYNOPSIS

  use SL::DATEV qw(:CONSTANTS);

  my $startdate = DateTime->new(year => 2014, month => 9, day => 1);
  my $enddate   = DateTime->new(year => 2014, month => 9, day => 31);
  my $datev = SL::DATEV->new(
    exporttype => DATEV_ET_BUCHUNGEN,
    format     => DATEV_FORMAT_KNE,
    from       => $startdate,
    to         => $enddate,
  );

  # To only export transactions from a specific trans_id: (from and to are ignored)
  my $invoice = SL::DB::Manager::Invoice->find_by( invnumber => '216' );
  my $datev = SL::DATEV->new(
    exporttype => DATEV_ET_BUCHUNGEN,
    format     => DATEV_FORMAT_KNE,
    trans_id   => $invoice->trans_id,
  );

  my $datev = SL::DATEV->new(
    exporttype => DATEV_ET_STAMM,
    format     => DATEV_FORMAT_KNE,
    accnofrom  => $start_account_number,
    accnoto    => $end_account_number,
  );

  # get or set datev stamm
  my $hashref = $datev->get_datev_stamm;
  $datev->save_datev_stamm($hashref);

  # manually clean up temporary directories older than 8 hours
  $datev->clean_temporary_directories;

  # export
  $datev->export;

  if ($datev->errors) {
    die join "\n", $datev->error;
  }

  # get relevant data for saving the export:
  my $dl_token = $datev->download_token;
  my $path     = $datev->export_path;
  my @files    = $datev->filenames;

  # retrieving an export at a later time
  my $datev = SL::DATEV->new(
    download_token => $dl_token_from_user,
  );

  my $path     = $datev->export_path;
  my @files    = glob("$path/*");

  # Only test the datev data of a specific trans_id, without generating an
  # export file, but filling $datev->errors if errors exist

  my $datev = SL::DATEV->new(
    trans_id   => $invoice->trans_id,
  );
  $datev->generate_datev_data;
  # if ($datev->errors) { ...


=head1 DESCRIPTION

This module implements the DATEV export standard. For usage see above.

=head1 FUNCTIONS

=over 4

=item new PARAMS

Generic constructor. See section attributes for information about what to pass.

=item generate_datev_data

Fetches all transactions from the database (via a trans_id or a date range),
and does an initial transformation (e.g. filters out tax, determines
the brutto amount, checks split transactions ...) and stores this data in
$self->{DATEV}.

If any errors are found these are collected in $self->errors.

This function is needed for all the exports, but can be also called
independently in order to check transactions for DATEV compatibility.

=item generate_datev_lines

Parse the data in $self->{DATEV} and transform it into a format that can be
used by DATEV, e.g. determines Konto and Gegenkonto, the taxkey, ...

The transformed data is returned as an arrayref, which is ready to be converted
to a DATEV data format, e.g. KNE, OBE, CSV, ...

At this stage the "DATEV rule" has already been applied to the taxkeys, i.e.
entries with datevautomatik have an empty taxkey, as the taxkey is already
determined by the chart.

=item get_datev_stamm

Loads DATEV Stammdaten and returns as hashref.

=item save_datev_stamm HASHREF

Saves DATEV Stammdaten from provided hashref.

=item exporttype

See L<CONSTANTS> for possible values

=item has_exporttype

Returns true if an exporttype has been set. Without exporttype most report functions won't work.

=item format

Specifies the designated format of the export. Currently only KNE export is implemented.

See L<CONSTANTS> for possible values

=item has_format

Returns true if a format has been set. Without format most report functions won't work.

=item download_token

Returns a download token for this DATEV object.

Note: If either a download_token or export_path were set at the creation these are infered, otherwise randomly generated.

=item export_path

Returns an export_path for this DATEV object.

Note: If either a download_token or export_path were set at the creation these are infered, otherwise randomly generated.

=item filenames

Returns a list of filenames generated by this DATEV object. This only works if the files were generated during its lifetime, not if the object was created from a download_token.

=item net_gross_differences

If there were any net gross differences during calculation they will be collected here.

=item sum_net_gross_differences

Sum of all differences.

=item clean_temporary_directories

Forces a garbage collection on previous exports which will delete all exports that are older than 8 hours. It will be automatically called on destruction of the object, but is advised to be called manually before delivering results of an export to the user.

=item errors

Returns a list of errors that occured. If no errors occured, the export was a success.

=item export

Exports data. You have to have set L<exporttype> and L<format> or an error will
occur. OBE exports are currently not implemented.

=item csv_export_for_tax_accountant

Generates up to four downloadable csv files containing data about sales and
purchase invoices, and their respective payments:

Example:
  my $startdate = DateTime->new(year => 2012, month =>  1, day =>  1);
  my $enddate   = DateTime->new(year => 2012, month => 12, day => 31);
  SL::DATEV->new(from => $startdate, to => $enddate)->csv_export_for_tax_accountant;
  # {
  #   'download_token' => '1488551625-815654-22430',
  #   'filenames' => [
  #                    'Zahlungen Kreditorenbuchungen 2012-01-01 - 2012-12-31.csv',
  #                    'Kreditorenbuchungen 2012-01-01 - 2012-12-31.csv',
  #                    'Zahlungen Debitorenbuchungen 2012-01-01 - 2012-12-31.csv',
  #                    'Debitorenbuchungen 2012-01-01 - 2012-12-31.csv'
  #                  ]
  # };


=item check_vcnumbers_are_valid_pk_numbers

Returns 1 if all vcnumbers are suitable for the DATEV export, 0 if not.

Finds the default length of charts (e.g. 4), adds 1 for the pk chart length
(e.g. 5), and checks the database for any customers or vendors whose customer-
or vendornumber doesn't consist of only numbers with exactly that length. E.g.
for a chart length of four "10001" would be ok, but not "10001b" or "1000".

All vcnumbers are checked, obsolete customers or vendors aren't exempt.

There is also no check for the typical customer range 10000-69999 and the
typical vendor range 70000-99999.

=item check_valid_length_of_accounts

Returns 1 if all currently booked accounts have only one common number length domain (e.g. 4 or 6).
Will throw an error if more than one distinct size is detected.
The error message gives a short hint with the value of the (at least)
two mismatching number length domains.

=back

=head1 ATTRIBUTES

This is a list of attributes set in either the C<new> or a method of the same name.

=over 4

=item dbh

Set a database handle to use in the process. This allows for an export to be
done on a transaction in progress without committing first.

Note: If you don't want this code to commit, simply providing a dbh is not
enough enymore. You'll have to wrap the call into a transaction yourself, so
that the internal transaction does not commit.

=item exporttype

See L<CONSTANTS> for possible values. This MUST be set before export is called.

=item format

See L<CONSTANTS> for possible values. This MUST be set before export is called.

=item download_token

Can be set on creation to retrieve a prior export for download.

=item from

=item to

Set boundary dates for the export. Unless a trans_id is passed these MUST be
set for the export to work.

=item trans_id

To check only one gl/ar/ap transaction, pass the trans_id. The attributes
L<from> and L<to> are currently still needed for the query to be assembled
correctly.

=item accnofrom

=item accnoto

Set boundary account numbers for the export. Only useful for a stammdaten export.

=item locked

Boolean if the transactions are locked (read-only in kivitenod) or not.
Default value is false

=back

=head1 CONSTANTS

=head2 Supplied to L<exporttype>

=over 4

=item DATEV_ET_BUCHUNGEN

=item DATEV_ET_STAMM

=back

=head2 Supplied to L<format>.

=over 4

=item DATEV_FORMAT_KNE

=item DATEV_FORMAT_OBE

=back

=head1 ERROR HANDLING

This module will die in the following cases:

=over 4

=item *

No or unrecognized exporttype or format was provided for an export

=item *

OBE export was called, which is not yet implemented.

=item *

general I/O errors

=back

Errors that occur during th actual export will be collected in L<errors>. The following types can occur at the moment:

=over 4

=item *

C<Unbalanced Ledger!>. Exactly that, your ledger is unbalanced. Should never occur.

=item *

C<Datev-Export fehlgeschlagen! Bei Transaktion %d (%f).>  This error occurs if a
transaction could not be reliably sorted out, or had rounding errors above the acceptable threshold.

=back

=head1 BUGS AND CAVEATS

=over 4

=item *

Handling of Vollvorlauf is currently not fully implemented. You must provide both from and to in order to get a working export.

=item *

OBE export is currently not implemented.

=back

=head1 TODO

- handling of export_path and download token is a bit dodgy, clean that up.

=head1 SEE ALSO

L<SL::DATEV::KNEFile>
L<SL::DATEV::CSV>

=head1 AUTHORS

Philip Reetz E<lt>p.reetz@linet-services.deE<gt>,

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,

Jan Büren E<lt>jan@lx-office-hosting.deE<gt>,

Geoffrey Richardson E<lt>information@lx-office-hosting.deE<gt>,

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,

Stephan Köhler

=cut
