package SL::Helper::KIX18;

use strict;
use warnings;

use SL::KIX18Client;
use SL::Locale::String qw(t8);
use SL::Helper::Flash qw(flash_later);

use Try::Tiny;


use Exporter 'import';
our @EXPORT_OK   = qw(create_kix18_ticket create_kix18_article);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);


sub create_kix18_ticket {
  my ($self) = @_;
  my %params = @_;

  die "Need a valid order object!" unless ref $params{order} eq 'SL::DB::Order';
  my $order = delete $params{order};
  try {
    # create new ticket
    my $customer_name = $order->customer->name;
    my $title = t8("Order for #1", $customer_name);
    $order->{kix18_client} //= SL::KIX18Client->new();
    my $id     = $order->{kix18_client}->create_ticket(Title => $title);
    my $ticket = $order->{kix18_client}->get_ticket(ticket_id => $id);
    die "Invalid ticket number" unless $ticket->{Ticket}{TicketNumber};

    $order->transaction_description($ticket->{Ticket}{TicketNumber});
    $order->ticket_id($id);
    $order->order_status_id(SL::DB::Manager::OrderStatus->find_by(name => 'Ticket offen')->id);

    flash_later('info', t8("Ticket with ID #1 created.", $ticket->{Ticket}{TicketNumber}));

  } catch { die t8("Communication error KIX18: #1", $_ ) };
}

sub create_kix18_article {
  my ($self) = @_;
  my %params = @_;

  die "Need a valid order object!" unless ref $params{order} eq 'SL::DB::Order';
  my $order = delete $params{order};
  my $customer_name = $order->customer->name;
  my $title = t8("Order for #1", $customer_name);
  my $note  = '<b>' . t8("Details:") . '</b>' . "<br>";
  foreach my $item (@{ $order->items }) {
    $title .= " " . $item->description;
    $note  .= $item->qty . " " . $item->unit . " " . $item->description . "<br>";
  }
  if ($::lx_office_conf{kix18}->{kivi_order_url}) {
    my $id = $order->id;
    my $link = $::lx_office_conf{kix18}->{kivi_order_url} =~ s/<%order_id%>/$id/r;
    $note .= t8('kivitendo Sales Order') . ': <a href="' . $link . '">' . $order->ordnumber . '</a>';
  }
  try {
    # create article for Ticket
    $order->{kix18_client} //= SL::KIX18Client->new();
    $order->{kix18_client}->create_article(Subject => $title, Body => $note, TicketID => $order->ticket_id);

  } catch { die t8("Communication error KIX18: #1", $_ ) };
}

1;


