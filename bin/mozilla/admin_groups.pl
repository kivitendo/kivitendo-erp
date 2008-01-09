sub edit_groups {
  $lxdebug->enter_sub();

  my @groups = sort { lc $a->{name} cmp lc $b->{name} } values %{ $auth->read_groups() };

  $form->header();
  print $form->parse_html_template("admin/edit_groups", { 'GROUPS'     => \@groups,
                                                          'num_groups' => scalar @groups });

  $lxdebug->leave_sub();
}

sub add_group {
  $lxdebug->enter_sub();

  delete $form->{group_id};
  $form->{message} = $locale->text("The group has been added.");

  save_group();

  $lxdebug->leave_sub();
}

sub save_group {
  $lxdebug->enter_sub();

  $form->isblank('name', $locale->text('The group name is missing.'));

  my $groups = $auth->read_groups();

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

  $auth->save_group($group);

  $form->{message} ||= $locale->text('The group has been saved.');

  if ($is_new) {
    edit_groups();

  } else {
    edit_group();
  }

  $lxdebug->leave_sub();
}

sub edit_group {
  $lxdebug->enter_sub();

  my $groups = $auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text("No group has been selected, or the group does not exist anymore."));
  }

  $group = $groups->{$form->{group_id}};

  my %all_users   = $auth->read_all_users();
  my %users_by_id = map { $_->{id} => $_ } values %all_users;

  my @members     = sort { lc $a->{login} cmp lc $b->{login} } @users_by_id{ @{ $group->{members} } };

  my %grouped     = map { $_ => 1 } @{ $group->{members} };
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

  $lxdebug->leave_sub();
}

sub delete_group {
  $lxdebug->enter_sub();

  my $groups = $auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text("No group has been selected, or the group does not exist anymore."));
  }

  if ($form->{confirmed}) {
    $auth->delete_group($form->{"group_id"});

    $form->{message} = $locale->text("The group has been deleted.");
    edit_groups();

  } else {

    $form->header();
    print $form->parse_html_template("admin/delete_group_confirm", $groups->{$form->{group_id}});
  }

  $lxdebug->leave_sub();
}

sub add_to_group {
  $lxdebug->enter_sub();

  $form->isblank('user_id_not_in_group', $locale->text('No user has been selected.'));

  my $groups = $auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text('No group has been selected, or the group does not exist anymore.'));
  }

  $group = $groups->{$form->{group_id}};
  push @{ $group->{members} }, $form->{user_id_not_in_group};

  $auth->save_group($group);

  $form->{message} = $locale->text('The user has been added to this group.');
  edit_group();

  $lxdebug->leave_sub();
}

sub remove_from_group {
  $lxdebug->enter_sub();

  $form->isblank('user_id_in_group', $locale->text('No user has been selected.'));

  my $groups = $auth->read_groups();

  if (!$form->{group_id} || !$groups->{$form->{group_id}}) {
    $form->show_generic_error($locale->text('No group has been selected, or the group does not exist anymore.'));
  }

  $group            = $groups->{$form->{group_id}};
  $group->{members} = [ grep { $_ ne $form->{user_id_in_group} } @{ $group->{members} } ];

  $auth->save_group($group);

  $form->{message} = $locale->text('The user has been removed from this group.');
  edit_group();

  $lxdebug->leave_sub();
}

sub edit_group_membership {
  $lxdebug->enter_sub();

  my %users  = $auth->read_all_users();
  my $groups = $auth->read_groups();
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

  $lxdebug->leave_sub();
}

sub save_group_membership {
  $lxdebug->enter_sub();

  my %users  = $auth->read_all_users();
  my $groups = $auth->read_groups();

  foreach my $group (values %{ $groups }) {
    $group->{members} = [ ];

    foreach my $user (values %users) {
      push @{ $group->{members} }, $user->{id} if ($form->{"u_$user->{id}_g_$group->{id}"});
    }

    $auth->save_group($group);
  }

  $form->{message} = $locale->text('The group memberships have been saved.');

  edit_groups();

  $lxdebug->leave_sub();
}

1;
