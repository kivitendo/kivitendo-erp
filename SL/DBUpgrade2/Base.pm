package SL::DBUpgrade2::Base;

use strict;

use parent qw(Rose::Object);

use Carp;
use Encode;
use English qw(-no_match_vars);
use File::Basename ();
use File::Copy ();
use File::Path ();
use List::MoreUtils qw(uniq);
use SL::DBUtils qw(selectfirst_hashref_query);
use SL::Presenter::EscapedText qw(escape);
use version;

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

  my $auth    =  $file_name =~ m{/Pg-upgrade2-auth/} ? 'Auth::' : '';
  my $package =  delete $params{tag};
  $package    =~ s/[^a-zA-Z0-9_]+/_/g;
  $package    =  "SL::DBUpgrade2::${auth}${package}";

  $package->new(%params)->run;
}

sub db_error {
  my ($self, $msg) = @_;

  die $::locale->text("Database update error:") . "<br>$msg<br>" . $self->db_errstr('DBI');
}

sub db_query {
  my ($self, $query, %params) = @_;

  my $dbh = $params{dbh} || $self->dbh;

  return if $dbh->do($query, undef, @{ $params{bind} || [] });

  $self->db_error($query) unless $params{may_fail};

  $dbh->rollback;
  $dbh->begin_work;
}

