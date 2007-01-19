#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#=====================================================================
#
# user related functions
#
#=====================================================================

package User;

use SL::DBUpgrade2;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $memfile, $login) = @_;
  my $self = {};

  if ($login ne "") {
    &error("", "$memfile locked!") if (-f "${memfile}.LCK");

    open(MEMBER, "$memfile") or &error("", "$memfile : $!");

    while (<MEMBER>) {
      if (/^\[$login\]/) {
        while (<MEMBER>) {
          last if /^\[/;
          next if /^(#|\s)/;

          # remove comments
          s/\s#.*//g;

          # remove any trailing whitespace
          s/^\s*(.*?)\s*$/$1/;

          ($key, $value) = split(/=/, $_, 2);

          if (($key eq "stylesheet") && ($value eq "sql-ledger.css")) {
            $value = "lx-office-erp.css";
          }

          $self->{$key} = $value;
        }

        $self->{login} = $login;

        last;
      }
    }
    close MEMBER;
  }

  $main::lxdebug->leave_sub();
  bless $self, $type;
}

sub country_codes {
  $main::lxdebug->enter_sub();

  my %cc       = ();
  my @language = ();

  # scan the locale directory and read in the LANGUAGE files
  opendir DIR, "locale";

  my @dir = grep !/(^\.\.?$|\..*)/, readdir DIR;

  foreach my $dir (@dir) {
    next unless open(FH, "locale/$dir/LANGUAGE");
    @language = <FH>;
    close FH;

    $cc{$dir} = "@language";
  }

  closedir(DIR);

  $main::lxdebug->leave_sub();

  return %cc;
}

sub login {
  $main::lxdebug->enter_sub();

  my ($self, $form, $userspath) = @_;

  my $rc = -3;

  if ($self->{login}) {

    if ($self->{password}) {
      if ($form->{hashed_password}) {
        $form->{password} = $form->{hashed_password};
      } else {
        $form->{password} = crypt($form->{password},
                                  substr($self->{login}, 0, 2));
      }
      if ($self->{password} ne $form->{password}) {
        $main::lxdebug->leave_sub();
        return -1;
      }
    }

    unless (-e "$userspath/$self->{login}.conf") {
      $self->create_config("$userspath/$self->{login}.conf");
    }

    do "$userspath/$self->{login}.conf";
    $myconfig{dbpasswd} = unpack 'u', $myconfig{dbpasswd};

    # check if database is down
    my $dbh =
      DBI->connect($myconfig{dbconnect}, $myconfig{dbuser},
                   $myconfig{dbpasswd})
      or $self->error(DBI::errstr);

    # we got a connection, check the version
    my $query = qq|SELECT version FROM defaults|;
    my $sth   = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($dbversion) = $sth->fetchrow_array;
    $sth->finish;

    # add login to employee table if it does not exist
    # no error check for employee table, ignore if it does not exist
    $query = qq|SELECT e.id FROM employee e WHERE e.login = '$self->{login}'|;
    $sth   = $dbh->prepare($query);
    $sth->execute;

    my ($login) = $sth->fetchrow_array;
    $sth->finish;

    if (!$login) {
      $query = qq|INSERT INTO employee (login, name, workphone, role)
                  VALUES ('$self->{login}', '$myconfig{name}',
		  '$myconfig{tel}', 'user')|;
      $dbh->do($query);
    }

    $self->create_schema_info_table($form, $dbh);

    $dbh->disconnect;

    $rc = 0;

    my $controls =
      parse_dbupdate_controls($form, $myconfig{"dbdriver"});

    map({ $form->{$_} = $myconfig{$_} }
        qw(dbname dbhost dbport dbdriver dbuser dbpasswd dbconnect));

    if (update_available($myconfig{"dbdriver"}, $dbversion) ||
        update2_available($form, $controls)) {

      $form->{"stylesheet"} = "lx-office-erp.css";
      $form->{"title"} = $main::locale->text("Dataset upgrade");
      $form->header();
      print($form->parse_html_template("dbupgrade/header"));

      $form->{dbupdate} = "db$myconfig{dbname}";
      $form->{ $form->{dbupdate} } = 1;

      if ($form->{"show_dbupdate_warning"}) {
        print($form->parse_html_template("dbupgrade/warning"));
        exit(0);
      }

      # update the tables
      open(FH, ">$userspath/nologin") or die("$!");

      # required for Oracle
      $form->{dbdefault} = $sid;

      # ignore HUP, QUIT in case the webserver times out
      $SIG{HUP}  = 'IGNORE';
      $SIG{QUIT} = 'IGNORE';

      $self->dbupdate($form);
      $self->dbupdate2($form, $controls);

      # remove lock file
      unlink("$userspath/nologin");

      print($form->parse_html_template("dbupgrade/footer"));

      $rc = -2;

    }
  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub dbconnect_vars {
  $main::lxdebug->enter_sub();

  my ($form, $db) = @_;

  my %dboptions = (
        'Pg' => { 'yy-mm-dd'   => 'set DateStyle to \'ISO\'',
                  'yyyy-mm-dd' => 'set DateStyle to \'ISO\'',
                  'mm/dd/yy'   => 'set DateStyle to \'SQL, US\'',
                  'mm-dd-yy'   => 'set DateStyle to \'POSTGRES, US\'',
                  'dd/mm/yy'   => 'set DateStyle to \'SQL, EUROPEAN\'',
                  'dd-mm-yy'   => 'set DateStyle to \'POSTGRES, EUROPEAN\'',
                  'dd.mm.yy'   => 'set DateStyle to \'GERMAN\''
        },
        'Oracle' => {
          'yy-mm-dd'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'YY-MM-DD\'',
          'yyyy-mm-dd' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'YYYY-MM-DD\'',
          'mm/dd/yy'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'MM/DD/YY\'',
          'mm-dd-yy'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'MM-DD-YY\'',
          'dd/mm/yy'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD/MM/YY\'',
          'dd-mm-yy'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD-MM-YY\'',
          'dd.mm.yy'   => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD.MM.YY\'',
        });

  $form->{dboptions} = $dboptions{ $form->{dbdriver} }{ $form->{dateformat} };

  if ($form->{dbdriver} eq 'Pg') {
    $form->{dbconnect} = "dbi:Pg:dbname=$db";
  }

  if ($form->{dbdriver} eq 'Oracle') {
    $form->{dbconnect} = "dbi:Oracle:sid=$form->{sid}";
  }

  if ($form->{dbhost}) {
    $form->{dbconnect} .= ";host=$form->{dbhost}";
  }
  if ($form->{dbport}) {
    $form->{dbconnect} .= ";port=$form->{dbport}";
  }

  $main::lxdebug->leave_sub();
}

sub dbdrivers {
  $main::lxdebug->enter_sub();

  my @drivers = DBI->available_drivers();

  $main::lxdebug->leave_sub();

  return (grep { /(Pg|Oracle)/ } @drivers);
}

sub dbsources {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my @dbsources = ();
  my ($sth, $query);

  $form->{dbdefault} = $form->{dbuser} unless $form->{dbdefault};
  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});

  my $dbh =
    DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
    or $form->dberror;

  if ($form->{dbdriver} eq 'Pg') {

    $query = qq|SELECT datname FROM pg_database WHERE NOT ((datname = 'template0') OR (datname = 'template1'))|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {

      if ($form->{only_acc_db}) {

        next if ($db =~ /^template/);

        &dbconnect_vars($form, $db);
        my $dbh =
          DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
          or $form->dberror;

        $query = qq|SELECT p.tablename FROM pg_tables p
		    WHERE p.tablename = 'defaults'
		    AND p.tableowner = '$form->{dbuser}'|;
        my $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

        if ($sth->fetchrow_array) {
          push @dbsources, $db;
        }
        $sth->finish;
        $dbh->disconnect;
        next;
      }
      push @dbsources, $db;
    }
  }

  if ($form->{dbdriver} eq 'Oracle') {
    if ($form->{only_acc_db}) {
      $query = qq|SELECT o.owner FROM dba_objects o
		  WHERE o.object_name = 'DEFAULTS'
		  AND o.object_type = 'TABLE'|;
    } else {
      $query = qq|SELECT username FROM dba_users|;
    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {
      push @dbsources, $db;
    }
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return @dbsources;
}

sub dbcreate {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh =
    DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
    or $form->dberror;

  my %dbcreate = (
    'Pg'     => qq|CREATE DATABASE "$form->{db}"|,
    'Oracle' =>
      qq|CREATE USER "$form->{db}" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP IDENTIFIED BY "$form->{db}"|
  );

  my %dboptions = (
    'Pg' => [],
  );

  push(@{$dboptions{"Pg"}}, "ENCODING = " . $dbh->quote($form->{"encoding"}))
    if ($form->{"encoding"});
  if ($form->{"dbdefault"}) {
    my $dbdefault = $form->{"dbdefault"};
    $dbdefault =~ s/[^a-zA-Z0-9_\-]//g;
    push(@{$dboptions{"Pg"}}, "TEMPLATE = $dbdefault");
  }

  my $query = qq|$dbcreate{$form->{dbdriver}}|;
  $query .= " WITH " . join(" ", @{$dboptions{"Pg"}}) if (@{$dboptions{"Pg"}});

  $dbh->do($query) || $form->dberror($query);

  if ($form->{dbdriver} eq 'Oracle') {
    $query = qq|GRANT CONNECT,RESOURCE TO "$form->{db}"|;
    $dbh->do($query) || $form->dberror($query);
  }
  $dbh->disconnect;

  # setup variables for the new database
  if ($form->{dbdriver} eq 'Oracle') {
    $form->{dbuser}   = $form->{db};
    $form->{dbpasswd} = $form->{db};
  }

  &dbconnect_vars($form, $form->{db});

  $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
    or $form->dberror;

  # create the tables
  my $filename = qq|sql/lx-office.sql|;
  $self->process_query($form, $dbh, $filename);

  # load gifi
  ($filename) = split /_/, $form->{chart};
  $filename =~ s/_//;
  $self->process_query($form, $dbh, "sql/${filename}-gifi.sql");

  # load chart of accounts
  $filename = qq|sql/$form->{chart}-chart.sql|;
  $self->process_query($form, $dbh, $filename);

  $query = "UPDATE defaults SET coa = " . $dbh->quote($form->{"chart"});
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

# Process a Perl script which updates the database.
# If the script returns 1 then the update was successful.
# Return code "2" means "needs more interaction; remove
# users/nologin and exit".
# All other return codes are fatal errors.
sub process_perl_script {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh, $filename, $version) = @_;

  open(FH, "$filename") or $form->error("$filename : $!\n");
  my $contents = join("", <FH>);
  close(FH);

  $dbh->begin_work();

  my %dbup_myconfig = ();
  map({ $dbup_myconfig{$_} = $form->{$_}; }
      qw(dbname dbuser dbpasswd dbhost dbport dbconnect));

  my $nls_file = $filename;
  $nls_file =~ s|.*/||;
  $nls_file =~ s|.pl$||;
  my $dbup_locale = Locale->new($main::language, $nls_file);

  my $result = eval($contents);

  if (1 != $result) {
    $dbh->rollback();
    $dbh->disconnect();
  }

  if (!defined($result)) {
    print($form->parse_html_template("dbupgrade/error",
                                     { "file" => $filename,
                                       "error" => $@ }));
    exit(0);
  } elsif (1 != $result) {
    unlink("users/nologin") if (2 == $result);
    exit(0);
  }

  if ($version) {
    $dbh->do("UPDATE defaults SET version = " . $dbh->quote($version));
  }
  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub process_query {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh, $filename, $version_or_control) = @_;

  #  return unless (-f $filename);

  open(FH, "$filename") or $form->error("$filename : $!\n");
  my $query = "";
  my $sth;
  my @quote_chars;

  $dbh->begin_work();

  while (<FH>) {

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
            $form->dberror("The database update/creation did not succeed. The file ${filename} containing the following query failed:<br>${query}<br>" .
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
  }

  if (ref($version_or_control) eq "HASH") {
    $dbh->do("INSERT INTO schema_info (tag, login) VALUES (" .
             $dbh->quote($version_or_control->{"tag"}) . ", " .
             $dbh->quote($form->{"login"}) . ")");
  } elsif ($version_or_control) {
    $dbh->do("UPDATE defaults SET version = " .
             $dbh->quote($version_or_control));
  }
  $dbh->commit();

  close FH;

  $main::lxdebug->leave_sub();
}

sub dbdelete {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my %dbdelete = ('Pg'     => qq|DROP DATABASE "$form->{db}"|,
                  'Oracle' => qq|DROP USER $form->{db} CASCADE|);

  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh =
    DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
    or $form->dberror;
  my $query = qq|$dbdelete{$form->{dbdriver}}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub dbsources_unused {
  $main::lxdebug->enter_sub();

  my ($self, $form, $memfile) = @_;

  my @dbexcl    = ();
  my @dbsources = ();

  $form->error('File locked!') if (-f "${memfile}.LCK");

  # open members file
  open(FH, "$memfile") or $form->error("$memfile : $!");

  while (<FH>) {
    if (/^dbname=/) {
      my ($null, $item) = split(/=/);
      push @dbexcl, $item;
    }
  }

  close FH;

  $form->{only_acc_db} = 1;
  my @db = &dbsources("", $form);

  push @dbexcl, $form->{dbdefault};

  foreach $item (@db) {
    unless (grep /$item$/, @dbexcl) {
      push @dbsources, $item;
    }
  }

  $main::lxdebug->leave_sub();

  return @dbsources;
}

sub dbneedsupdate {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my %dbsources = ();
  my $query;

  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});

  my $dbh =
    DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
    or $form->dberror;

  if ($form->{dbdriver} eq 'Pg') {

    $query = qq|SELECT d.datname FROM pg_database d, pg_user u
                WHERE d.datdba = u.usesysid
		AND u.usename = '$form->{dbuser}'|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {

      next if ($db =~ /^template/);

      &dbconnect_vars($form, $db);

      my $dbh =
        DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
        or $form->dberror;

      $query = qq|SELECT t.tablename FROM pg_tables t
		  WHERE t.tablename = 'defaults'|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      if ($sth->fetchrow_array) {
        $query = qq|SELECT version FROM defaults|;
        my $sth = $dbh->prepare($query);
        $sth->execute;

        if (my ($version) = $sth->fetchrow_array) {
          $dbsources{$db} = $version;
        }
        $sth->finish;
      }
      $sth->finish;
      $dbh->disconnect;
    }
    $sth->finish;
  }

  if ($form->{dbdriver} eq 'Oracle') {
    $query = qq|SELECT o.owner FROM dba_objects o
		WHERE o.object_name = 'DEFAULTS'
		AND o.object_type = 'TABLE'|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {

      $form->{dbuser} = $db;
      &dbconnect_vars($form, $db);

      my $dbh =
        DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
        or $form->dberror;

      $query = qq|SELECT version FROM defaults|;
      my $sth = $dbh->prepare($query);
      $sth->execute;

      if (my ($version) = $sth->fetchrow_array) {
        $dbsources{$db} = $version;
      }
      $sth->finish;
      $dbh->disconnect;
    }
    $sth->finish;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return %dbsources;
}

## LINET
sub calc_version {
  $main::lxdebug->enter_sub(2);

  my (@v, $version, $i);

  @v = split(/\./, $_[0]);
  while (scalar(@v) < 4) {
    push(@v, 0);
  }
  $version = 0;
  for ($i = 0; $i < 4; $i++) {
    $version *= 1000;
    $version += $v[$i];
  }

  $main::lxdebug->leave_sub(2);
  return $version;
}

sub cmp_script_version {
  my ($a_from, $a_to, $b_from, $b_to);
  my ($i, $res_a, $res_b);
  my ($my_a, $my_b) = ($a, $b);

  $my_a =~ s/.*-upgrade-//;
  $my_a =~ s/.sql$//;
  $my_b =~ s/.*-upgrade-//;
  $my_b =~ s/.sql$//;
  ($my_a_from, $my_a_to) = split(/-/, $my_a);
  ($my_b_from, $my_b_to) = split(/-/, $my_b);

  $res_a = calc_version($my_a_from);
  $res_b = calc_version($my_b_from);

  if ($res_a == $res_b) {
    $res_a = calc_version($my_a_to);
    $res_b = calc_version($my_b_to);
  }

  return $res_a <=> $res_b;
}
## /LINET

sub update_available {
  my ($dbdriver, $cur_version) = @_;

  opendir SQLDIR, "sql/${dbdriver}-upgrade" or &error("", "sql/${dbdriver}-upgrade: $!");
  my @upgradescripts =
    grep(/$form->{dbdriver}-upgrade-\Q$cur_version\E.*\.(sql|pl)$/, readdir(SQLDIR));
  closedir SQLDIR;

  return ($#upgradescripts > -1);
}

sub create_schema_info_table {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh) = @_;

  my $query = "SELECT tag FROM schema_info LIMIT 1";
  if (!$dbh->do($query)) {
    $query =
      "CREATE TABLE schema_info (" .
      "  tag text, " .
      "  login text, " .
      "  itime timestamp DEFAULT now(), " .
      "  PRIMARY KEY (tag))";
    $dbh->do($query) || $form->dberror($query);
  }

  $main::lxdebug->leave_sub();
}

sub dbupdate {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  $form->{sid} = $form->{dbdefault};

  my @upgradescripts = ();
  my $query;
  my $rc = -2;

  if ($form->{dbupdate}) {

    # read update scripts into memory
    opendir SQLDIR, "sql/" . $form->{dbdriver} . "-upgrade" or &error("", "sql/" . $form->{dbdriver} . "-upgrade : $!");
    ## LINET
    @upgradescripts =
      sort(cmp_script_version
           grep(/$form->{dbdriver}-upgrade-.*?\.(sql|pl)$/, readdir(SQLDIR)));
    ## /LINET
    closedir SQLDIR;
  }

  foreach my $db (split / /, $form->{dbupdate}) {

    next unless $form->{$db};

    # strip db from dataset
    $db =~ s/^db//;
    &dbconnect_vars($form, $db);

    my $dbh =
      DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
      or $form->dberror;

    # check version
    $query = qq|SELECT version FROM defaults|;
    my $sth = $dbh->prepare($query);

    # no error check, let it fall through
    $sth->execute;

    my $version = $sth->fetchrow_array;
    $sth->finish;

    next unless $version;

    ## LINET
    $version = calc_version($version);
    ## /LINET

    foreach my $upgradescript (@upgradescripts) {
      my $a = $upgradescript;
      $a =~ s/^$form->{dbdriver}-upgrade-|\.(sql|pl)$//g;
      my $file_type = $1;

      my ($mindb, $maxdb) = split /-/, $a;
      my $str_maxdb = $maxdb;
      ## LINET
      $mindb = calc_version($mindb);
      $maxdb = calc_version($maxdb);
      ## /LINET

      next if ($version >= $maxdb);

      # if there is no upgrade script exit
      last if ($version < $mindb);

      # apply upgrade
      $main::lxdebug->message(DEBUG2, "Applying Update $upgradescript");
      if ($file_type eq "sql") {
        $self->process_query($form, $dbh, "sql/" . $form->{"dbdriver"} . "-upgrade/$upgradescript", $str_maxdb);
      } else {
        $self->process_perl_script($form, $dbh, "sql/" . $form->{"dbdriver"} . "-upgrade/$upgradescript", $str_maxdb);
      }

      $version = $maxdb;

    }

    $rc = 0;
    $dbh->disconnect;

  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub dbupdate2 {
  $main::lxdebug->enter_sub();

  my ($self, $form, $controls) = @_;

  $form->{sid} = $form->{dbdefault};

  my @upgradescripts = ();
  my ($query, $sth, $tag);
  my $rc = -2;

  @upgradescripts = sort_dbupdate_controls($controls);

  foreach my $db (split / /, $form->{dbupdate}) {

    next unless $form->{$db};

    # strip db from dataset
    $db =~ s/^db//;
    &dbconnect_vars($form, $db);

    my $dbh =
      DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd})
      or $form->dberror;

    map({ $_->{"applied"} = 0; } @upgradescripts);

    $query = "SELECT tag FROM schema_info";
    $sth = $dbh->prepare($query);
    $sth->execute() || $form->dberror($query);
    while (($tag) = $sth->fetchrow_array()) {
      $controls->{$tag}->{"applied"} = 1 if (defined($controls->{$tag}));
    }
    $sth->finish();

    my $all_applied = 1;
    foreach (@upgradescripts) {
      if (!$_->{"applied"}) {
        $all_applied = 0;
        last;
      }
    }

    next if ($all_applied);

    foreach my $control (@upgradescripts) {
      next if ($control->{"applied"});

      $control->{"file"} =~ /\.(sql|pl)$/;
      my $file_type = $1;

      # apply upgrade
      $main::lxdebug->message(DEBUG2, "Applying Update $control->{file}");
      print($form->parse_html_template("dbupgrade/upgrade_message2",
                                       $control));

      if ($file_type eq "sql") {
        $self->process_query($form, $dbh, "sql/" . $form->{"dbdriver"} .
                             "-upgrade2/$control->{file}", $control);
      } else {
        $self->process_perl_script($form, $dbh, "sql/" . $form->{"dbdriver"} .
                                   "-upgrade2/$control->{file}", $control);
      }
    }

    $rc = 0;
    $dbh->disconnect;

  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub update2_available {
  $main::lxdebug->enter_sub();

  my ($form, $controls) = @_;

  map({ $_->{"applied"} = 0; } values(%{$controls}));

  dbconnect_vars($form, $form->{"dbname"});

  my $dbh =
    DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) ||
    $form->dberror;

  my ($query, $tag, $sth);

  $query = "SELECT tag FROM schema_info";
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (($tag) = $sth->fetchrow_array()) {
    $controls->{$tag}->{"applied"} = 1 if (defined($controls->{$tag}));
  }
  $sth->finish();
  $dbh->disconnect();

  map({ $main::lxdebug->leave_sub() and return 1 if (!$_->{"applied"}) }
      values(%{$controls}));

  $main::lxdebug->leave_sub();
  return 0;
}

sub create_config {
  $main::lxdebug->enter_sub();

  my ($self, $filename) = @_;

  @config = &config_vars;

  open(CONF, ">$filename") or $self->error("$filename : $!");

  # create the config file
  print CONF qq|# configuration file for $self->{login}

\%myconfig = (
|;

  foreach $key (sort @config) {
    $self->{$key} =~ s/\'/\\\'/g;
    print CONF qq|  $key => '$self->{$key}',\n|;
  }

  print CONF qq|);\n\n|;

  close CONF;

  $main::lxdebug->leave_sub();
}

sub save_member {
  $main::lxdebug->enter_sub();

  my ($self, $memberfile, $userspath) = @_;

  my $newmember = 1;

  # format dbconnect and dboptions string
  &dbconnect_vars($self, $self->{dbname});

  $self->error('File locked!') if (-f "${memberfile}.LCK");
  open(FH, ">${memberfile}.LCK") or $self->error("${memberfile}.LCK : $!");
  close(FH);

  open(CONF, "+<$memberfile") or $self->error("$memberfile : $!");

  @config = <CONF>;

  seek(CONF, 0, 0);
  truncate(CONF, 0);

  while ($line = shift @config) {
    if ($line =~ /^\[$self->{login}\]/) {
      $newmember = 0;
      last;
    }
    print CONF $line;
  }

  # remove everything up to next login or EOF
  while ($line = shift @config) {
    last if ($line =~ /^\[/);
  }

  # this one is either the next login or EOF
  print CONF $line;

  while ($line = shift @config) {
    print CONF $line;
  }

  print CONF qq|[$self->{login}]\n|;

  if ((($self->{dbpasswd} ne $self->{old_dbpasswd}) || $newmember)
      && $self->{root}) {
    $self->{dbpasswd} = pack 'u', $self->{dbpasswd};
    chop $self->{dbpasswd};
  }
  if (defined($self->{new_password})) {
    if ($self->{new_password} ne $self->{old_password}) {
      $self->{password} = crypt $self->{new_password},
        substr($self->{login}, 0, 2)
        if $self->{new_password};
    }
  } else {
    if ($self->{password} ne $self->{old_password}) {
      $self->{password} = crypt $self->{password}, substr($self->{login}, 0, 2)
        if $self->{password};
    }
  }

  if ($self->{'root login'}) {
    @config = ("password");
  } else {
    @config = &config_vars;
  }

  # replace \r\n with \n
  map { $self->{$_} =~ s/\r\n/\\n/g } qw(address signature);
  foreach $key (sort @config) {
    print CONF qq|$key=$self->{$key}\n|;
  }

  print CONF "\n";
  close CONF;
  unlink "${memberfile}.LCK";

  # create conf file
  $self->create_config("$userspath/$self->{login}.conf")
    unless $self->{'root login'};

  $main::lxdebug->leave_sub();
}

sub config_vars {
  $main::lxdebug->enter_sub();

  my @conf = qw(acs address admin businessnumber charset company countrycode
    currency dateformat dbconnect dbdriver dbhost dbport dboptions
    dbname dbuser dbpasswd email fax name numberformat in_numberformat password
    printer role sid signature stylesheet tel templates vclimit angebote bestellungen rechnungen
    anfragen lieferantenbestellungen einkaufsrechnungen taxnumber co_ustid duns menustyle
    template_format copies show_form_details);

  $main::lxdebug->leave_sub();

  return @conf;
}

sub error {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    print qq|Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">

<body bgcolor=ffffff>

<h2><font color=red>Error!</font></h2>
<p><b>$msg</b>|;

  }

  die "Error: $msg\n";

  $main::lxdebug->leave_sub();
}

1;

