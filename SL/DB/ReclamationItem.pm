package SL::DB::ReclamationItem;

use utf8;
use strict;

use List::MoreUtils qw(any);

use SL::DB::MetaSetup::ReclamationItem;
use SL::DB::Manager::ReclamationItem;
use SL::DB::ReclamationReason;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'reclamation_items',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
      class => 'SL::DB::Part',
      module => 'IC',
    }
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(reclamation_id)]);

sub is_linked_to_record {
  my ($self) = @_;

  if(scalar(@{$self->linked_records}) || $self->{converted_from_record_item_type_ref}) {
    return 1;
  }

  return 0;
}

#TODO(Werner): überprüfen ob alle Felder richtig gestetzt werden
sub new_from {
  my ($class, $source, $parent_type, %params) = @_;
  unless (any {ref($source) eq $_}
    qw(
      SL::DB::ReclamationItem
      SL::DB::OrderItem
      SL::DB::DeliveryOrderItem
      SL::DB::InvoiceItem
    )
  ) {
    croak("Unsupported source object type '" . ref($source) . "'");
  }
  my @custom_variables = map { _clone_cvar_for_reclamation_item($_) } @{ $source->custom_variables };


  my %item_args;
  if (ref($source) eq 'SL::DB::ReclamationItem') {
    map { $item_args{$_} = $source->$_ } qw(
      active_discount_source active_price_source base_qty description discount
      lastcost longdescription parts_id position price_factor price_factor_id
      pricegroup_id project_id qty reason_description_ext reason_description_int
      reason_id reqdate sellprice serialnumber
      unit
    );
    $item_args{custom_variables} = \@custom_variables;
  } elsif (ref($source) eq 'SL::DB::OrderItem') {
    map { $item_args{$_} = $source->$_ } qw(
      active_discount_source active_price_source base_qty description discount
      lastcost longdescription parts_id position price_factor price_factor_id
      pricegroup_id project_id qty reqdate sellprice serialnumber unit
    );
    $item_args{custom_variables} = \@custom_variables;
  } elsif (ref($source) eq 'SL::DB::DeliveryOrderItem') {
    map { $item_args{$_} = $source->$_ } qw(
      active_discount_source active_price_source base_qty description discount
      lastcost longdescription parts_id position price_factor price_factor_id
      pricegroup_id project_id qty reqdate sellprice serialnumber unit
    );
    $item_args{custom_variables} = \@custom_variables;
  } elsif (ref($source) eq 'SL::DB::InvoiceItem') {
    map { $item_args{$_} = $source->$_ } qw(
      active_discount_source active_price_source base_qty description discount
      lastcost longdescription parts_id position price_factor price_factor_id
      pricegroup_id project_id qty sellprice serialnumber unit
    );
    $item_args{custom_variables} = \@custom_variables;
  }

  my $item = $class->new(%item_args);

  if ( $source->record->is_sales() && ($parent_type =~ m{sales}) ) {
    $item->sellprice($source->lastcost);
    $item->discount(0);
  }
  if ( !$source->record->is_sales() && ($parent_type =~ m{purchase}) ) {
    $item->lastcost($source->sellprice);
  }

  $item->assign_attributes(%{ $params{attributes} }) if $params{attributes};

  unless ($params{no_linked_records}) {
    $item->{"converted_from_record_item_type_ref"} = ref($source);
    $item->{"converted_from_record_item_id"} = $source->id;
  }

  return $item;
}

sub _clone_cvar_for_reclamation_item {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('reclamation_items');

  return $cloned;
}

sub customervendor {
  my ($self) = @_;

  return $self->reclamation->customervendor;
}

sub record { goto &reclamation }
sub record_id { goto &reclamation_id }
sub trans_id { goto &reclamation_id }
sub date { goto &reqdate }

1;

__END__

=pod

=head1 NAME

SL::DB::ReclamationItems: Rose model for reclamationitems

=head1 FUNCTIONS

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
