# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Shop;

use strict;

use SL::DB::MetaSetup::Shop;
use SL::DB::Manager::Shop;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String qw(t8);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  # critical checks
  push @errors, $::locale->text('The description is missing.') unless $self->{description};
  push @errors, $::locale->text('The path is missing.')        unless $self->{path};
  push @errors, $::locale->text('The Host Name is missing')    unless $self->{server};
  push @errors, $::locale->text('The Host Name seems invalid') unless $self->{server} =~ m/[0-9A-Za-z].\.[0-9A-Za-z]/;
  push @errors, $::locale->text('The Proxy Name seems invalid') unless $self->{proxy} =~ m/[0-9A-Za-z].\.[0-9A-Za-z]/;
  push @errors, $::locale->text('Orders to fetch neeeds a positive Integer')
                                                               unless $self->{orders_to_fetch} > 0;

  # not yet implemented checks
  push @errors, $::locale->text('Transaction Description is not yet implemented')    if $self->{transaction_description};
  if ($self->{connector} eq 'shopware6') {
    push @errors, $::locale->text('Shipping cost article is not implemented')        if $self->{shipping_costs_parts_id};
    push @errors, $::locale->text('Fetch from last order number is not implemented') if $self->{last_order_number};
  } else {
    push @errors, $::locale->text('Use Long Description from Parts is only for Shopware6 implemented')
      if $self->{use_part_longdescription};
  }
  return @errors;
}

sub shops_dd {
  my ( $self ) = @_;

  my @shops_dd = ( { title => t8("all") ,   value =>'' } );
  my $shops = SL::DB::Manager::Shop->get_all( where => [ obsolete => 0 ] );
  my @tmp = map { { title => $_->{description}, value => $_->{id} } } @{ $shops } ;
  push @shops_dd, @tmp;
  return \@shops_dd;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::Shop - Model for the 'shops' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<validate>

Returns an error if the shop description is missing

=item C<shops_dd>

Returns an array of hashes for dropdowns in filters

=back

=head1 AUTHORS

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
