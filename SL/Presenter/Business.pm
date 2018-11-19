package SL::Presenter::Business;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);
use SL::DB::Business;

use Exporter qw(import);
our @EXPORT_OK = qw(business business_picker);

use Carp;

sub business {
  my ($business, %params) = @_;

  return '' unless $business;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $description = $business->full_description(style => $params{style});
  my $edit_url    = SL::Controller::Base->url_for(
    controller => 'SimpleSystemSetting',
    action     => 'edit',
    type       => 'business',
    id         => $business->id,
    callback   => $params{callback},
  );

  my $text = $params{no_link} || !$::auth->assert('config', 'dont abort')
      ? escape($description)
      : link_tag($edit_url, $description);

  is_escaped($text);
}

sub business_picker {
  my ($name, $value, %params) = @_;

  my $all = SL::DB::Manager::Business->get_all;
  $value  = SL::DB::Manager::Business->find_by(id => $value) if $value && !ref $value;

  select_tag($name, $all, selected => $value, title_key => 'description', %params);
}

sub picker { goto &business_picker };

1;
