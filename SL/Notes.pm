# Notes

package Notes;

use SL::Common;
use SL::DBUtils;
use SL::DB;

use strict;

sub save {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;
    my ($query, @values);

    if (!$params{id}) {
      ($params{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('note_id')|);
      $query        = qq|INSERT INTO notes (created_by, trans_id, trans_module, subject, body, id)
                         VALUES ((SELECT id FROM employee WHERE login = ?), ?, ?, ?, ?, ?)|;
      push @values, $::myconfig{login}, conv_i($params{trans_id}), $params{trans_module};

    } else {
      $query        = qq|UPDATE notes SET subject = ?, body = ? WHERE id = ?|;
    }

    push @values, $params{subject}, $params{body}, conv_i($params{id});

    do_query($form, $dbh, $query, @values);
  });

  $main::lxdebug->leave_sub();

  return $params{id};
}

sub retrieve {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $ref      = selectfirst_hashref_query($form, $dbh, qq|SELECT * FROM notes WHERE id = ?|, conv_i($params{id}));

  $main::lxdebug->leave_sub();

  return $ref;
}

sub delete {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;
    my $id       = conv_i($params{id});

    do_query($form, $dbh, qq|DELETE FROM follow_up_links WHERE follow_up_id IN (SELECT DISTINCT id FROM follow_ups WHERE note_id = ?)|, $id);
    do_query($form, $dbh, qq|DELETE FROM follow_ups      WHERE note_id = ?|, $id);
    do_query($form, $dbh, qq|DELETE FROM notes           WHERE id = ?|, $id);
  });

  $main::lxdebug->leave_sub();
}

1;
