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
use SL::Helper::ShippedQty;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(reclamation_id)]);

sub shipped_qty {
  my ($self, %params) = @_;

  my $force = delete $params{force};

  SL::Helper::ShippedQty->new(%params)->calculate($self)->write_to_objects if $force || !defined $self->{shipped_qty};

  $self->{shipped_qty};
}

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

sub delivered_qty { goto &shipped_qty }
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

=over 4

=item C<shipped_qty PARAMS>

Calculates the shipped qty for this reclamationitem (measured in the current unit)
and returns it.

Note that the shipped qty is expected not to change within the request and is
cached in C<shipped_qty> once calculated. If C<< force => 1 >> is passed, the
existibng cache is ignored.

Given parameters will be passed to L<SL::Helper::ShippedQty>, so you can force
the shipped/delivered distinction like this:

  $_->shipped_qty(require_stock_out => 0);

Note however that calculating shipped_qty on individual Reclamationitems is generally
a bad idea. See L<SL::Helper::ShippedQty> for way to compute these all at once.

=item C<delivered_qty>

Alias for L</shipped_qty>.

=back

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
