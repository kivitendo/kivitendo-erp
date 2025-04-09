package SL::Presenter::PartsGroup;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);
use SL::DB::PartsGroup;
use List::Util qw(any);

use Exporter qw(import);
our @EXPORT_OK = qw(partsgroup partsgroup_picker);

use Carp;

sub partsgroup_picker {
  my ($name, $curr, %params) = @_;

  my $all = delete $params{objects} // SL::DB::Manager::PartsGroup->get_all;
  unshift @$all, $curr if $curr && !any { $_->id == $curr } @$all;

  select_tag($name, $all, %params, default_sub => sub { $curr && $_[0]->id == $curr }, title_key => 'partsgroup');
}

sub partsgroup {
  my ($partsgroup, %params) = @_;

  return '' unless $partsgroup;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $description = $partsgroup->partsgroup;
  my $edit_url    = SL::Controller::Base->url_for(
    controller => 'SimpleSystemSetting',
    action     => 'edit',
    type       => 'parts_group',
    id         => $partsgroup->id,
    callback   => $params{callback},
  );

  my $text = $params{no_link} || !$::auth->assert('config', 'dont abort')
      ? escape($description)
      : link_tag($edit_url, $description);

  is_escaped($text);
}

sub picker { goto &partsgroup_picker };

1;
