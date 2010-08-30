package SL::DB::Manager::PurchaseInvoice;

use strict;

use SL::DB::Helpers::Manager;
use base qw(SL::DB::Helpers::Manager);

sub object_class { 'SL::DB::PurchaseInvoice' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return (or  => [ invoice => 0, invoice => undef                       ]) if $type eq 'ap_transaction';
  return (and => [ invoice => 1, or => [ storno => 0, storno => undef ] ]) if $type eq 'invoice';
  return (and => [ invoice => 1,         storno => 1                    ]) if $type =~ m/(?:invoice_)?storno/;

  die "Unknown type $type";
}

1;
