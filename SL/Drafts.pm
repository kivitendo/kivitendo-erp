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

my @dont_save = qw(login password action);

sub dont_save {
  return @dont_save;
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $draft_id, $draft_description) = @_;

  my ($dbh, $sth, $query, %saved, $dumped);

  $dbh = $form->get_standard_dbh;
  $dbh->begin_work;

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

  $form->{draft_id}          = $draft_id;
  $form->{draft_description} = $draft_description;

  $main::lxdebug->leave_sub();
}

sub load {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $draft_id) = @_;

  my ($dbh, $sth, $query, @values);

  $dbh = $form->get_standard_dbh;

  $query = qq|SELECT id, description, form FROM drafts WHERE id = ?|;

  $sth = prepare_execute_query($form, $dbh, $query, $draft_id);

  if (my $ref = $sth->fetchrow_hashref()) {
    @values = ($ref->{form}, $ref->{id}, $ref->{description});
  }
  $sth->finish();

  $main::lxdebug->leave_sub();

  return @values;
}

sub remove {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, @draft_ids) = @_;

  return $main::lxdebug->leave_sub() unless (@draft_ids);

  my ($dbh, $sth, $query);

  $dbh = $form->get_standard_dbh;

  $query = qq|DELETE FROM drafts WHERE id IN (| . join(", ", map { "?" } @draft_ids) . qq|)|;
  do_query($form, $dbh, $query, @draft_ids);

  $dbh->commit;

  $main::lxdebug->leave_sub();
}

sub list {
  $::lxdebug->enter_sub;

  my $self     = shift;
  my $myconfig = shift || \%::myconfig;
  my $form     = shift ||  $::form;
  my $dbh      = $form->get_standard_dbh;

  my @list = selectall_hashref_query($form, $dbh, <<SQL, $self->get_module($form));
    SELECT d.id, d.description, d.itime::timestamp(0) AS itime,
      e.name AS employee_name
    FROM drafts d
    LEFT JOIN employee e ON d.employee_id = e.id
    WHERE (d.module = ?) AND (d.submodule = ?)
    ORDER BY d.itime
SQL

  $::lxdebug->leave_sub;

  return @list;
}

1;
