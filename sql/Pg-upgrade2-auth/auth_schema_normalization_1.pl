# @tag: auth_schema_normalization_1
# @description: Auth-Datenbankschema Normalisierungen Teil 1
# @depends:
package SL::DBUpgrade2::Auth::auth_schema_normalization_1;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries = ( qq|ALTER TABLE auth.group_rights ADD PRIMARY KEY (group_id, "right");|,
                  qq|ALTER TABLE auth.user_config  ADD PRIMARY KEY (user_id,  cfg_key);|,
                  qq|ALTER TABLE auth.user_group   ADD PRIMARY KEY (user_id,  group_id);|);

  $self->db_query($_, may_fail => 1) for @queries;

  return 1;
}

1;
