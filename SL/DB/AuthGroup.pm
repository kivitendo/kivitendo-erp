package SL::DB::AuthGroup;

use strict;

use SL::DB::MetaSetup::AuthGroup;
use SL::DB::Manager::AuthGroup;
use SL::DB::Helper::Util;

__PACKAGE__->meta->add_relationship(
  users => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'group',
    map_to    => 'user',
  },
  rights => {
    type       => 'one to many',
    class      => 'SL::DB::AuthGroupRight',
    column_map => { id => 'group_id' },
  },
  clients => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthClientGroup',
    map_from  => 'group',
    map_to    => 'client',
  },
);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name is missing.')    if !$self->name;
  push @errors, $::locale->text('The name is not unique.') if !SL::DB::Helper::Util::is_unique($self, 'name');

  return @errors;
}

sub get_employees {
  my @logins = map { $_->login } $_[0]->users;
  return @logins ? @{ SL::DB::Manager::Employee->get_all(query => [ login => \@logins ]) } : ();
}

sub rights_map {
  my $self = shift;

  if (@_) {
    my %new_rights = ref($_[0]) eq 'HASH' ? %{ $_[0] } : @_;
    $self->rights([ map { SL::DB::AuthGroupRight->new(right => $_, granted => $new_rights{$_} ? 1 : 0) } SL::Auth::all_rights() ]);
  }

  return {
    map({ ($_        => 0)           } SL::Auth::all_rights()),
    map({ ($_->right => $_->granted) } @{ $self->rights || [] })
  };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::AuthGroup - RDBO model for auth.group

=head1 SYNOPSIS

  # Outputting all rights granted to this group:
  my $group  = SL::DB::Manager::AuthGroup->get_first;
  my %rights = %{ $group->rights_map };
  print "Granted rights:\n";
  print "  $_\n" for sort grep { $rights{$_} } keys %rights;

  # Set a right to 'yes':
  $group->rights_map(%{ $group->rights_map }, invoice_edit => 1);
  $group->save;

=head1 FUNCTIONS

=over 4

=item C<get_employees>

Returns all employees (as instances of L<SL::DB::Employee>) whose
corresponding logins are members in this group.

=item C<rights_map [$new_rights]>

Gets/sets the rights for this group as hashes. Returns a hash
references containing the right names as the keys and trueish/falsish
values for 'granted'/'not granted'.

If C<$new_rights> is given as a hash reference or a plain hash then it
will also set all rights from this hash.

=item C<validate>

Validates the object before saving (checks uniqueness, attribute
presence etc). Returns a list of human-readable errors and an empty
list on success.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
