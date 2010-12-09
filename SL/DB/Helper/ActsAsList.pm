package SL::DB::Helper::ActsAsList;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(move_position_up move_position_down);

use Carp;

sub import {
  my ($class, @params)   = @_;
  my $importing = caller();

  $importing->before_save(  sub { SL::DB::Helper::ActsAsList::set_position(@_)    });
  $importing->before_delete(sub { SL::DB::Helper::ActsAsList::remove_position(@_) });

  # Use 'goto' so that Exporter knows which module to import into via
  # 'caller()'.
  goto &Exporter::import;
}

#
# Exported functions
#

sub move_position_up {
  my ($self) = @_;
  do_move($self, 'up');
}

sub move_position_down {
  my ($self) = @_;
  do_move($self, 'down');
}

#
# Helper functions
#

sub set_position {
  my ($self) = @_;
  if (!defined $self->position) {
    my $max_position = $self->db->dbh->selectrow_arrayref(qq|SELECT COALESCE(max(position), 0) FROM | . $self->meta->table)->[0];
    $self->position($max_position + 1);
  }

  return 1;
}

sub remove_position {
  my ($self) = @_;

  $self->load;
  if (defined $self->position) {
    $self->_get_manager_class->update_all(set   => { position => \'position - 1' },
                                          where => [ position => { gt => $self->position } ]);
  }

  return 1;
}

sub do_move {
  my ($self, $direction) = @_;

  croak "Object has not been saved yet" unless $self->id;
  croak "No position set yet"           unless defined $self->position;

  my ($comp_sql, $comp_rdbo, $min_max, $plus_minus) = $direction eq 'up' ? ('<', 'ge', 'max', '+') : ('>', 'le', 'min', '-');

  my $new_position = $self->db->dbh->selectrow_arrayref(qq|SELECT ${min_max}(position) FROM | . $self->meta->table . qq| WHERE position ${comp_sql} | . $self->position)->[0];

  return undef unless defined $new_position;

  $self->_get_manager_class->update_all(set   => { position => $self->position },
                                        where => [ position => $new_position ]);
  $self->update_attributes(position => $new_position);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::ActsAsList - Mixin for managing ordered items by a column I<position>

=head1 SYNOPSIS

  package SL::DB::SomeObject;
  use SL::DB::Helper::ActsAsList;

  package SL::Controller::SomeController;
  ...
  # Assign a position automatically
  $obj = SL::DB::SomeObject->new(description => 'bla');
  $obj->save;

  # Move items up and down
  $obj = SL::DB::SomeOBject->new(id => 1)->load;
  $obj->move_position_up;
  $obj->move_position_down;

  # Adjust all remaining positions automatically
  $obj->delete

This mixin assumes that the mixing package's table contains a column
called C<position>. This column is set automatically upon saving the
object if it hasn't been set already. If it hasn't then it will be set
to the maximum position used in the table plus one.

When the object is deleted all positions greater than the object's old
position are decreased by one.

=head1 FUNCTIONS

=over 4

=item C<move_position_up>

Swaps the object with the object one step above the current one
regarding their sort order by exchanging their C<position> values.

=item C<move_position_down>

Swaps the object with the object one step below the current one
regarding their sort order by exchanging their C<position> values.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
