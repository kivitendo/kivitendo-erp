package SL::ShopConnector::Base;

use strict;

use parent qw(SL::DB::Object);
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(config) ],
);

sub get_one_order  { die 'get_one_order needs to be implemented' }

sub get_new_orders { die 'get_order needs to be implemented' }

sub update_part    { die 'update_part needs to be implemented' }

sub get_article    { die 'get_article needs to be implemented' }

sub get_categories { die 'get_categories needs to be implemented' }

sub get_version    {

  die 'get_version needs to be implemented';
  # has to return a hashref with this structure:
  # version has to return the connection error message
  my $connect = {};
  $connect->{success}         = 0 || 1;
  $connect->{data}->{version} = '1234';
  return $connect;
}

sub set_orderstatus { die 'set_orderstatus needs to be implemented' }

1;

__END__

=encoding utf-8

=head1 NAME

  SL::ShopConnectorBase - this is the base class for shop connectors

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AVAILABLE METHODS

=over 4

=item C<get_one_order>

=item C<get_new_orders>

=item C<update_part>

=item C<get_article>

=item C<get_categories>

=item C<get_version>

IMPORTANT: This call is used to test the connection and if succesful
it returns the version number of the shop. If not succesful the
returning function has to make sure a error string is returned in
the same data structure. Details of the returning hashref:

 my $connect = {};
 $connect->{success}         = 0 || 1;
 $connect->{data}->{version} = '1234';
 return $connect;

=item C<set_orderstatus>

=back

=head1 SEE ALSO

L<SL::ShopConnector::ALL>

=head1 BUGS

None yet. :)

=head1 AUTHOR

G. Richardson <lt>information@kivitendo-premium.deE<gt>
W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
