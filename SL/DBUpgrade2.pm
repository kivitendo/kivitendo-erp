package SL::DBUpgrade2;

use English qw(-no_match_vars);
use IO::File;
use List::MoreUtils qw(any);

use SL::Common;
use SL::DBUpgrade2::Base;
use SL::DBUtils;
use SL::System::Process;

use strict;

sub new {
  my $package = shift;

  return bless({}, $package)->init(@_);
}

sub init {
  my ($self, %params) = @_;

  if ($params{auth}) {
    $params{path_suffix} = "-auth";
    $params{schema}      = "auth.";
  }

  $params{path_suffix} ||= '';
  $params{schema}      ||= '';
  $params{path}        ||= SL::System::Process->exe_dir . "/sql/Pg-upgrade2" . $params{path_suffix};

  map { $self->{$_} = $params{$_} } keys %params;

  return $self;
}

sub path {
  $_[0]{path};
}

sub parse_dbupdate_controls {
  my ($self) = @_;

  my $form   = $self->{form};
  my $locale = $::locale;

  local *IN;
  my %all_controls;

  my $path = $self->path;

  foreach my $file_name (<$path/*.sql>, <$path/*.pl>) {
    next unless (open(IN, "<:encoding(UTF-8)", $file_name));

    my $file = $file_name;
    $file =~ s|.*/||;

    my $control = {
      "priority" => 1000,
      "depends"  => [],
      "locales"  => [],
    };

    while (<IN>) {
      chomp();
      next unless (/^(--|\#)\s*\@/);
      s/^(--|\#)\s*\@//;
      s/\s*$//;
      next if ($_ eq "");

      my @fields = split(/\s*:\s*/, $_, 2);
      next unless (scalar(@fields) == 2);

      if ($fields[0] eq "depends") {
        push(@{$control->{"depends"}}, split(/\s+/, $fields[1]));
      } elsif ($fields[0] eq "locales") {
        push @{$control->{locales}}, $fields[1];
      } else {
        $control->{$fields[0]} = $fields[1];
      }
    }

    next if ($control->{ignore});

    if (!$control->{"tag"}) {
      _control_error($form, $file_name, $locale->text("Missing 'tag' field.")) ;
    }

    if ($control->{"tag"} =~ /[^a-zA-Z0-9_\(\)\-]/) {
      _control_error($form, $file_name, $locale->text("The 'tag' field must only consist of alphanumeric characters or the carachters - _ ( )"))
    }

    if (defined($all_controls{$control->{"tag"}})) {
      _control_error($form, $file_name, sprintf($locale->text("More than one control file with the tag '%s' exist."), $control->{"tag"}))
    }

    if (!$control->{"description"}) {
      _control_error($form, $file_name, sprintf($locale->text("Missing 'description' field."))) ;
    }

    delete @{$control}{qw(depth applied)};

    my @unknown_keys = grep { !m{^ (?: depends | description | file | ignore | locales | may_fail | priority | superuser_privileges | tag ) $}x } keys %{ $control };
    if (@unknown_keys) {
      _control_error($form, $file_name, sprintf($locale->text("Unknown control fields: #1", join(' ', sort({ lc $a cmp lc $b } @unknown_keys)))));
    }

    $control->{"priority"}  *= 1;
    $control->{"priority"} ||= 1000;
    $control->{"file"}       = $file;

    $all_controls{$control->{"tag"}} = $control;

    close(IN);
  }

  foreach my $control (values(%all_controls)) {
    foreach my $dependency (@{$control->{"depends"}}) {
      _control_error($form, $control->{"file"}, sprintf($locale->text("Unknown dependency '%s'."), $dependency)) if (!defined($all_controls{$dependency}));
    }

    map({ $_->{"loop"} = 0; } values(%all_controls));
    _check_for_loops($form, $control->{"file"}, \%all_controls, $control->{"tag"});
  }

  map({ _dbupdate2_calculate_depth(\%all_controls, $_->{"tag"}) }
      values(%all_controls));

  $self->{all_controls} = \%all_controls;

  return $self;
}

sub process_query {
  $::lxdebug->enter_sub();

  my ($self, $dbh, $filename, $version_or_control) = @_;

  my $form  = $self->{form};
  my $fh    = IO::File->new($filename, "<:encoding(UTF-8)");
  my $query = "";
  my $sth;
  my @quote_chars;

  if (!$fh) {
    return "No such file: $filename" if $self->{return_on_error};
    $form->error("$filename : $!\n");
  }

  $dbh->begin_work();

  while (<$fh>) {
    # Remove DOS and Unix style line endings.
    chomp;

    for (my $i = 0; $i < length($_); $i++) {
      my $char = substr($_, $i, 1);

      # Are we inside a string?
      if (@quote_chars) {
        if ($char eq $quote_chars[-1]) {
          pop(@quote_chars);
        } elsif (length $quote_chars[-1] > 1
             &&  substr($_, $i, length $quote_chars[-1]) eq $quote_chars[-1]) {
          $i   += length($quote_chars[-1]) - 1;
          $char = $quote_chars[-1];
          pop(@quote_chars);
        }
        $query .= $char;

      } else {
        my ($tag, $tag_end);
        if (($char eq "'") || ($char eq "\"")) {
          push(@quote_chars, $char);

        } elsif ($char eq '$'                                            # start of dollar quoting
             && ($tag_end  = index($_, '$', $i + 1)) > -1                # ends on same line
             && (do { $tag = substr($_, $i + 1, $tag_end - $i - 1); 1 }) # extract tag
             &&  $tag      =~ /^ (?= [A-Za-z_] [A-Za-z0-9_]* | ) $/x) {  # tag is identifier
          push @quote_chars, $char = '$' . $tag . '$';
          $i = $tag_end;
        } elsif ($char eq "-") {
          if ( substr($_, $i+1, 1) eq "-") {
            # found a comment outside quote
            last;
          }
        } elsif ($char eq ";") {

          # Query is complete. Send it.

          $sth = $dbh->prepare($query);
          if (!$sth->execute()) {
            my $errstr = $dbh->errstr;
            return $errstr // '<unknown database error>' if $self->{return_on_error};
            $sth->finish();
            $dbh->rollback();
            if (!ref $version_or_control || ref $version_or_control ne 'HASH' || !$version_or_control->{may_fail})  {
              $form->dberror("The database update/creation did not succeed. " .
                             "The file ${filename} containing the following " .
                             "query failed:<br>${query}<br>" .
                             "The error message was: ${errstr}<br>" .
                             "All changes in that file have been reverted.")
            }
          }
          $sth->finish();

          $char  = "";
          $query = "";
        }

        $query .= $char;
      }
    }

    # Insert a space at the end of each line so that queries split
    # over multiple lines work properly.
    if ($query ne '') {
      $query .= @quote_chars ? "\n" : ' ';
    }
  }

  if (ref($version_or_control) eq "HASH") {
    $dbh->do("INSERT INTO " . $self->{schema} . "schema_info (tag, login) VALUES (" . $dbh->quote($version_or_control->{"tag"}) . ", " . $dbh->quote($form->{"login"}) . ")");
  } elsif ($version_or_control) {
    $dbh->do("UPDATE defaults SET version = " . $dbh->quote($version_or_control));
  }
  $dbh->commit();

  $fh->close();

  $::lxdebug->leave_sub();

  # Signal "no error"
  return undef;
}

# Process a Perl script which updates the database.
# If the script returns 1 then the update was successful.
# Return code "2" means "needs more interaction; unlock
# the system and end current request".
# All other return codes are fatal errors.
sub process_perl_script {
  $::lxdebug->enter_sub();

  my ($self, $dbh, $filename, $version_or_control) = @_;

  my %form_values = %$::form;

  $dbh->begin_work;

  # setup dbup_ export vars & run script
  my %dbup_myconfig = map { ($_ => $::form->{$_}) } qw(dbname dbuser dbpasswd dbhost dbport dbconnect);
  my $result        = eval {
    SL::DBUpgrade2::Base::execute_script(
      file_name => $filename,
      tag       => $version_or_control->{tag},
      dbh       => $dbh,
      myconfig  => \%dbup_myconfig,
    );
  };

  my $error = $EVAL_ERROR;

  $dbh->rollback if 1 != ($result // -1);

  return $error if $self->{return_on_error} && (1 != ($result // -1));

  if (!defined($result)) {
    print $::form->parse_html_template("dbupgrade/error", { file  => $filename, error => $error });
    $::dispatcher->end_request;
  } elsif (1 != $result) {
    SL::System::InstallationLock->unlock if 2 == $result;
    $::dispatcher->end_request;
  }

  if (ref($version_or_control) eq "HASH") {
    $dbh->do("INSERT INTO " . $self->{schema} . "schema_info (tag, login) VALUES (" . $dbh->quote($version_or_control->{tag}) . ", " . $dbh->quote($::form->{login}) . ")");
  } elsif ($version_or_control) {
    $dbh->do("UPDATE defaults SET version = " . $dbh->quote($version_or_control));
  }

  $dbh->commit if !$dbh->{AutoCommit} || $dbh->{BegunWork};

  # Clear $::form of values that may have been set so that following
  # Perl upgrade scripts won't have to work with old data (think of
  # the usual 'continued' mechanism that's used for determining
  # whether or not the upgrade form must be displayed).
  delete @{ $::form }{ keys %{ $::form } };
  $::form->{$_} = $form_values{$_} for keys %form_values;

  $::lxdebug->leave_sub();

  return undef;
}

sub process_file {
  my ($self, $dbh, $filename, $version_or_control) = @_;

  my $result = $filename =~ m/sql$/ ? $self->process_query(      $dbh, $filename, $version_or_control)
                                    : $self->process_perl_script($dbh, $filename, $version_or_control);

  $::lxdebug->log_time("DB upgrade script '${filename}' finished");

  return $result;
}

sub unapplied_upgrade_scripts {
  my ($self, $dbh) = @_;

  my @all_scripts = map { $_->{applied} = 0; $_ } $self->sort_dbupdate_controls;

  my $query = qq|SELECT tag FROM | . $self->{schema} . qq|schema_info|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $self->{form}->dberror($query);
  while (my ($tag) = $sth->fetchrow_array()) {
    $self->{all_controls}->{$tag}->{applied} = 1 if defined $self->{all_controls}->{$tag};
  }
  $sth->finish;

  return grep { !$_->{applied} } @all_scripts;
}

sub apply_admin_dbupgrade_scripts {
  my ($self, $called_from_admin) = @_;

  return 0 if !$self->{auth};

  my $dbh               = $::auth->dbconnect;
  my @unapplied_scripts = $self->unapplied_upgrade_scripts($dbh);

  return 0 if !@unapplied_scripts;

  $self->{form}->{login} ||= 'admin';

  if ($called_from_admin) {
    $self->{form}->{title} = $::locale->text('Dataset upgrade');
    $self->{form}->header;
  }

  print $self->{form}->parse_html_template("dbupgrade/header", { dbname => $::auth->{DB_config}->{db} });

  $::lxdebug->log_time("DB upgrades commencing");

  foreach my $control (@unapplied_scripts) {
    $::lxdebug->message(LXDebug->DEBUG2(), "Applying Update $control->{file}");
    print $self->{form}->parse_html_template("dbupgrade/upgrade_message2", $control);

    $self->process_file($dbh, "sql/Pg-upgrade2-auth/$control->{file}", $control);
  }

  $::lxdebug->log_time("DB upgrades finished");

  print $self->{form}->parse_html_template("dbupgrade/footer", { is_admin => 1 }) if $called_from_admin;

  return 1;
}

sub _check_for_loops {
  my ($form, $file_name, $controls, $tag, @path) = @_;

  push(@path, $tag);

  my $ctrl = $controls->{$tag};

  if ($ctrl->{"loop"} == 1) {
    # Not done yet.
    _control_error($form, $file_name, $::locale->text("Dependency loop detected:") . " " . join(" -> ", @path))

  } elsif ($ctrl->{"loop"} == 0) {
    # Not checked yet.
    $ctrl->{"loop"} = 1;
    map({ _check_for_loops($form, $file_name, $controls, $_, @path); } @{ $ctrl->{"depends"} });
    $ctrl->{"loop"} = 2;
  }
}

sub _control_error {
  my ($form, $file_name, $message) = @_;

  $form = $::form;
  my $locale = $::locale;

  $form->error(sprintf($locale->text("Error in database control file '%s': %s"), $file_name, $message));
}

sub _dbupdate2_calculate_depth {
  my ($tree, $tag) = @_;

  my $node = $tree->{$tag};

  return if (defined($node->{"depth"}));

  my $max_depth = 0;

  foreach $tag (@{$node->{"depends"}}) {
    _dbupdate2_calculate_depth($tree, $tag);
    my $value = $tree->{$tag}->{"depth"};
    $max_depth = $value if ($value > $max_depth);
  }

  $node->{"depth"} = $max_depth + 1;
}

sub sort_dbupdate_controls {
  my $self = shift;

  $self->parse_dbupdate_controls unless $self->{all_controls};

  return sort { ($a->{depth} <=> $b->{depth}) || ($a->{priority} <=> $b->{priority}) || ($a->{tag} cmp $b->{tag}) } values %{ $self->{all_controls} };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DBUpgrade2 - Parse database upgrade files stored in
C<sql/Pg-upgrade2> and C<sql/Pg-upgrade2-auth>

=head1 SYNOPSIS

  use SL::User;
  use SL::DBUpgrade2;

  # Apply outstanding updates to the authentication database
  my $scripts = SL::DBUpgrade2->new(
    form     => $::form,
    auth     => 1
  );
  $scripts->apply_admin_dbupgrade_scripts(1);

  # Apply updates to a user database
  my $scripts = SL::DBUpgrade2->new(
    form     => $::form,
    auth     => 1
  );
  User->dbupdate2(form     => $form,
                  updater  => $scripts->parse_dbupdate_controls,
                  database => $dbname);

=head1 OVERVIEW

Database upgrade files are used to upgrade the database structure and
content of both the authentication database and the user
databases. They're applied when a user logs in. As long as the
authentication database is not up to date users cannot log in in
general, and the admin has to log in first in order to get his
database updated.

Database scripts form a tree by specifying which upgrade file depends
on which other upgrade file. This means that such files are always
applied in a well-defined order.

Each script is run in a separate transaction. If a script fails the
current transaction is rolled back and the whole upgrade process is
stopped. The user/admin is required to fix the issue manually.

A list of applied upgrade scripts is maintained in a table called
C<schema_info> for the user database and C<auth.schema_info>) for the
authentication database. They contain the tags, the login name of the
user having applied the script and the timestamp when the script was
applied.

Database upgrade files come in two flavours: SQL files and Perl
files. For both there are control fields that determine the order in
which they're executed etc. The control fields are tag/value pairs
contained in comments.

=head1 CONTROL FIELDS

=head2 SYNTAX

Control fields for Perl files:

  # @tag1: value1
  # @tag2: some more values
  sub do_stuff {
  }
  1;

Control fields for SQL files:

  -- @tag1: value1
  -- @tag2: some more values
  ALTER TABLE ...;

=head2 TAGS AND THEIR MEANING

The following tags are recognized:

=over 4

=item tag

The name for this file. The C<tag> is also used for dependency
resolution (see C<depends>).

This is mandatory.

=item description

A description presented to the user when the update is applied.

This is mandatory.

=item depends

A space-separated list of tags of scripts this particular script
depends on. All other upgrades listed in C<depends> will be applied
before the current one is applied.

=item priority

Ordering the scripts by their dependencies alone produces a lot of
groups of scripts that could be applied at the same time (e.g. if both
B and C depend only on A then B could be applied before C or the other
way around). This field determines the order inside such a
group. Scripts with lower priority fields are executed before scripts
with higher priority fields.

If two scripts have equal priorities then their tag name decides.

The priority defaults to 1000.

=back

=head1 FUNCTIONS

=over 4

=item C<apply_admin_dbupgrade_scripts $called_from_admin>

Applies all unapplied upgrade files to the authentication/admin
database. The parameter C<$called_from_admin> should be truish if the
function is called from the web interface and falsish if it's called
from e.g. a command line script like C<scripts/dbupgrade2_tool.pl>.

=item C<init %params>

Initializes the object. Is called directly from L<new> and should not
be called again.

=item C<new %params>

Creates a new object. Possible parameters are:

=over 4

=item path

Path to the upgrade files to parse. Required.

=item form

C<SL::Form> object to use. Required.

=item auth

Optional parameter defaulting to 0. If trueish then the scripts read
are the ones applying to the authentication database.

=back

=item C<parse_dbupdate_controls>

Parses all files located in C<path> (see L<new>), ananlyzes their
control fields, builds the tree, and signals errors if control fields
are missing/wrong (e.g. a tag name listed in C<depends> is not
found). Sets C<$Self-&gt;{all_controls}> to the list of database
scripts.

=item C<process_file $dbh, $filename, $version_or_control>

Applies a single database upgrade file. Calls L<process_perl_script>
for Perl update files and C<process_query> for SQL update
files. Requires an open database handle(C<$dbh>), the file name
(C<$filename>) and a hash structure of the file's control fields as
produced by L<parse_dbupdate_controls> (C<$version_or_control>).

Returns the result of the actual function called.

=item C<process_perl_script $dbh, $filename, $version_or_control>

Applies a single Perl database upgrade file. Requires an open database
handle(C<$dbh>), the file name (C<$filename>) and a hash structure of
the file's control fields as produced by L<parse_dbupdate_controls>
(C<$version_or_control>).

Perl scripts are executed via L<eval>. If L<eval> returns falsish then
an error is expected. There are two special return values: If the
script returns C<1> then the update was successful. Return code C<2>
means "needs more interaction from the user; unlock the system and
end current upgrade process". All other return codes are fatal errors.

Inside the Perl script several local variables exist that can be used:

=over 4

=item $dbup_locale

A locale object for translating messages

=item $dbh

The database handle (inside a transaction).

=item $::form

The global C<SL::Form> object.

=back

A Perl script can actually implement queries that fail while
continuing the process by handling the transaction itself, e.g. with
the following function:

  sub do_query {
    my ($query, $may_fail) = @_;

    if (!$dbh->do($query)) {
      die($dbup_locale->text("Database update error:") . "<br>$msg<br>" . $DBI::errstr) unless $may_fail;
      $dbh->rollback();
      $dbh->begin_work();
    }
  }

=item C<process_query $dbh, $filename, $version_or_control>

Applies a single SQL database upgrade file. Requires an open database
handle(C<$dbh>), the file name (C<$filename>), and a hash structure of
the file's control fields as produced by L<parse_dbupdate_controls>
(C<$version_or_control>).

=item C<sort_dbupdate_controls>

Sorts the database upgrade scripts according to their C<tag> and
C<priority> control fields. Returns a list of their hash
representations that can be applied in order.

=item C<unapplied_upgrade_scripts $dbh>

Returns a list if upgrade scripts (their internal hash representation)
that haven't been applied to a database yet. C<$dbh> is an open handle
to the database that is checked.

Requires that the scripts have been parsed.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
