package SL::DB::Shipto;

use strict;

use Carp;
use List::MoreUtils qw(all);

use SL::Util qw(trim);

use SL::DB::MetaSetup::Shipto;
use SL::DB::Manager::Shipto;
use SL::DB::Helper::CustomVariables (
  module      => 'ShipTo',
  cvars_alias => 1,
);

our @SHIPTO_VARIABLES = qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptogln shiptocontact
                           shiptophone shiptofax shiptoemail shiptodepartment_1 shiptodepartment_2);

__PACKAGE__->meta->initialize;


sub displayable_id {
  my $self = shift;
  my $text = join('; ', grep { $_ } (map({ $self->$_ } qw(shiptoname shiptostreet shiptodepartment_1 shiptodepartment_2)),
                                     join(' ', grep { $_ }
                                               map  { $self->$_ }
                                               qw(shiptozipcode shiptocity))));

  return $text;
}

sub used {
  my ($self) = @_;

  return unless $self->shipto_id;

  require SL::DB::Order;
  require SL::DB::Invoice;
  require SL::DB::DeliveryOrder;

  return SL::DB::Manager::Order->get_all_count(query => [ shipto_id => $self->shipto_id ])
      || SL::DB::Manager::Invoice->get_all_count(query => [ shipto_id => $self->shipto_id ])
      || SL::DB::Manager::DeliveryOrder->get_all_count(query => [ shipto_id => $self->shipto_id ]);
}

sub is_empty {
  my ($self) = @_;

  # todo: consider cvars
  my @fields_to_consider = grep { !m{^ (?: itime | mtime | shipto_id | trans_id | shiptocp_gender | module ) $}x } map {$_->name} $self->meta->columns;

  return all { (trim($self->$_)||'') eq '' } @fields_to_consider;
}

sub detach {
  $_[0]->trans_id(undef);
  $_[0];
}

sub clone {
  my ($self, $target) = @_;

  my $type   = ref($target) || $target;
  my $module = $type =~ m{::Order$}               ? 'OE'
             : $type =~ m{::DeliveryOrder$}       ? 'DO'
             : $type =~ m{::Invoice$}             ? 'AR'
             : $type =~ m{::Reclamation$}         ? 'RC'
             : $type =~ m{::(?:Customer|Vendor)$} ? 'CT'
             :                                      croak "Unsupported target class '$type'";

  my $new_shipto = SL::DB::Shipto->new(
    (map  { +($_ => $self->$_) }
     grep { !m{^ (?: itime | mtime | shipto_id | trans_id ) $}x }
     map  { $_->name }
     @{ $self->meta->columns }),
    module           => $module,
    custom_variables => [ map { $_->clone_and_reset } @{ $self->custom_variables } ],
  );

  return $new_shipto;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Shipto - Database model for shipping addresses

=head1 SYNOPSIS

  my $order = SL::DB::Order->new(id => …)->load;
  if ($order->custom_shipto) {
    my $cloned_shipto = $order->custom_shipto->clone('SL::DB::Invoice');
  }

=head1 FUNCTIONS

=over 4

=item C<is_empty>

Returns truish if all fields to consider are empty, falsish if not.
Fields are trimmed before the test is performed.
C<shiptocp_gender> is not considered because in forms this is usually
a selection with 'm' as default value.
CVar fields are not considered by now.

=back

=over 4

=item C<clone $target>

Creates and returns a clone of the current object. The mandatory
parameter C<$target> must be either an instance of a Rose DB class or
the name of one. It's used for setting the new instance's C<module>
attribute to the correct value.

Currently the following classes are supported:

=over 2

=item C<SL::DB::Order>

=item C<SL::DB::DeliveryOrder>

=item C<SL::DB::Invoice>

=item C<SL::DB::Customer>

=item C<SL::DB::Vendor>

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
