# @tag: mail_journal_rights
# @description:  Extra right for email journal
# @depends: master_rights_position_gaps
# @locales: E-Mail-Journal
# @locales: Read all employee e-mails

package SL::DBUpgrade2::Auth::mail_journal_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (?, ?, ?)", bind => $_) for
    [ 4450, 'email_journal'         , 'E-Mail-Journal'            ],
    [ 4480, 'email_employee_readall', 'Read all employee e-mails' ];

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{email_journal}          = $group->{rights}->{productivity};
    $group->{rights}->{email_employee_readall} = $group->{rights}->{admin};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
