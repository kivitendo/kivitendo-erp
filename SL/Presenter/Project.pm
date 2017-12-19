package SL::Presenter::Project;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(project project_picker);

use Carp;

sub project {
  my ($project, %params) = @_;

  return '' unless $project;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $description = $project->full_description(style => $params{style});
  my $callback    = $params{callback} ? '&callback=' . $::form->escape($params{callback}) : '';

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=Project/edit&amp;id=' . escape($project->id) . $callback . '">',
    escape($description),
    $params{no_link} ? '' : '</a>',
  );
  is_escaped($text);
}

sub project_picker {
  my ($name, $value, %params) = @_;

  $value      = SL::DB::Manager::Project->find_by(id => $value) if $value && !ref $value;
  my $id      = delete($params{id}) || name_to_id($name);
  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'project_autocomplete';

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id) .
    join('', map { $params{$_} ? input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(customer_id)) .
    input_tag("", ref $value ? $value->displayable_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('autocomplete_project.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'project_picker');
}

sub picker { goto &project_picker };

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Project - Presenter module for project Rose::DB objects

=head1 SYNOPSIS

  my $project = SL::DB::Manager::Project->get_first;
  my $html    = SL::Presenter::Project->project($project, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<project $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the project object C<$customer>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the project's description
(controlled by the C<style> parameter) linked to the corresponding
'edit' action.

=item * style

Determines what exactly will be output. Can be one of the values with
C<both> being the default if it is missing:

=over 2

=item C<projectnumber> (or simply C<number>)

Outputs only the project's number.

=item C<projectdescription> (or simply C<description>)

Outputs only the project's description.

=item C<both>

Outputs the project's number followed by its description in
parenthesis (e.g. "12345 (Secret Combinations)"). If the project's
description is already part of the project's number then it will not
be appended.

=back

=item * no_link

If falsish (the default) then the project's description will be linked to
the "edit project" dialog from the master data menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
