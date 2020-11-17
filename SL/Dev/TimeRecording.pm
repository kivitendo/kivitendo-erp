package SL::Dev::TimeRecording;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(new_time_recording);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use DateTime;

use SL::DB::TimeRecording;

use SL::DB::Employee;
use SL::Dev::CustomerVendor qw(new_customer);


sub new_time_recording {
  my (%params) = @_;

  my $customer = delete $params{customer} // new_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless defined $customer && ref($customer) eq 'SL::DB::Customer';

  my $employee     = $params{employee}     // SL::DB::Manager::Employee->current;
  my $staff_member = $params{staff_member} // $employee;

  my $now = DateTime->now_local;

  my $time_recording = SL::DB::TimeRecording->new(
    start_time   => $now,
    end_time     => $now->add(hours => 1),
    customer     => $customer,
    description  => '<p>this and that</p>',
    staff_member => $staff_member,
    employee     => $employee,
    %params,
  );

  return $time_recording;
}


1;
