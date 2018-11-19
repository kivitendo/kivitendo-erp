package SL::Presenter::Pricegroup;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);
use SL::DB::Pricegroup;

use Exporter qw(import);
our @EXPORT_OK = qw(pricegroup pricegroup_picker);

use Carp;

sub pricegroup {
  my ($pricegroup, %params) = @_;

  return '' unless $pricegroup;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $description = $pricegroup->pricegroup;
  my $edit_url    = SL::Controller::Base->url_for(
    controller => 'SimpleSystemSetting',
    action     => 'edit',
    type       => 'pricegroup',
    id         => $pricegroup->id,
    callback   => $params{callback},
  );

  my $text = $params{no_link} || !$::auth->assert('config', 'dont abort')
      ? escape($description)
      : link_tag($edit_url, $description);

  is_escaped($text);
}

sub pricegroup_picker {
  my ($name, $value, %params) = @_;

  my $all = SL::DB::Manager::Pricegroup->get_all;
  $value  = SL::DB::Manager::Pricegroup->find_by(id => $value) if $value && !ref $value;

  select_tag($name, $all, selected => $value, title_key => 'pricegroup', %params);
}

sub picker { goto &pricegroup_picker };

1;
