#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
#
#  Author: Moritz Bunkus
#   Email: mbunkus@linet-services.de
#     Web: www.linet-services.de
#
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
#======================================================================
#
# group administration module
# add/edit/delete user groups
#
#======================================================================

use List::MoreUtils qw(uniq);

use strict;

sub edit_groups {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my @groups = sort { lc $a->{name} cmp lc $b->{name} } values %{ $main::auth->read_groups() };

  $form->header();
  print $form->parse_html_template("admin/edit_groups", { 'GROUPS'     => \@groups,
                                                          'num_groups' => scalar @groups });

  $main::lxdebug->leave_sub();
}

sub add_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  delete $form->{group_id};
  $form->{message} = $locale->text("The group has been added.");

  save_group();

  $main::lxdebug->leave_sub();
}

sub save_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->isblank('name', $locale->text('The group name is missing.'));

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    if (($form->{group_id} != $group->{id})
        && ($form->{name} eq $group->{name})) {
      $form->show_generic_error($locale->text("A group with that name does already exist."));
    }
  }

  my $group;

  if ($form->{group_id} && $groups->{$form->{group_id}}) {
    $group = $groups->{$form->{group_id}};

  } else {
    $group = { };
  }

  $group->{name}        = $form->{name};
  $group->{description} = $form->{description};
  $group->{rights}      = {};

  map { $group->{rights}->{$_} = $form->{"${_}_granted"} ? 1 : 0 } SL::Auth::all_rights();

  my $is_new = !$form->{group_id};

  $main::auth->save_group($group);

  $form->{message} ||= $locale->text('The group has been saved.');

  if ($is_new) {
    edit_groups();

  } else {
    edit_group();
  }

  $main::lxdebug->leave_sub();
}

sub edit_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $groups = $main::auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text("No group has been selected, or the group does not exist anymore."));
  }

  my $group = $groups->{$form->{group_id}};

  my %all_users   = $main::auth->read_all_users();
  my %users_by_id = map { $_->{id} => $_ } values %all_users;

  my @members     = uniq sort { lc $a->{login} cmp lc $b->{login} } @users_by_id{ @{ $group->{members} } };

  my %grouped     = map { $_ => 1 } uniq @{ $group->{members} };
  my @non_members = sort { lc $a->{login} cmp lc $b->{login} } grep { !$grouped{$_->{id}} } values %all_users;

  my @rights = map {
    { "right"       => $_->[0],
      "description" => $_->[1],
      "is_section"  => '--' eq substr($_->[0], 0, 2),
      "granted"     => defined $group->{rights}->{$_->[0]} ? $group->{rights}->{$_->[0]} : 0,
    }
  } SL::Auth::all_rights_full();

  $form->header();
  print $form->parse_html_template("admin/edit_group", { "USERS_IN_GROUP"     => \@members,
                                                         "USERS_NOT_IN_GROUP" => \@non_members,
                                                         "RIGHTS"             => \@rights,
                                                         "name"               => $group->{name},
                                                         "description"        => $group->{description} });

  $main::lxdebug->leave_sub();
}

sub delete_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $groups = $main::auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text("No group has been selected, or the group does not exist anymore."));
  }

  if ($form->{confirmed}) {
    $main::auth->delete_group($form->{"group_id"});

    $form->{message} = $locale->text("The group has been deleted.");
    edit_groups();

  } else {

    $form->header();
    print $form->parse_html_template("admin/delete_group_confirm", $groups->{$form->{group_id}});
  }

  $main::lxdebug->leave_sub();
}

sub add_to_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->isblank('user_id_not_in_group', $locale->text('No user has been selected.'));

  my $groups = $main::auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text('No group has been selected, or the group does not exist anymore.'));
  }

  my $group = $groups->{$form->{group_id}};
  $group->{members} = [ uniq @{ $group->{members} }, $form->{user_id_not_in_group} ];

  $main::auth->save_group($group);

  $form->{message} = $locale->text('The user has been added to this group.');
  edit_group();

  $main::lxdebug->leave_sub();
}

sub remove_from_group {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->isblank('user_id_in_group', $locale->text('No user has been selected.'));

  my $groups = $main::auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text('No group has been selected, or the group does not exist anymore.'));
  }

  my $group            = $groups->{$form->{group_id}};
  $group->{members} = [ uniq grep { $_ ne $form->{user_id_in_group} } @{ $group->{members} } ];

  $main::auth->save_group($group);

  $form->{message} = $locale->text('The user has been removed from this group.');
  edit_group();

  $main::lxdebug->leave_sub();
}

sub edit_group_membership {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my %users  = $main::auth->read_all_users();
  my $groups = $main::auth->read_groups();
  $groups    = [ sort { lc $a->{name} cmp lc $b->{name} } values %{ $groups } ];

  my @headings = map { { 'title' => $_ } } map { $_->{name} } @{ $groups };

  foreach my $group (@{ $groups }) {
    $group->{members_h} = { map { $_ => 1 } @{ $group->{members} } };
  }

  my @rows;

  foreach my $user (sort { lc $a->{login} cmp lc $b->{login} } values %users) {
    my $row = {
      'id'              => $user->{id},
      'login'           => $user->{login},
      'name'            => $user->{name},
      'repeat_headings' => (scalar(@rows) % 20) == 0,
      'GROUPS'          => [],
    };

    foreach my $group (@{ $groups }) {
      push @{ $row->{GROUPS} }, {
        'id'        => $group->{id},
        'is_member' => $group->{members_h}->{$user->{id}},
      };
    }

    push @rows, $row;
  }

  $form->{title} = $locale->text('Edit group membership');
  $form->header();
  print $form->parse_html_template('admin/edit_group_membership', { 'HEADINGS' => \@headings, 'USERS' => \@rows });

  $main::lxdebug->leave_sub();
}

sub save_group_membership {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my %users  = $main::auth->read_all_users();
  my $groups = $main::auth->read_groups();

  foreach my $group (values %{ $groups }) {
    $group->{members} = [ ];

    foreach my $user (values %users) {
      push @{ $group->{members} }, $user->{id} if ($form->{"u_$user->{id}_g_$group->{id}"});
    }

    $main::auth->save_group($group);
  }

  $form->{message} = $locale->text('The group memberships have been saved.');

  edit_groups();

  $main::lxdebug->leave_sub();
}

1;
