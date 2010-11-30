package SL::DBUpgrade2;

use IO::File;
use List::MoreUtils qw(any);

use SL::Common;
use SL::Iconv;

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
  $params{schame}      ||= '';

  map { $self->{$_} = $params{$_} } keys %params;

  return $self;
}

sub parse_dbupdate_controls {
  $::lxdebug->enter_sub();

  my ($self) = @_;

  my $form   = $self->{form};
  my $locale = $::locale;

  local *IN;
  my %all_controls;

  my $path = "sql/" . $self->{dbdriver} . "-upgrade2" . $self->{path_suffix};

  foreach my $file_name (<$path/*.sql>, <$path/*.pl>) {
    next unless (open(IN, $file_name));

    my $file = $file_name;
    $file =~ s|.*/||;

    my $control = {
      "priority" => 1000,
      "depends"  => [],
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
      } else {
        $control->{$fields[0]} = $fields[1];
      }
    }

    next if ($control->{ignore});

    $control->{charset} ||= Common::DEFAULT_CHARSET;

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

    $control->{"priority"}  *= 1;
    $control->{"priority"} ||= 1000;
    $control->{"file"}       = $file;

    delete @{$control}{qw(depth applied)};

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

  $::lxdebug->leave_sub();

  return $self;
}

sub process_query {
  $::lxdebug->enter_sub();

  my ($self, $dbh, $filename, $version_or_control, $db_charset) = @_;

  my $form  = $self->{form};
  my $fh    = IO::File->new($filename, "r") or $form->error("$filename : $!\n");
  my $query = "";
  my $sth;
  my @quote_chars;

  my $file_charset = Common::DEFAULT_CHARSET;
  while (<$fh>) {
    last if !/^--/;
    next if !/^--\s*\@charset:\s*(.+)/;
    $file_charset = $1;
    last;
  }
  $fh->seek(0, SEEK_SET);

  $db_charset ||= Common::DEFAULT_CHARSET;

  $dbh->begin_work();

  while (<$fh>) {
    $_ = SL::Iconv::convert($file_charset, $db_charset, $_);

    # Remove DOS and Unix style line endings.
    chomp;

    # remove comments
    s/--.*$//;

    for (my $i = 0; $i < length($_); $i++) {
      my $char = substr($_, $i, 1);

      # Are we inside a string?
      if (@quote_chars) {
        if ($char eq $quote_chars[-1]) {
          pop(@quote_chars);
        }
        $query .= $char;

      } else {
        if (($char eq "'") || ($char eq "\"")) {
          push(@quote_chars, $char);

        } elsif ($char eq ";") {

          # Query is complete. Send it.

          $sth = $dbh->prepare($query);
          if (!$sth->execute()) {
            my $errstr = $dbh->errstr;
            $sth->finish();
            $dbh->rollback();
            $form->dberror("The database update/creation did not succeed. " .
                           "The file ${filename} containing the following " .
                           "query failed:<br>${query}<br>" .
                           "The error message was: ${errstr}<br>" .
                           "All changes in that file have been reverted.");
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
}

# Process a Perl script which updates the database.
# If the script returns 1 then the update was successful.
# Return code "2" means "needs more interaction; remove
# users/nologin and end current request".
# All other return codes are fatal errors.
sub process_perl_script {
  $::lxdebug->enter_sub();

  my ($self, $dbh, $filename, $version_or_control, $db_charset) = @_;

  my $form         = $self->{form};
  my $fh           = IO::File->new($filename, "r") or $form->error("$filename : $!\n");
  my $file_charset = Common::DEFAULT_CHARSET;

  if (ref($version_or_control) eq "HASH") {
    $file_charset = $version_or_control->{charset};

  } else {
    while (<$fh>) {
      last if !/^--/;
      next if !/^--\s*\@charset:\s*(.+)/;
      $file_charset = $1;
      last;
    }
    $fh->seek(0, SEEK_SET);
  }

  my $contents = join "", <$fh>;
  $fh->close();

  $db_charset ||= Common::DEFAULT_CHARSET;

  my $iconv = SL::Iconv::get_converter($file_charset, $db_charset);

  $dbh->begin_work();

  # setup dbup_ export vars
  my %dbup_myconfig = ();
  map({ $dbup_myconfig{$_} = $form->{$_}; } qw(dbname dbuser dbpasswd dbhost dbport dbconnect));

  my $dbup_locale = $::locale;

  my $result = eval($contents);

  if (1 != $result) {
    $dbh->rollback();
    $dbh->disconnect();
  }

  if (!defined($result)) {
    print $form->parse_html_template("dbupgrade/error",
                                     { "file"  => $filename,
                                       "error" => $@ });
    ::end_of_request();
  } elsif (1 != $result) {
    unlink("users/nologin") if (2 == $result);
    ::end_of_request();
  }

  if (ref($version_or_control) eq "HASH") {
    $dbh->do("INSERT INTO schema_info (tag, login) VALUES (" . $dbh->quote($version_or_control->{"tag"}) . ", " . $dbh->quote($form->{"login"}) . ")");
  } elsif ($version_or_control) {
    $dbh->do("UPDATE defaults SET version = " . $dbh->quote($version_or_control));
  }
  $dbh->commit();

  $::lxdebug->leave_sub();
}

sub process_file {
  my ($self, $dbh, $filename, $version_or_control, $db_charset) = @_;

  if ($filename =~ m/sql$/) {
    $self->process_query($dbh, $filename, $version_or_control, $db_charset);
  } else {
    $self->process_perl_script($dbh, $filename, $version_or_control, $db_charset);
  }
}

sub update_available {
  my ($self, $cur_version) = @_;

  local *SQLDIR;

  my $dbdriver = $self->{dbdriver};
  opendir SQLDIR, "sql/${dbdriver}-upgrade" || error("", "sql/${dbdriver}-upgrade: $!");
  my @upgradescripts = grep /${dbdriver}-upgrade-\Q$cur_version\E.*\.(sql|pl)$/, readdir SQLDIR;
  closedir SQLDIR;

  return ($#upgradescripts > -1);
}

sub update2_available {
  $::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  map { $_->{applied} = 0; } values %{ $self->{all_controls} };

  my $sth = $dbh->prepare(qq|SELECT tag FROM | . $self->{schema} . qq|schema_info|);
  if ($sth->execute) {
    while (my ($tag) = $sth->fetchrow_array) {
      $self->{all_controls}->{$tag}->{applied} = 1 if defined $self->{all_controls}->{$tag};
    }
  }
  $sth->finish();

  my $needs_update = any { !$_->{applied} } values %{ $self->{all_controls} };

  $::lxdebug->leave_sub();

  return $needs_update;
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
  $::lxdebug->enter_sub(2);

  my ($tree, $tag) = @_;

  my $node = $tree->{$tag};

  return $::lxdebug->leave_sub(2) if (defined($node->{"depth"}));

  my $max_depth = 0;

  foreach $tag (@{$node->{"depends"}}) {
    _dbupdate2_calculate_depth($tree, $tag);
    my $value = $tree->{$tag}->{"depth"};
    $max_depth = $value if ($value > $max_depth);
  }

  $node->{"depth"} = $max_depth + 1;

  $::lxdebug->leave_sub(2);
}

sub sort_dbupdate_controls {
  my $self = shift;

  return sort { ($a->{depth} <=> $b->{depth}) || ($a->{priority} <=> $b->{priority}) || ($a->{tag} cmp $b->{tag}) } values %{ $self->{all_controls} };
}

1;
