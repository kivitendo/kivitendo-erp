package SL::DB::Helpers::ALL;

use strict;

use SL::DB::Assembly;
use SL::DB::BankAccount;
use SL::DB::Bin;
use SL::DB::Buchungsgruppe;
use SL::DB::Business;
use SL::DB::Chart;
use SL::DB::Contact;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::CustomVariableValidity;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Draft;
use SL::DB::Dunning;
use SL::DB::DunningConfig;
use SL::DB::Employee;
use SL::DB::FollowUp;
use SL::DB::FollowUpLink;
use SL::DB::GLTransaction;
use SL::DB::GenericTranslation;
use SL::DB::History;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Language;
use SL::DB::Licemse;
use SL::DB::Note;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Part;
use SL::DB::PaymentTerm;
use SL::DB::PriceFactor;
use SL::DB::Pricegroup;
use SL::DB::Printer;
use SL::DB::Project;
use SL::DB::PurchaseInvoice;
use SL::DB::RMA;
use SL::DB::SepaExport;
use SL::DB::SepaExportItem;
use SL::DB::SchemaInfo;
use SL::DB::Shipto;
use SL::DB::Tax;
use SL::DB::Taxkey;
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
