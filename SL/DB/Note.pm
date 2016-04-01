package SL::DB::Note;

use strict;

use Carp;

use SL::DB::MetaSetup::Note;


__PACKAGE__->meta->add_relationships(
  follow_up => {
    type         => 'one to one',
    class        => 'SL::DB::FollowUp',
    column_map   => { id => 'note_id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub trans_object {
  my $self = shift;

  croak "Method is not a setter" if @_;

  return undef if !$self->trans_id || !$self->trans_module;

  if ($self->trans_module eq 'fu') {
    require SL::DB::FollowUp;
    return SL::DB::Manager::FollowUp->find_by(id => $self->trans_id);
  }

  if ($self->trans_module eq 'ct') {
    require SL::DB::Customer;
    require SL::DB::Vendor;
    return SL::DB::Manager::Customer->find_by(id => $self->trans_id)
        || SL::DB::Manager::Vendor  ->find_by(id => $self->trans_id);
  }

  return undef;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Note - Notes

=head1 FUNCTIONS

=over 4

=item C<trans_object>

A note object is always attached to another database entity. Which one
is determined by the columns C<trans_module> and C<trans_id>. This
function looks at both, retrieves the corresponding object from the
database and returns it.

Currently the following three types are supported:

=over 2

=item * C<SL::DB::FollowUp> for C<trans_module == 'fu'>

=item * C<SL::DB::Customer> or C<SL::DB::Vendor> for C<trans_module ==
'ct'> (which class is used depends on the value of C<trans_id>;
customers are looked up first)

=back

The method returns C<undef> in three cases: if no C<trans_id> or no
C<trans_module> has been assigned yet; if C<trans_module> is unknown;
if the referenced object doesn't exist.

This method is a getter only, not a setter.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
