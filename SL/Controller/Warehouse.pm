package SL::Controller::Warehouse;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Warehouse;
use SL::Presenter::Tag qw(select_tag);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before(sub { $::auth->assert('developer') },
                        only => [ qw(test_page) ]);

#
# actions
#

sub action_test_page {
  $_[0]->render('warehouse/test_page');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::Warehouse->reorder_list(@{ $::form->{warehouse_id} || [] });

  $self->render(\'', { type => 'json' }); # make emacs happy again ')
}

sub action_wh_bin_select_update_bins {
  my ($self) = @_;

  my $wh_id      = $::form->{wh_id};
  my $bin_dom_id = $::form->{bin_dom_id} || 'bin';

  my $bins = $wh_id ? SL::DB::Warehouse->new(id => $wh_id)->load->bins_sorted_naturally
           : [{id => '', description => ''}];

  $self->js->run('kivi.Warehouse.wh_bin_select_update_bins', $bin_dom_id, [map { {key => $_->{id}, value => $_->{description}} } @$bins])
           ->render;
}


#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Warehouse - Controller module for warehouse and bin objects

=head1 FUNCTIONS

=over 4

=item C<action_test_page>

Renders the test page.

=item C<action_wh_bin_select_update_bins>

This action is used by the C<SL::Presenter::Warehouse::wh_bin_select>
to update the bin selection after the warehouse selection was changed.
See also L<SL::Presenter::Warehouse::wh_bin_select> and
L<js/kivi.Warehouse.js>).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
