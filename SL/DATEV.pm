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
use SL::DATEV::CSV;
use SL::DB;
use Encode qw(encode);
use SL::HTML::Util ();
use SL::Iconv;
use SL::Locale::String qw(t8);
use SL::VATIDNr;

use Archive::Zip;
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
use XML::LibXML;

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
   die "Invalid type, need DateTime Object" unless ref $_[0] eq 'DateTime';
   $self->{from} = $_[0];
 }

 return $self->{from};
}

sub to {
 my $self = shift;

 if (@_) {
   die "Invalid type, need DateTime Object" unless ref $_[0] eq 'DateTime';
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

  return $self->csv_export;
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

    # get encoding from defaults - use cp1252 if DATEV strict export is used
    my $enc = ($::instance_conf->get_datev_export_format eq 'cp1252') ? 'cp1252' : 'utf-8';
    my $csv_file = IO::File->new($self->export_path . '/' . $filename, ">:encoding($enc)") or die "Can't open: $!";

    $csv->print($csv_file, $_) for @{ $datev_csv->header };
    $csv->print($csv_file, $_) for @{ $datev_csv->lines  };
    $csv_file->close;
    $self->{warnings} = $datev_csv->warnings;

    $self->_create_xml_and_documents if $self->{documents} && $self->{guids} && %{ $self->{guids} };

    # convert utf-8 to cp1252//translit if set
    if ($::instance_conf->get_datev_export_format eq 'cp1252-translit') {

      my $filename_translit = "EXTF_DATEV_kivitendo_translit" . $self->from->ymd() . '-' . $self->to->ymd() . ".csv";
      open my $fh_in,  '<:encoding(UTF-8)',  $self->export_path . '/' . $filename or die "could not open $filename for reading: $!";
      open my $fh_out, '>', $self->export_path . '/' . $filename_translit         or die "could not open $filename_translit for writing: $!";

      my $converter = SL::Iconv->new("utf-8", "cp1252//translit");

      print $fh_out $converter->convert($_) while <$fh_in>;
      close $fh_in;
      close $fh_out;

      unlink $self->export_path . '/' . $filename or warn "Could not unlink $filename: $!";
      $filename = $filename_translit;
    }

    return { download_token => $self->download_token, filenames => $filename };

  } else {
    die 'unrecognized exporttype';
  }

  return $result;
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

sub imported {
 my $self = shift;

 if (@_) {
   $self->{imported} = $_[0];
 }
 return $self->{imported};
}

sub documents {
 my $self = shift;

 if (@_) {
   $self->{documents} = $_[0];
 }
 return $self->{documents};
}

sub _create_xml_and_documents {
  my $self = shift;

  die "No guids" unless %{ $self->{guids} };

  my $today = DateTime->now_local;
  my $doc   = XML::LibXML::Document->new('1.0', 'utf-8');

  my $root  = $doc->createElement('archive');
  #<archive xmlns="http://xml.datev.de/bedi/tps/document/v05.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://xml.datev.de/bedi/tps/document/v05.0 Document_v050.xsd" version="5.0" generatingSystem="DATEV-Musterdaten">

  $root->setAttribute('xmlns'              => 'http://xml.datev.de/bedi/tps/document/v05.0');
  $root->setAttribute('xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance');
  $root->setAttribute('xsi:schemaLocation' => 'http://xml.datev.de/bedi/tps/document/v05.0 Document_v050.xsd');
  $root->setAttribute('version'            => '5.0');
  $root->setAttribute('generatingSystem'   => 'kivitendo');

  # header with timestamp
  my $header_tag = $doc->createElement('header');
  $root->appendChild($header_tag);
  my $date_tag = $doc->createElement('date');
  $date_tag->appendTextNode($today);
  $header_tag->appendChild($date_tag);


  # content
  my $content_node = $doc->createElement('content');
  $root->appendChild($content_node);
  # we have n document childs
  foreach my $guid (keys %{ $self->{guids} }) {
    # 1. get filename and file location
    my $file_version = SL::DB::Manager::FileVersion->find_by(guid => $guid);
    die "Invalid guid $guid" unless ref $file_version eq 'SL::DB::FileVersion';
    # file_name has to be unique add guid if needed
    my $filename_for_zip = (exists $self->{files}{$file_version->file_name})
                           ? $file_version->file_name . '__' . $guid
                           : $file_version->file_name;
    $filename_for_zip = $guid . '.pdf';
    $self->{files}{$filename_for_zip} = $file_version->get_system_location;
    # create xml metadata for files
    my $document_node = $doc->createElement('document');
    # set attr
    $document_node->setAttribute('guid'      => $guid);
    $document_node->setAttribute('processID' => '1');
    $document_node->setAttribute('type'      => '1');
    $content_node->appendChild($document_node);
    my $extension_node = $doc->createElement('extension');
    $extension_node->setAttribute('xsi:type' => 'File');
    $extension_node->setAttribute('name'     => $filename_for_zip);
    $document_node->appendChild($extension_node);
  }
  $doc->setDocumentElement($root);

  # create Archive::Zip in Export Path
  my $zip = Archive::Zip->new();
  # add metadata document
  $zip->addString($doc->toString(), 'document.xml');
  # add real files
  foreach my $filename (keys %{ $self->{files} }) {
#    my $enc_filename = encode('Windows-1252', $filename);
    $zip->addFile($self->{files}{$filename}, $filename);
  }
  die "Cannot write Belege-XML.zip" unless ($zip->writeToFileNamed($self->export_path . 'Belege-XML.zip')
                                            == Archive::Zip::AZ_OK());
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
  my $gl_imported;
  if ( !$self->imported ) {
    $gl_imported = " AND NOT imported";
  }

  my $query    =
    qq|SELECT ac.acc_trans_id, ac.transdate, ac.gldate, ac.trans_id,ar.id, ac.amount, ac.taxkey, ac.memo,
         ar.invnumber, ar.duedate, ar.amount as umsatz, COALESCE(ar.tax_point, ar.deliverydate) AS deliverydate, ar.itime::date,
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
         ap.invnumber, ap.duedate, ap.amount as umsatz, COALESCE(ap.tax_point, ap.deliverydate) AS deliverydate, ap.itime::date,
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
         gl.reference AS invnumber, NULL AS duedate, ac.amount as umsatz, COALESCE(gl.tax_point, gl.deliverydate) AS deliverydate, gl.itime::date,
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
         $gl_imported
         AND NOT EXISTS (SELECT gl_id from ap_gl where gl_id = gl.id)
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
    my $customernumber = "";
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
        # $taxkey = 0 if $taxkey == 94; # taxbookings are in gl
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
            if ($transaction->[$haben]->{'vcnumber'} ne "") {
        $datev_data{customernumber} = $transaction->[$haben]->{'vcnumber'};
      }
      if (($transaction->[$haben]->{'ustid'} // '') ne "") {
        $datev_data{ustid} = SL::VATIDNr->normalize($transaction->[$haben]->{'ustid'});
      }
      if (($transaction->[$haben]->{'duedate'} // '') ne "") {
        $datev_data{belegfeld2} = $transaction->[$haben]->{'duedate'};
      }

      # if deliverydate exists, add it to datev export if it is
      # * an ar/ap booking that is not a payment
      # * a gl booking
      if (    ($transaction->[$haben]->{'deliverydate'} // '') ne ''
           && (
                (    $transaction->[$haben]->{'table'} =~ /^(ar|ap)$/
                  && $transaction->[$haben]->{'link'}  !~ m/_paid/
                  && $transaction->[$soll]->{'link'}   !~ m/_paid/
                )
                || $transaction->[$haben]->{'table'} eq 'gl'
              )
         ) {
        $datev_data{leistungsdatum} = $transaction->[$haben]->{'deliverydate'};
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
    # set lock for each transaction
    $datev_data{locked} = $self->locked;
    # add guids if datev export with documents is requested
    if ($self->documents) {
      # add all document links for the latest created/uploaded document
      my $latest_document = SL::DB::Manager::File->get_first(query =>
                                [
                                  object_id   => $transaction->[$haben]->{trans_id},
                                  file_type   => 'document',
                                  mime_type   => 'application/pdf',
                                  or          => [
                                                   object_type => 'gl_transaction',
                                                   object_type => 'purchase_invoice',
                                                   object_type => 'invoice',
                                                   object_type => 'credit_note',
                                                 ],
                                ],
                                  sort_by   => 'itime DESC');
      if (ref $latest_document eq 'SL::DB::File') {
      #if (scalar @{ $latest_documents }) {
        # if we have a booking document add guid from the latest version
        # one record may be referenced to more transaction (credit booking with different accounts)
        # therefore collect guids in hash
        # not yet implemented -> datev steigt aus, sobald ein komma getrennter wert erscheint
        #foreach my $latest_document (@{ $latest_documents }) {
          die "No file datatype:" . ref $latest_document unless (ref $latest_document eq 'SL::DB::File');
          my $latest_guid = $latest_document->file_versions_sorted->[-1]->guid;

          $self->{guids}{$latest_guid} = 1;
          $datev_data{document_guid}  .= $datev_data{document_guid} ?  ',' : '';
          $datev_data{document_guid}  .= $latest_guid;
        # }
      }
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

sub check_document_export {
  my ($self) = @_;

  # no dms enabled and works only for type Filesystem
  return 0 unless $::instance_conf->get_doc_storage
               && $::instance_conf->get_doc_storage_for_documents eq 'Filesystem';

  return 1;

}

sub check_all_bookings_have_documents {
  my $self   = shift;
  my %params = @_;

  die "Need from date" unless $params{from};
  die "Need to date"   unless $params{to};

  $self->from($params{from});
  $self->to($params{to});

  my $fromto = $self->fromto;
  # not all last month ar ap gl booking have an entry -> rent ?
  my $query = qq|
  select distinct trans_id,object_id from acc_trans
  left join files on files.object_id=trans_id
  where $fromto
  and object_id is null
  and trans_id not in (select id from gl)
  LIMIT 1|;

  my ($booking_has_no_document)  = selectrow_query($::form, SL::DB->client->dbh, $query);
  return defined $booking_has_no_document ? 0 : 1;

}



sub _u8 {
  my ($value) = @_;
  return encode('UTF-8', $value // '');
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

Returns a list of errors that occurred. If no errors occurred, the export was a success.

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

=item check_document_export

Returns 1 if DMS feature is enabled and Backend is Filesystem

=item check_all_bookings_have_documents

Returns 1 if all ar and ap transactions for this period have a document entry in files.
Therefore all ar and ap transactions may be exported.
Note: DATEV accepts only PDF and for some gl bookings a document makes no sense


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
