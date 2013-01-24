package SL::DB::Project;

use strict;

use List::MoreUtils qw(any);

use SL::DB::MetaSetup::Project;
use SL::DB::Manager::Project;

use SL::DB::Helper::CustomVariables(
  module      => 'Project',
  cvars_alias => 1,
);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The project number is missing.')        if !$self->projectnumber;
  push @errors, $::locale->text('The project number is already in use.') if !$self->is_projectnumber_unique;
  push @errors, $::locale->text('The description is missing.')           if !$self->description;

  return @errors;
}

sub is_used {
  my ($self) = @_;

  # Unsaved projects are never referenced.
  return 0 unless $self->id;

  return any {
    my $column = $SL::DB::Manager::Project::project_id_column_prefixes{$_} . 'project_id';
    $self->db->dbh->selectrow_arrayref(qq|SELECT EXISTS(SELECT * FROM ${_} WHERE ${column} = ?)|, undef, $self->id)->[0]
  } @SL::DB::Manager::Project::tables_with_project_id_cols;
}

sub is_projectnumber_unique {
  my ($self) = @_;

  return 1 unless $self->projectnumber;

  my @filter = (projectnumber => $self->projectnumber);
  @filter    = (and => [ @filter, '!id' => $self->id ]) if $self->id;

  return !SL::DB::Manager::Project->get_first(where => \@filter);
}

1;

__END__

=pod

=head1 NAME

SL::DB::Project: Model for the 'project' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 FUNCTIONS

=over 4

=item C<validate>

Checks whether or not all fields are set to valid values so that the
object can be saved. If valid returns an empty list. Returns an array
of translated error message otherwise.

=item C<is_used>

Checks whether or not the project is referenced from any other
database table. Returns a boolean value.

=item C<is_projectnumber_unique>

Returns trueish if the project number is not used for any other
project in the database. Also returns trueish if no project number has
been set yet.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
