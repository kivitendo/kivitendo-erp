package SL::Controller::OrderItem;

use strict;

use parent qw(SL::Controller::Base);
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Customer;
use SL::DB::Part;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ParseFilter;
use SL::Locale::String qw(t8);

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  'scalar'                => [ qw(orderitems) ],
  'scalar --get_set_init' => [ qw(model) ],
);

my %sort_columns = (
  partnumber        => t8('Part Number'),
  ordnumber         => t8('Order'),
  customer          => t8('Customer'),
  transdate         => t8('Date'),
);

sub action_search {

  my ($self, %params) = @_;

  my $title = t8("Sold order items");

  $::request->layout->use_javascript('client_js.js');

  # The actual loading of orderitems happens in action_order_item_list_dynamic_table
  # which is processed inside this template and automatically called upon
  # loading. This causes all filtered orderitems to be displayed,
  # there is no paginate mechanism or export
  $self->render('order_items_search/order_items', { layout => 1, process => 1 },
                                                  title         => $title,
               );
}


sub action_order_item_list_dynamic_table {
  my ($self) = @_;

  $self->orderitems( $self->model->get );


  $self->add_linked_delivery_order_items;

  $self->render('order_items_search/_order_item_list', { layout  => 0 , process => 1 });
}

sub add_linked_delivery_order_items {
  my ($self) = @_;

  my $qty_round = 2;

  foreach my $orderitem ( @{ $self->orderitems } ) {
    my $dois = $orderitem->linked_delivery_order_items;
    $orderitem->{deliveryorders} = join('<br>', map { $_->displayable_delivery_order_info($qty_round) } @{$dois});
  };
};

sub init_model {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'OrderItem',
    query      => [ SL::DB::Manager::Order->type_filter('sales_order') ],
    sorted       => {
      _default     => {
        by           => 'transdate',
        dir          => 0,
      },
      %sort_columns,
    } ,
    with_objects    => [ 'order', 'order.customer', 'part' ],
  );
}

sub check_auth {
  $::auth->assert('sales_order_item_search');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::OrderItem - Controller for OrderItems

=head2 OVERVIEW

Controller for quickly finding orderitems in sales orders. For example the
customer phones you, saying he would like to order another one of the green
thingies he ordered 2 years ago. You have no idea what he is referring to, but
you can quickly filter by customer (a customerpicker) and e.g. part description
or partnumber or order date, successively narrowing down the search. The
resulting list is updated dynamically after keypresses.

=head1 Usage

Certain fields can be preset by passing them as get parameters in the URL, so
you could create links to this report:

 controller.pl?action=OrderItem/search&ordnumber=24
 controller.pl?action=OrderItem/search&customer_id=3455

=head1 TODO AND CAVEATS

=over 4

=item * amount of results is limited

=back

=cut
