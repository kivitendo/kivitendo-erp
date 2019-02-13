package SL::DB::Project;

use strict;

use List::MoreUtils qw(any);

use SL::DB::MetaSetup::Project;
use SL::DB::Manager::Project;

use SL::DB::Helper::CustomVariables(
  module      => 'Projects',
  cvars_alias => 1,
);

__PACKAGE__->meta->add_relationship(
  employee_invoice_permissions  => {
    type       => 'many to many',
    map_class  => 'SL::DB::EmployeeProjectInvoices',
  },
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

sub displayable_name {
  my ($self) = @_;

  return join ' ', grep $_, $self->projectnumber, $self->description;
}

sub full_description {
  my ($self, %params) = @_;

  $params{style} ||= 'both';
  my $description;

  if ($params{style} =~ m/number/) {
    $description = $self->projectnumber;

  } elsif ($params{style} =~ m/description/) {
    $description = $self->description;

  } elsif (($params{style} =~ m/full/) && $self->customer) {
    $description = $self->projectnumber;
    if ($self->description && do { my $desc = quotemeta $self->description; $self->projectnumber !~ m/$desc/ }) {
      $description .= ' ' . $self->description;
    }

    $description = $self->customer->name . " (${description})";

  } else {
    $description = $self->projectnumber;
    if ($self->description && do { my $desc = quotemeta $self->description; $self->projectnumber !~ m/$desc/ }) {
      $description .= ' (' . $self->description . ')';
    }
  }

  return $description;
}

sub may_employee_view_project_invoices {
  my ($self, $employee) = @_;

  return undef if !$self->id;

  my $employee_id = ref($employee) ? $employee->id : $employee * 1;
  my $query       = <<EOSQL;
    SELECT project_id
    FROM employee_project_invoices
    WHERE (employee_id = ?)
      AND (project_id  = ?)
    LIMIT 1
EOSQL

  return !!$self->db->dbh->selectrow_arrayref($query, undef, $employee_id, $self->id)->[0];
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

=item C<displayable_name>

Returns a human-readable description of the project, consisting of projectnumber
and description.

=item C<full_description %params>

Returns a full description for the project which can consist of the
project number, its description or both. This is determined by the
parameter C<style> which defaults to C<both>:

=over 2

=item C<both>

Returns the project's number followed by its description in
parenthesis (e.g. "12345 (Secret Combinations)"). If the project's
description is already part of the project's number then it will not
be appended.

=item C<projectnumber> (or simply C<number>)

Returns only the project's number.

=item C<projectdescription> (or simply C<description>)

Returns only the project's description.

=item C<full>

Returns the customer name followed by the project number and project
description in parenthesis (e.g. "Evil Corp (12345 World
domination)"). If the project's description is already part of the
project's number then it will not be appended.

If this project isn't linked to a customer then the style C<both> is
used instead.

=back

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
