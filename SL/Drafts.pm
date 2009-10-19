#======================================================================
# LX-Office ERP
#
#======================================================================
#
# Saving and loading drafts
#
#======================================================================

package Drafts;

use YAML;

use SL::Common;
use SL::DBUtils;

use strict;

sub get_module {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my ($module, $submodule);

  $module = $form->{"script"};
  $module =~ s/\.pl$//;
  if (grep({ $module eq $_ } qw(is ir ar ap))) {
    $submodule = "invoice";
  } else {
    $submodule = "unknown";
  }

  $main::lxdebug->leave_sub();

  return ($module, $submodule);
}

my @dont_save = qw(login password stylesheet action);

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $draft_id, $draft_description) = @_;

  my ($dbh, $sth, $query, %saved, $dumped);

  $dbh = $form->dbconnect_noauto($myconfig);

  my ($module, $submodule) = $self->get_module($form);

  $query = "SELECT COUNT(*) FROM drafts WHERE id = ?";
  my ($res) = selectrow_query($form, $dbh, $query, $draft_id);

  if (!$res) {
    $draft_id = $module . "-" . $submodule . "-" . Common::unique_id();
    $query    = "INSERT INTO drafts (id, module, submodule) VALUES (?, ?, ?)";
    do_query($form, $dbh, $query, $draft_id, $module, $submodule);
  }

  map({ $saved{$_} = $form->{$_};
        delete($form->{$_}); } @dont_save);

  $dumped = YAML::Dump($form);
  map({ $form->{$_} = $saved{$_}; } @dont_save);

  $query =
    qq|UPDATE drafts SET description = ?, form = ?, employee_id = | .
    qq|  (SELECT id FROM employee WHERE login = ?) | .
    qq|WHERE id = ?|;

  do_query($form, $dbh, $query, $draft_description, $dumped, $form->{login}, $draft_id);

  $dbh->commit();
  $dbh->disconnect();

  $form->{draft_id}          = $draft_id;
  $form->{draft_description} = $draft_description;

  $main::lxdebug->leave_sub();
}

sub load {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $draft_id) = @_;

  my ($dbh, $sth, $query, @values);

  $dbh = $form->dbconnect($myconfig);

  $query = qq|SELECT id, description, form FROM drafts WHERE id = ?|;

  $sth = prepare_execute_query($form, $dbh, $query, $draft_id);

  if (my $ref = $sth->fetchrow_hashref()) {
    @values = ($ref->{form}, $ref->{id}, $ref->{description});
  }
  $sth->finish();

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return @values;
}

sub remove {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, @draft_ids) = @_;

  return $main::lxdebug->leave_sub() unless (@draft_ids);

  my ($dbh, $sth, $query);

  $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM drafts WHERE id IN (| . join(", ", map { "?" } @draft_ids) . qq|)|;
  do_query($form, $dbh, $query, @draft_ids);

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub list {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($dbh, $sth, $query, @values);

  $dbh = $form->dbconnect($myconfig);

  my ($module, $submodule) = $self->get_module($form);

  my @list = ();
  $query =
    qq|SELECT d.id, d.description, d.itime::timestamp(0) AS itime, | .
    qq|  e.name AS employee_name | .
    qq|FROM drafts d | .
    qq|LEFT JOIN employee e ON d.employee_id = e.id | .
    qq|WHERE (d.module = ?) AND (d.submodule = ?) | .
    qq|ORDER BY d.itime|;
  @values = ($module, $submodule);

  $sth = prepare_execute_query($form, $dbh, $query, @values);

  while (my $ref = $sth->fetchrow_hashref()) {
    push(@list, $ref);
  }
  $sth->finish();

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return @list;
}

1;
