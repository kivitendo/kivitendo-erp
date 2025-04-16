package SL::POS::TSEAPI;

use strict;
use warnings;
use SL::DB::TSEDevice;

use SL::JSON qw(to_json decode_json);
use LWP::UserAgent;
use SL::Dev::POS; # qw(build_tse_response build_tse_json_response); # TODO: remove once API works

sub start_tse_transaction {
  my ($data) = @_;

  my $tse_device = SL::DB::Manager::TSEDevice->get_first() // die "no TSEDevice found";
  my $transaction_number = 10000 + int(rand(10000));

  return {
    tse_device => $tse_device,
    transaction_number => $transaction_number
  }
}

sub finish_tse_transaction {
  my ($data) = @_;

  # TODO
  # my $ua = LWP::UserAgent->new;
  # ...

  # for now simulate TSE
  # TODO: process_data shouldn't come from SL::Dev::POS, but from API
  # $tse_device should initially come from start_transaction
  my $payments = $data->{payments};
  my $tse_device = $data->{tse_device} // SL::DB::Manager::TSEDevice->get_first() // die "no TSEDevice found";
  my $transaction_number = $data->{transaction_number} // (10000 + int(rand(10000)));

  my $process_data = SL::Dev::POS::build_process_data($payments);

  my $tse_data = {
    process_data => $process_data,
    transaction_number => $transaction_number,
  };
  my $tse_response = SL::Dev::POS::build_tse_response($tse_data);

  return $tse_response;
}

1;
