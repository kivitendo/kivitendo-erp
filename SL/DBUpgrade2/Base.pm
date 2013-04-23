package SL::DBUpgrade2::Base;

use strict;

use parent qw(Rose::Object);

use English qw(-no_match_vars);
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(dbh myconfig) ],
);

use SL::DBUtils;

sub execute_script {
  my (%params) = @_;

  my $file_name = delete $params{file_name};

  if (!eval { require $file_name }) {
    delete $INC{$file_name};
    die $EVAL_ERROR;
  }

  my $package =  delete $params{tag};
  $package    =~ s/[^a-zA-Z0-9_]+/_/g;
  $package    =  "SL::DBUpgrade2::${package}";

  $package->new(%params)->run;
}

sub db_error {
  my ($self, $msg) = @_;

  die $self->locale->text("Database update error:") . "<br>$msg<br>" . $DBI::errstr;
}

sub db_query {
  my ($self, $query, $may_fail) = @_;

  return if $self->dbh->do($query);

  $self->db_error($query) unless $may_fail;

  $self->dbh->rollback;
  $self->dbh->begin_work;
}

sub check_coa {
  my ($self, $wanted_coa) = @_;

  my ($have_coa)          = selectrow_query($::form, $self->dbh, q{ SELECT count(*) FROM defaults WHERE coa = ? }, $wanted_coa);

  return $have_coa;
}

sub is_coa_empty {
  my ($self) = @_;

  my $query = q{ SELECT count(*)
                 FROM ar, ap, gl, invoice, acc_trans, customer, vendor, parts
               };
  my ($empty) = selectrow_query($::form, $self->dbh, $query);

  return !$empty;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DBUpgrade2::Base - Base class for Perl-based database upgrade files

=head1 OVERVIEW

Database scripts written in Perl must be derived from this class and
provide a method called C<run>.

The functions in this base class offer functionality for the upgrade
scripts.

=head1 PROPERTIES

The following properties (which can be accessed with
C<$self-E<gt>property_name>) are available to the database upgrade
script:

=over 4

=item C<dbh>

The database handle; an Instance of L<DBI>. It is connected, and a
transaction has been started right before the script (the method
L</run>)) was executed.

=item C<myconfig>

The stripped-down version of the C<%::myconfig> hash: this hash
reference only contains the database connection parameters applying to
the current database.

=back


=head1 FUNCTIONS

=over 4

=item C<check_coa $coa_name>

Returns trueish if the database uses the chart of accounts named
C<$coa_name>.

=item C<db_error $message>

Outputs an error message C<$message> to the user and aborts execution.

=item C<db_query $query, $may_fail>

Executes an SQL query. What the method does if the query fails depends
on C<$may_fail>. If it is falsish then the method will simply die
outputting the error message via L</db_error>. If C<$may_fail> is
trueish then the current transaction will be rolled back, a new one
will be started

=item C<execute_script>

Executes a named database upgrade script. This function is not
supposed to be called from an upgrade script. Instead, the upgrade
manager L<SL::DBUpgrade2> uses it in order to execute the actual
database upgrade scripts.

=item C<is_coa_empty>

Returns trueish if no transactions have been recorded in the table
C<acc_trans> yet.

=item C<run>

This method is the entry point for the actual upgrade. Each upgrade
script must provide this method.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
