package SL::ShopConnector::Base;

use strict;

use parent qw(SL::DB::Object);
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(config) ],
);

sub get_order      { die 'get_order needs to be implemented' }

sub get_new_orders { die 'get_order needs to be implemented' }

sub update_part    { die 'update_part needs to be implemented' }

sub get_article    { die 'get_article needs to be implemented' }

sub get_categories { die 'get_order needs to be implemented' }

sub get_version    { die 'get_order needs to be implemented' }

1;

__END__

=encoding utf-8

=head1 NAME

  SL::ShopConnectorBase - this is the base class for shop connectors

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AVAILABLE METHODS

=over 4

=item C<get_order>

=item C<get_new_orders>

=item C<update_part>

=item C<get_article>

=item C<get_categories>

=item C<get_version>

=back

=head1 SEE ALSO

L<SL::ShopConnector::ALL>

=head1 BUGS

None yet. :)

=head1 AUTHOR

G. Richardson <lt>information@kivitendo-premium.deE<gt>
W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
