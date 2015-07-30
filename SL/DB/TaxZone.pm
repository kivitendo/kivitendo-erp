# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::TaxZone;

use strict;

use SL::DB::MetaSetup::TaxZone;
use SL::DB::Manager::TaxZone;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
#__PACKAGE__->meta->make_manager_class;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.') if !$self->description;

  return @errors;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  my @classes = qw(Customer Vendor Invoice Order DeliveryOrder PurchaseInvoice);
  foreach my $class ( @classes ) {
    my $module = 'SL::DB::' . $class;
    eval "require $module";
    my $manager = 'SL::DB::Manager::' . $class;
    return 0 if $manager->get_all_count( query  => [ taxzone_id => $self->id ] );
  };
  return 1;
}

1;
