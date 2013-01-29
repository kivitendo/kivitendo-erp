package SL::Presenter::Project;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(project);

use Carp;

sub project {
  my ($self, $project, %params) = @_;

  return '' unless $project;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  $params{style} ||= 'both';
  my $description;

  if ($params{style} =~ m/number/) {
    $description = $project->projectnumber;

  } elsif ($params{style} =~ m/description/) {
    $description = $project->description;

  } else {
    $description = $project->projectnumber;
    if ($project->description && do { my $desc = quotemeta $project->description; $project->projectnumber !~ m/$desc/ }) {
      $description .= ' (' . $project->description . ')';
    }
  }

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=Project/edit&amp;id=' . $self->escape($project->id) . '">',
    $self->escape($description),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Project - Presenter module for project Rose::DB objects

=head1 SYNOPSIS

  my $project = SL::DB::Manager::Project->get_first;
  my $html    = SL::Presenter->get->project($project, display => 'inline');

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
