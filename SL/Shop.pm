package SL::Shop;

use strict;

use parent qw(Rose::Object);
use SL::ShopConnector::ALL;
use SL::DB::Part;

use Rose::Object::MakeMethods::Generic (
  'scalar'                => [ qw(config) ],
  'scalar --get_set_init' => [ qw(connector) ],
);

sub updatable_parts {
  my ($self, $last_update) = @_;
  $last_update ||= DateTime->now(); # need exact timestamp, with minutes

  my $parts;
  my $active_shops = SL::DB::Manager::Shop->get_all(query => [ obsolete => 0 ]);
  foreach my $shop ( @{ $active_shops } ) {
    # maybe run as an iterator? does that make sense with with_objects?
    my $update_parts = SL::DB::Manager::ShopPart->get_all(query => [
             and => [
                'active' => 1,
                'shop_id' => $shop->id,
                # shop => '1',
                or => [ 'part.mtime' => { ge => $last_update },
                        'part.itime' => { ge => $last_update },
                        'itime'      => { ge => $last_update },
                        'mtime'      => { ge => $last_update },
                      ],
                    ]
             ],
             with_objects => ['shop', 'part'],
             # multi_many_ok   => 1,
          );
    push( @{ $parts }, @{ $update_parts });
  };
  return $parts;

};

sub check_connectivity {
  my ($self) = @_;
  my $version = $self->connector->get_version;
  return $version;
}

sub init_connector {
  my ($self) = @_;
  # determine the connector from the connector type in the webshop config
  return SL::ShopConnector::ALL->shop_connector_class_by_name($self->config->connector)->new( config => $self->config);

};

1;

__END__

=encoding utf8

=head1 NAME

SL::Shop - Do stuff with WebShop instances

=head1 SYNOPSIS

my $config = SL::DB::Manager::Shop->get_first();
my $shop = SL::Shop->new( config => $config );

From the config we know which Connector class to load, save in $shop->connector
and do stuff from there:

$shop->connector->get_new_orders;

=head1 FUNCTIONS

=over 4

=item C<updatable_parts>

=item C<check_connectivity>

=item C<init_connector>

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson <lt>information@kivitendo-premium.deE<gt>

=cut
