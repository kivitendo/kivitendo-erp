package SL::Presenter::PartsGroup;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);
use SL::DB::PartsGroup;
use List::Util qw(any);

use Exporter qw(import);
our @EXPORT_OK = qw(partsgroup_picker);

use Carp;

sub partsgroup_picker {
  my ($name, $curr, %params) = @_;

  my $all = delete $params{objects} // SL::DB::Manager::PartsGroup->get_all;

  unshift @$all, $curr if $curr && !any { $_->id == $curr->id } @$all;

  select_tag($name, $all, %params, default_sub => sub { $curr && $_[0]->id == $curr->id }, title_key => 'partsgroup');
}

sub picker { goto &partsgroup_picker };

1;
