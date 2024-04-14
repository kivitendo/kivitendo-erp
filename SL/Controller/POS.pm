package SL::Controller::POS;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash flash_later);
use SL::HTML::Util;
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Locale::String qw(t8);

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(uniq any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;
use Sort::Naturally;

# show form pos
sub action_show_form {
  my ($self) = @_;
  $self->render(
    'pos/form',
    title => t8('POS'),
  );
}

sub setup_edit_action_bar {
  my ($self, %params) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('ACTION'),
        call      => [ 'kivi.POS.action', {
          action             => 'ACTION',
        }],
      ],
    );
  }
}
1;
