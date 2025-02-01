package SL::DB::Manager::Employee;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Employee' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  (
    default  => [ 'name', 1 ],
    columns  => {
      SIMPLE => 'ALL',
      map { +($_ => "lower(employee.$_)") } qw(deleted_email deleted_fax deleted_signature deleted_tel login name)
    },
  );
}

sub current {
  return undef unless $::myconfig{login};
  return $::request->cache('current')->{object} //= shift->find_by(login => $::myconfig{login});
}

sub update_entries_for_authorized_users {
  my ($class) = @_;

  my %employees_by_login = map { ($_->login => $_) } @{ $class->get_all };

  require SL::DB::AuthClient;
  no warnings 'once';

  foreach my $user (@{ SL::DB::AuthClient->new(id => $::auth->client->{id})->load->users || [] }) {
    my $user_config = $user->config_values;
    my $employee    = $employees_by_login{$user->login} || SL::DB::Employee->new(login => $user->login);

    $employee->update_attributes(
      name      => $user_config->{name},
      deleted   => 0,
    );
  }
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::Employee - RDBO manager for the C<employee> table

=head1 SYNOPSIS

  my $logged_in_employee = SL::DB::Manager::Employee->current;

=head1 FUNCTIONS

=over 4

=item C<current>

Returns an RDBO instance corresponding to the currently logged-in user.

=item C<update_entries_for_authorized_users>

For each user created by the administrator in the admin section an
entry only exists in the authentication table, but not in the employee
table. This is where this function comes in: It iterates over all
authentication users that have access to the current client and ensures
that an entry for them exists in the table C<employee>. The matching
is done via the login name which must be the same in both tables.

The only other properties that will be copied from the authentication
table into the C<employee> row are C<name>. In
addition C<deleted> is always set to 0.

The intention is that this function is called automatically during the
login process.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
