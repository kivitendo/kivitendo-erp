package SL::BackgroundJob::KIXSetTicketState;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Order;
use SL::KIX18Client qw(:all);


sub run {
  my ($self, $db_obj)     = @_;
  my $data       = $db_obj->data_as_hash;

  my $dry_run         = ($data->{dry_run}) ? 1 : 0;
  my $closed_state_id = $data->{closed_state_id} || 4;

  my $open_ticket_id   = SL::DB::Manager::OrderStatus->find_by(name => 'Ticket offen')->id;
  my $closed_ticket_id = SL::DB::Manager::OrderStatus->find_by(name => 'Ticket erledigt')->id;

  my $orders = SL::DB::Manager::Order->get_all(query => [ order_status_id   => $open_ticket_id,
                                                          record_type       => 'sales_order',
                                                         '!ticket_id'       => undef            ]);

  my $c = SL::KIX18Client->new();

  my @ord;
  foreach my $order (@{ $orders }) {
    next unless $order->ticket_id;

    my $ticket = $c->get_ticket(ticket_id => $order->ticket_id);

    if ($ticket->{Ticket}{StateID} == $closed_state_id)  {
      push @ord, $order->ordnumber;

      next if $dry_run;
      $order->order_status_id($closed_ticket_id);
      $order->save;
    }
  }
  return "Ticket-Status auf erledigt gesetzt bei:" . join (', ', @ord) . ($dry_run ? " TESTLAUF noch nicht getan" : " getan");
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::KIXSetTicketState
Background job for state updates of all sales orders who have ticket_id.
Data Options include dry_run and closed_state_id which defaults to 4:

 dry_run: 0
 closed_state_id: 4

=head1 SYNOPSIS

=head1 AUTHOR

Jan Büren

=cut
