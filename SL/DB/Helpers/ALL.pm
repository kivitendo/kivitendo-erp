package SL::DB::Helpers::ALL;

use strict;

use SL::DB::Assembly;
use SL::DB::Bin;
use SL::DB::Business;
use SL::DB::Chart;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::GLTransaction;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Part;
use SL::DB::PriceFactor;
use SL::DB::Printer;
use SL::DB::Project;
use SL::DB::PurchaseInvoice;
use SL::DB::Shipto;
use SL::DB::TransferType;
use SL::DB::Unit;
use SL::DB::Vendor;
use SL::DB::Warehouse;

1;

__END__

=pod

=head1 NAME

SL::DB::Helpers::ALL: Dependency-only package for all SL::DB::* modules

=head1 SYNOPSIS

  use SL::DB::Helpers::ALL;

=head1 DESCRIPTION

This module depends on all modules in SL/DB/*.pm for the convenience
of being able to write a simple \C<use SL::DB::Helpers::ALL> and
having everything loaded. This is supposed to be used only in the
Lx-Office console. Normal modules should C<use> only the modules they
actually need.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
