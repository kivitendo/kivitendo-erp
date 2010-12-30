#!/usr/bin/perl
# @tag: auth_schema_normalization_1
# @description: Auth-Datenbankschema Normalisierungen Teil 1
# @depends:

use strict;

sub do_one {
  my ($dbh, $query) = @_;

  if ($dbh->do($query)) {
    $dbh->commit();
  } else {
    $dbh->rollback();
  }
}

sub do_all {
  my $dbh = $::auth->dbconnect();

  my @queries = ( qq|ALTER TABLE auth.group_rights ADD PRIMARY KEY (group_id, "right");|,
                  qq|ALTER TABLE auth.user_config  ADD PRIMARY KEY (user_id,  cfg_key);|,
                  qq|ALTER TABLE auth.user_group   ADD PRIMARY KEY (user_id,  group_id);|);

  do_one($dbh, $_) for @queries;
}

do_all();

1;
