# @tag: auth_schema_normalization_1
# @description: Auth-Datenbankschema Normalisierungen Teil 1
# @depends:
package SL::DBUpgrade2::auth_schema_normalization_1;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub do_one {
  my ($self, $query) = @_;

  if ($self->dbh->do($query)) {
    $self->dbh->commit();
  } else {
    $self->dbh->rollback();
  }
}

sub run {
  my ($self) = @_;

  $self->dbh($::auth->dbconnect);

  my @queries = ( qq|ALTER TABLE auth.group_rights ADD PRIMARY KEY (group_id, "right");|,
                  qq|ALTER TABLE auth.user_config  ADD PRIMARY KEY (user_id,  cfg_key);|,
                  qq|ALTER TABLE auth.user_group   ADD PRIMARY KEY (user_id,  group_id);|);

  $self->do_one($_) for @queries;
}

1;
