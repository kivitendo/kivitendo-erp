package SL::Controller::PriceFactor;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PriceFactor;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  my @ids = @{ $::form->{price_factor_id} || [] };
  my $result = SL::DB::PriceFactor->new->db->do_transaction(sub {
    foreach my $idx (0 .. scalar(@ids) - 1) {
      SL::DB::PriceFactor->new(id => $ids[$idx])->load->update_attributes(sortkey => $idx + 1);
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
