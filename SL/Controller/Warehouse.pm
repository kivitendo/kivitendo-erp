package SL::Controller::Warehouse;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Warehouse;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  my @ids = @{ $::form->{warehouse_id} || [] };
  my $result = SL::DB::Warehouse->new->db->do_transaction(sub {
    foreach my $idx (0 .. scalar(@ids) - 1) {
      SL::DB::Warehouse->new(id => $ids[$idx])->load->update_attributes(sortkey => $idx + 1);
    }
  });

  $self->render(type => 'js', inline => '1;');
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;
