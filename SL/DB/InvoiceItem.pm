package SL::DB::InvoiceItem;

use strict;

use SL::DB::MetaSetup::InvoiceItem;
use SL::DB::Manager::InvoiceItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'invoice',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
     class => 'SL::DB::Part',
     module => 'IC',
    },
  },
);
use Rose::DB::Object::Helpers qw(as_tree strip);

__PACKAGE__->configure_acts_as_list(group_by => [qw(trans_id)]);

__PACKAGE__->meta->add_relationships(
  invoice          => {
    type           => 'one to one',
    class          => 'SL::DB::Invoice',
    column_map     => { trans_id => 'id' },
  },

  purchase_invoice => {
    type           => 'one to one',
    class          => 'SL::DB::PurchaseInvoice',
    column_map     => { trans_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('longdescription');

__PACKAGE__->before_save('_before_save_set_tax_id');

sub _before_save_set_tax_id {
  my ($self) = @_;

  return 1 if defined $self->tax_id && $self->tax_id >= 0;

  my $record = $self->record;
  my $taxkey = $self->part->get_taxkey(date       => $record->effective_tax_point,
                                       is_sales   => $record->is_sales,
                                       taxzone_id => $record->taxzone_id);
  $self->tax_id($taxkey->tax_id);

  return 1;
}

sub record {
  my ($self) = @_;

  return $self->invoice          if $self->invoice;
  return $self->purchase_invoice if $self->purchase_invoice;
  return;
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SL::DB::InvoiceItem: Rose model for invoices items (table "invoice")

=head1 HOOKS

=over 4

=item C<_before_save_set_tax_id>

This before-save-hook sets the tax_id for the itemif it is not already set.

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

...

=cut
