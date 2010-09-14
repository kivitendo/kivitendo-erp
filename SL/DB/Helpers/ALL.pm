package SL::DB::Helpers::ALL;

use strict;

use SL::DB::AccTrans;
use SL::DB::AccTransaction;
use SL::DB::Assembly;
use SL::DB::AuditTrail;
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
use SL::DB::CustomerTax;
use SL::DB::Datev;
use SL::DB::Default;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Department;
use SL::DB::DptTrans;
use SL::DB::Draft;
use SL::DB::Dunning;
use SL::DB::DunningConfig;
use SL::DB::Employee;
use SL::DB::Exchangerate;
use SL::DB::Finanzamt;
use SL::DB::FollowUp;
use SL::DB::FollowUpAccess;
use SL::DB::FollowUpLink;
use SL::DB::GLTransaction;
use SL::DB::GenericTranslation;
use SL::DB::Gifi;
use SL::DB::History;
use SL::DB::Inventory;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Language;
use SL::DB::Lead;
use SL::DB::License;
use SL::DB::LicenseInvoice;
use SL::DB::MakeModel;
use SL::DB::Note;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Part;
use SL::DB::PartsGroup;
use SL::DB::PartsTax;
use SL::DB::PaymentTerm;
use SL::DB::PriceFactor;
use SL::DB::Pricegroup;
use SL::DB::Prices;
use SL::DB::Printer;
use SL::DB::Project;
use SL::DB::PurchaseInvoice;
use SL::DB::RMA;
use SL::DB::RMAItem;
use SL::DB::RecordLink;
use SL::DB::SchemaInfo;
use SL::DB::SepaExport;
use SL::DB::SepaExportItem;
use SL::DB::Shipto;
use SL::DB::Status;
use SL::DB::Tax;
use SL::DB::TaxKey;
use SL::DB::TaxZone;
use SL::DB::TodoUserConfig;
use SL::DB::TransferType;
use SL::DB::Translation;
use SL::DB::TranslationPaymentTerm;
use SL::DB::Unit;
use SL::DB::UnitsLanguage;
use SL::DB::Vendor;
use SL::DB::VendorTax;
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
