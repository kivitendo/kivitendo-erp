package SL::Helper::MT940;

use strict;
use File::Path qw(mkpath);
use File::Copy qw(copy);

sub convert_mt940_data {
  my ($mt940_data) = @_;

  # takes the data from an uploaded mt940 file, converts it to csv via aqbanking and returns the converted data
  # The uploaded file data is stored as a session file, just like the aqbanking settings file.

  my $import_filename = 'bank_transfer.940';
  my $sfile = SL::SessionFile->new($import_filename, mode => '>');
  $sfile->fh->print($mt940_data);
  $sfile->fh->close;

  my $todir = $sfile->get_path . '/imexporters/csv/profiles';
  mkpath $todir;
  File::Copy::copy('users/aqbanking.conf', $todir.'/kivi.conf');

  my $aqbin = $::lx_office_conf{applications}->{aqbanking};
  die "Can't find aqbanking-cli, please check your configuration file.\n" unless -f $aqbin;
  my $cmd = "$aqbin --cfgdir=\"" . $sfile->get_path . "\" import --importer=\"swift\" --profile=\"SWIFT-MT940\" -f " .
          $sfile->get_path . "/$import_filename | $aqbin --cfgdir=\"" . $sfile->get_path . "\" listtrans --exporter=\"csv\" --profile=kivi 2> /dev/null ";

  my $converted_data = '"empty";"local_bank_code";"local_account_number";"remote_bank_code";"remote_account_number";"transdate";"valutadate";"amount";'.
    '"currency";"remote_name";"remote_name_1";"purpose";"purpose1";"purpose2";"purpose3";"purpose4";"purpose5";"purpose6";"purpose7";"purpose8";"purpose9";'.
    '"purpose10";"purpose11";"transaction_key";"customer_reference";"bank_reference";"transaction_code";"transaction_text"'."\n";

  open my $mt, "-|", "$cmd" || die "Problem with executing aqbanking\n";
  my $headerline = <$mt>;  # discard original aqbanking header line
  while (<$mt>) {
    $converted_data .= $_;
  };
  close $mt;
  return $converted_data;
};

1;
