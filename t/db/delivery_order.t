use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use Time::HiRes;

use SL::DB::Order;
use SL::DB::Customer;
use SL::DB::Department;
use SL::DB::Currency;
use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Employee;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types);

use SL::Controller::DeliveryOrder;

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();


#######

my $order1 = SL::Dev::Record::create_purchase_order(
  save                    => 1,
  taxincluded             => 0,
);

my $delivery_order = SL::DB::DeliveryOrder->new_from($order1);

is $delivery_order->type, PURCHASE_DELIVERY_ORDER_TYPE, "new_from purchase order gives purchase delivery order";
is scalar @{ $delivery_order->items }, 2, "purchase delivery order keeps items";
is $delivery_order->vendor_id, $order1->vendor_id, "purchase delivery order keeps vendor";

my $supplier_delivery_order = SL::DB::DeliveryOrder->new_from($order1, destination_type => SUPPLIER_DELIVERY_ORDER_TYPE);

is $supplier_delivery_order->type, SUPPLIER_DELIVERY_ORDER_TYPE, "new_from purchase order with given type gives supplier delivery order";
is scalar @{ $supplier_delivery_order->items }, 0, "supplier delivery order ignores items";
is $supplier_delivery_order->vendor_id, $order1->vendor_id, "supplier delivery order keeps vendor";


test_performance(400);
#my @timings;
#my $runtime;
#my $noitems;
#$noitems = 400;
#$runtime = clock (sub {test_performance($noitems);});
#push @timings, [$noitems, $runtime];
##$noitems = 4;
##$runtime = clock (sub {test_performance($noitems);});
##push @timings, [$noitems, $runtime];
#$main::lxdebug->dump(0, 'timings', @timings);
#
#sub clock (&) {
#  my $s = [Time::HiRes::gettimeofday()];
#  $_[0]->();
#  Time::HiRes::tv_interval($s);
#}


sub test_performance {
  my ($noitems) = shift;

  #my $template = 'templates/' . ( +{ SL::Template->available_templates }->{print_templates}[0] );
  #$main::lxdebug->dump(0, 'templates', +{ SL::Template->available_templates });
  #$main::lxdebug->dump(0, 'templates', $template);
  #my $defaults = SL::DB::Default->get;
  #$defaults->templates($template);
  #$defaults->save;
  #diag('tem ', $::instance_conf->get_templates);


  my @orderitems;
  for (1..$noitems) {
    my $part1 = SL::Dev::Part::new_part(partnumber => "T4254-$_")->save;
    push @orderitems, SL::Dev::Record::create_order_item(part => $part1, qty => 3, sellprice => 70);
  }

  my $order = SL::Dev::Record::create_sales_order(
      save         => 1,
      taxincluded  => 0,
      orderitems   => \@orderitems,
      );

  my $delivery_order = SL::DB::DeliveryOrder->new_from($order);
  $delivery_order->tax_point($delivery_order->transdate);
  $delivery_order->save;

#sleep(300);

  #$main::lxdebug->dump(0, 'do', $delivery_order);
  diag('donumber ', $delivery_order->donumber);

#$::form = Form->new('');
  $::form->{id} = $delivery_order->id;


  my $docontroller = SL::Controller::DeliveryOrder->new;
  $docontroller->load_order;
  my $pdf;

  my $tstart = [Time::HiRes::gettimeofday()];
  my @errors = SL::Controller::DeliveryOrder::generate_pdf($docontroller->order, \$pdf, {
      format => 'pdf',
      formname => 'sales_delivery_order',
      language => undef,
#printer_id => undef,
#groupitems => 0,
      });
  my $runtime = Time::HiRes::tv_interval($tstart);

  if (scalar @errors) {
    diag('Generating the document failed: ', $errors[0]);
  }
  #$main::lxdebug->dump(0, 'form', $::form);

  my $outfile = '/tmp/kivi-unittest-print.pdf';
  open my $out, '>', $outfile or die;
  print $out $pdf;
  close $out;

#sleep(900);

  open(MEAS, '>>', 'users/time-measurement-printing');
  print MEAS "$noitems $runtime\n";
  close(MEAS);
}




done_testing();