sub db_errstr {
  my ($self, $handle) = @_;

  # DBD::Pg before 2.16.1 doesn't set the UTF-8 flag for error
  # messages even if the connection has UTF-8 enabled. Therefore we
  # have to convert it to Perl's internal encoding ourselves. See
  # https://rt.cpan.org/Public/Bug/Display.html?id=53854

  my $error = $handle ? $handle->errstr : $self->dbh->errstr;

  return $error if version->new("$DBD::Pg::VERSION")->numify >= version->new("2.16.1")->numify;
  return Encode::decode('utf-8', $error);
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

sub add_print_templates {
  my ($self, $src_dir, @files) = @_;

  $::lxdebug->message(LXDebug::DEBUG1(), "add_print_templates: src_dir $src_dir files " . join('  ', @files));

  foreach (@files) {
    croak "File '${src_dir}/$_' does not exist" unless -f "${src_dir}/$_";
  }

  # can't use Rose or InstanceConf here because defaults might not be fully upgraded yet.
  my $defaults = selectfirst_hashref_query($::form, $::form->get_standard_dbh, "SELECT * FROM defaults");
  return 1 unless my $template_dir = $defaults->{template};
  $::lxdebug->message(LXDebug::DEBUG1(), "add_print_templates: template_dir $template_dir");

  foreach my $src_file (@files) {
    my $dest_file = $template_dir . '/' . $src_file;

    if (-f $dest_file) {
      $::lxdebug->message(LXDebug::DEBUG1(), "add_print_templates: dest_file exists, skipping: ${dest_file}");
      next;
    }

    my $dest_dir = File::Basename::dirname($dest_file);

    if ($dest_dir && !-d $dest_dir) {
      File::Path::make_path($dest_dir) or die "Cannot create directory '${dest_dir}': $!";
    }

    File::Copy::copy($src_dir . '/' . $src_file, $dest_file) or die "Cannot copy '${src_dir}/${src_file}' to '${dest_file}': $!";

    $::lxdebug->message(LXDebug::DEBUG1(), "add_print_templates: copied '${src_dir}/${src_file}' to '${dest_file}'");
  }

  return 1;
}

sub drop_constraints {
  my ($self, %params) = @_;

  croak "Missing parameter 'table'" unless $params{table};
  $params{type}   ||= 'FOREIGN KEY';
  $params{schema} ||= 'public';

  my $constraints = $self->dbh->selectall_arrayref(<<SQL, undef, $params{type}, $params{schema}, $params{table});
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE (constraint_type = ?)
      AND (table_schema    = ?)
      AND (table_name      = ?)
SQL

  $self->db_query(qq|ALTER TABLE $params{schema}."$params{table}" DROP CONSTRAINT "${_}"|) for map { $_->[0] } @{ $constraints };
}

sub convert_column_to_html {
  my ($self, $table, $column) = @_;

  my $sth = $self->dbh->prepare(qq|UPDATE $table SET $column = ? WHERE id = ?|) || $self->dberror;

  foreach my $row (selectall_hashref_query($::form, $self->dbh, qq|SELECT id, $column FROM $table WHERE $column IS NOT NULL|)) {
    next if !$row->{$column} || (($row->{$column} =~ m{^<[a-z]+>}) && ($row->{$column} =~ m{</[a-z]+>$}));

    my $new_content = "" . escape($row->{$column});
    $new_content    =~ s{\r}{}g;
    $new_content    =~ s{\n\n+}{</p><p>}g;
    $new_content    =~ s{\n}{<br />}g;
    $new_content    =  "<p>${new_content}</p>" if $new_content;

    $sth->execute($new_content, $row->{id}) if $new_content ne $row->{$column};
  }

  $sth->finish;
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

=item C<add_print_templates $source_dir, @files>

Adds (copies) new print templates to existing users. All existing
users in the authentication database are read. The listed C<@files>
are copied to each user's configured templates directory preserving
sub-directory structure (non-existing sub-directories will be
created). If a template with the same name exists it will be skipped.

The source file names must all be relative to the source directory
C<$source_dir>. This way only the desired sub-directories are created
in the users' template directories. Example:

  $self->add_print_templates(
    'templates/print/Standard',
    qw(receipt.tex common.sty images/background.png)
  );

Let's assume a user's template directory is
C<templates/big-money-inc>. The call above would trigger five actions:

=over 2

=item 1. Create the directory C<templates/big-money-inc> if it doesn't
exist.

=item 2. Copy C<templates/print/Standard/receipt.tex> to
C<templates/big-money-inc/receipt.tex> if there's no such file in that
directory.

=item 3. Copy C<templates/print/Standard/common.sty> to
C<templates/big-money-inc/common.sty> if there's no such file in that
directory.

=item 4. Create the directory C<templates/big-money-inc/images> if it
doesn't exist.

=item 5. Copy C<templates/print/Standard/images/background.png> to
C<templates/big-money-inc/images/background.png> if there's no such
file in that directory.

=back

=item C<check_coa $coa_name>

Returns trueish if the database uses the chart of accounts named
C<$coa_name>.

=item C<db_error $message>

Outputs an error message C<$message> to the user and aborts execution.

=item C<db_query $query, %params>

Executes an SQL query. The following parameters are supported:

=over 2

=item C<may_fail>

What the method does if the query fails depends on this parameter. If
it is falsish (the default) then the method will simply die outputting
the error message via L</db_error>. If C<may_fail> is trueish then the
current transaction will be rolled back, a new one will be started.

=item C<bind>

An optional array reference containing bind parameter for the query.

=item C<dbh>

The database handle to use. If undefined then C<$self-E<gt>dbh> will
be used.

=back

=item C<db_errstr [$handle]>

Returns the last database from C<$handle> error message encoded in
Perl's internal encoding. The PostgreSQL DBD before 2.16.1 leaves the
UTF-8 flag off for error messages even if the C<pg_enable_utf8>
attribute is set. For older versions the error string is already
encoded correctly and is left unchanged.

C<$handle> is optional and can be one of three things:

=over 2

=item 1. A database or statement handle. In that case
C<$handle-E<gt>errstr> is used.

=item 2. The string 'DBI'. In that case C<$DBI::errstr> is used.

=item 3. If it is undefined then C<$self-E<gt>dbh-E<gt>errstr> is
used.

=back

=item C<drop_constraints %params>

Drops all constraints of a type (e.g. foreign keys) on a table. One
parameter is mandatory: C<table>. Optional parameters include:

=over 2

=item * C<schema> -- if missing defaults to C<public>

=item * C<type> -- if missing defaults to C<FOREIGN KEY>. Must be one of
the values contained in the C<information_schema.table_constraints>
view in the C<constraint_type> column.

=back

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

=item C<convert_column_to_html $table, $column>

Converts the content of a single column from text to HTML suitable for
use with the ckeditor.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
