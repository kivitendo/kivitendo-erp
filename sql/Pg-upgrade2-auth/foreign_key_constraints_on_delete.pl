# @tag: foreign_key_constraints_on_delete
# @description: Ändert "FOREIGN KEY" constraints auf "ON DELETE CASCADE"
# @depends: clients
# @ignore: 0
package SL::DBUpgrade2::Auth::foreign_key_constraints_on_delete;

use Data::Dumper;


use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(schema => 'auth', table => $_) for qw(clients_groups clients_users group_rights session_content user_config user_group);

  my @add_constraints = (
    qq|ALTER TABLE auth.clients_groups ADD FOREIGN KEY (client_id) REFERENCES auth.clients (id) ON DELETE CASCADE|,
    qq|ALTER TABLE auth.clients_groups ADD FOREIGN KEY (group_id)  REFERENCES auth."group" (id) ON DELETE CASCADE|,

    qq|ALTER TABLE auth.clients_users ADD FOREIGN KEY (client_id) REFERENCES auth.clients (id) ON DELETE CASCADE|,
    qq|ALTER TABLE auth.clients_users ADD FOREIGN KEY (user_id)   REFERENCES auth."user"  (id) ON DELETE CASCADE|,

    qq|ALTER TABLE auth.group_rights ADD FOREIGN KEY (group_id) REFERENCES auth."group" (id) ON DELETE CASCADE|,


    qq|ALTER TABLE auth.session_content ADD FOREIGN KEY (session_id) REFERENCES auth.session (id) ON DELETE CASCADE|,

    qq|ALTER TABLE auth.user_config ADD FOREIGN KEY (user_id) REFERENCES auth."user" (id) ON DELETE CASCADE|,

    qq|ALTER TABLE auth.user_group ADD FOREIGN KEY (user_id)  REFERENCES auth."user"  (id) ON DELETE CASCADE|,
    qq|ALTER TABLE auth.user_group ADD FOREIGN KEY (group_id) REFERENCES auth."group" (id) ON DELETE CASCADE|,
  );

  $self->db_query($_) for @add_constraints;

  return 1;
}

1;
