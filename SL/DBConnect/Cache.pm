package SL::DBConnect::Cache;

use strict;
use List::MoreUtils qw(apply);

my %cache;

sub get {
  my ($package, @args) = @_;

  my $dbh = $cache{ _args2str(@args) };

  if (!$dbh->{Active}) {
    delete $cache{ _args2str(@args) };
    $dbh = undef;
  }

  return $dbh;
}

sub store {
  my ($package, $dbh, @args) = @_;

  $cache{ _args2str(@args) } = $dbh;
}

sub reset {
  my ($package, @args) = @_;

  my $dbh = $cache{ _args2str(@args) };

  return unless $dbh;

  $dbh->rollback;
  $dbh;
}

sub clear {
  %cache = ();
}

sub _args2str {
  my (@args) = @_;

  my ($dbconnect, $dbuser, $dbpasswd, $options) = @_;
  $dbconnect //= '';
  $dbuser    //= '';
  $dbpasswd  //= '';
  $options   //= {};
  my $options_str =
    join ';', apply { s/([;\\])/\\$1/g }  # no collisions if anything contains ;
    map { $_ => $options->{$_} }
    sort keys %$options;                  # deterministic order

  join ';', apply { s/([;\\])/\\$1/g } $dbconnect, $dbuser, $dbpasswd, $options_str;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DBConnect::Cache - cached database handle pool

=head1 SYNOPSIS

  use SL::SBConnect::Cache;

  my $dbh = SL::DBConnct::Cache->get(@args);
  SL::DBConnct::Cache->store($dbh, @args);

  # reset a cached handle
  SL::DBConnct::Cache->reset($dbh);

  # close a cached handle and forget it
  SL::DBConnct::Cache->close($dbh);

  SL::DBConnct::Cache->clear($dbh);


=head1 DESCRIPTION

Implementes a managed cache for DB connection handles.

The same would be possible with C<< DBI->connect_cached >>, but in that case,
we would have no control ver the cache.

=head1 METHODS

=over 4

=item * C<get ARGS>

Retrieve a connection specified by C<ARGS>.

=item * C<store DBH ARGS>

Store a connection specified by C<ARGS>.

=item * C<reset ARGS>

Rollback the connection specified by C<ARGS>.

=item * C<clear>

Emties the cache. If handles are not referenced otherwise, they will get
dropped and closed.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
