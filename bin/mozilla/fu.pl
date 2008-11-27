use POSIX qw(strftime);

use SL::FU;
use SL::ReportGenerator;

require "bin/mozilla/reportgenerator.pl";

sub _collect_links {
  $lxdebug->enter_sub();

  my $dest = shift;

  $dest->{LINKS} = [];

  foreach my $i (1 .. $form->{trans_rowcount}) {
    next if (!$form->{"trans_id_$i"} || !$form->{"trans_type_$i"});

    push @{ $dest->{LINKS} }, { map { +"trans_$_" => $form->{"trans_${_}_$i"} } qw(id type info) };
  }

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  _collect_links($form);

  $form->get_employee($form->get_standard_dbh(\%myconfig));
  $form->{created_for_user} = $form->{employee_id};

  my $link_details;

  if (0 < scalar @{ $form->{LINKS} }) {
    $link_details = FU->link_details(%{ $form->{LINKS}->[0] });
  }

  if ($link_details && $link_details->{title}) {
    $form->{title} = $locale->text('Add Follow-Up for #1', $link_details->{title});
  } else {
    $form->{title} = $locale->text('Add Follow-Up');
  }

  display_form();

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  my $ref = FU->retrieve('id' => $form->{id});

  if (!$ref) {
    $form->error($locale->text("Invalid follow-up ID."));
  }

  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  if (@{ $form->{LINKS} } && $form->{LINKS}->[0]->{title}) {
    $form->{title} = $locale->text('Edit Follow-Up for #1', $form->{LINKS}->[0]->{title});
  } else {
    $form->{title} = $locale->text('Edit Follow-Up');
  }

  display_form();

  $lxdebug->leave_sub();
}

sub display_form {
  $lxdebug->enter_sub();

  $form->get_lists("employees" => "EMPLOYEES");

  my %params;
  $params{not_id}     = $form->{id} if ($form->{id});
  $params{trans_id}   = $form->{LINKS}->[0]->{trans_id} if (@{ $form->{LINKS} });
  $form->{FOLLOW_UPS} = FU->follow_ups(%params);

  $form->{jsscript}   = 1;

  $form->header();
  print $form->parse_html_template('fu/add_edit');

  $lxdebug->leave_sub();
}

sub save_follow_up {
  $lxdebug->enter_sub();

  $form->isblank('created_for_user', $locale->text('You must chose a user.'));
  $form->isblank('follow_up_date',   $locale->text('The follow-up date is missing.'));
  $form->isblank('subject',          $locale->text('The subject is missing.'));

  my %params = (map({ $_ => $form->{$_} } qw(id subject body note_id created_for_user follow_up_date)), 'done' => 0);

  _collect_links(\%params);

  FU->save(%params);

  if ($form->{POPUP_MODE}) {
    $form->header();
    print $form->parse_html_template('fu/close_window');
    exit 0;
  }

  $form->{SAVED_MESSAGE} = $locale->text('Follow-Up saved.');

  if ($form->{callback}) {
    $form->redirect();
  }

  delete @{$form}{qw(id subject body created_for_user follow_up_date)};

  map { $form->{$_} = 1 } qw(due_only all_users not_done);

  report();

  $lxdebug->leave_sub();
}

sub finish {
  $lxdebug->enter_sub();

  if ($form->{id}) {
    my $ref = FU->retrieve('id' => $form->{id});

    if (!$ref) {
      $form->error($locale->text("Invalid follow-up ID."));
    }

    FU->finish('id' => $form->{id});

  } else {
    foreach my $i (1..$form->{rowcount}) {
      next unless ($form->{"selected_$i"} && $form->{"follow_up_id_$i"});

      FU->finish('id' => $form->{"follow_up_id_$i"});
    }
  }

  if ($form->{POPUP_MODE}) {
    $form->header();
    print $form->parse_html_template('fu/close_window');
    exit 0;
  }

  $form->redirect() if ($form->{callback});

  report();

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  if ($form->{id}) {
    my $ref = FU->retrieve('id' => $form->{id});

    if (!$ref) {
      $form->error($locale->text("Invalid follow-up ID."));
    }

    FU->delete('id' => $form->{id});

  } else {
    foreach my $i (1..$form->{rowcount}) {
      next unless ($form->{"selected_$i"} && $form->{"follow_up_id_$i"});

      FU->delete('id' => $form->{"follow_up_id_$i"});
    }
  }

  if ($form->{POPUP_MODE}) {
    $form->header();
    print $form->parse_html_template('fu/close_window');
    exit 0;
  }

  $form->redirect() if ($form->{callback});

  report();

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $form->get_lists("employees" => "EMPLOYEES");

  $form->{jsscript} = 1;
  $form->{title}    = $locale->text('Follow-Ups');

  $form->header();
  print $form->parse_html_template('fu/search');

  $lxdebug->leave_sub();
}

sub report {
  $lxdebug->enter_sub();

  my @report_params = qw(created_for subject body reference follow_up_date_from follow_up_date_to itime_from itime_to due_only all_users done not_done);

  report_generator_set_default_sort('follow_up_date', 1);

  my $follow_ups    = FU->follow_ups(map { $_ => $form->{$_} } @report_params);
  $form->{rowcount} = scalar @{ $follow_ups };

  $form->{title}    = $locale->text('Follow-Ups');

  my %column_defs = (
    'selected'              => { 'text' => '', },
    'follow_up_date'        => { 'text' => $locale->text('Follow-Up Date'), },
    'created_on'            => { 'text' => $locale->text('Created on'), },
    'title'                 => { 'text' => $locale->text('Reference'), },
    'subject'               => { 'text' => $locale->text('Subject'), },
    'created_by_name'       => { 'text' => $locale->text('Created by'), },
    'created_for_user_name' => { 'text' => $locale->text('Follow-up for'), },
    'done'                  => { 'text' => $locale->text('Done'), 'visible' => $form->{done} && $form->{not_done} ? 1 : 0 },
  );

  my @columns = qw(selected follow_up_date created_on subject title created_by_name created_for_user_name done);
  my $href    = build_std_url('action=report', grep { $form->{$_} } @report_params);

  foreach my $name (qw(follow_up_date created_on title subject)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my @options;

  if ($form->{created_for}) {
    $form->get_lists("employees" => "EMPLOYEES");

    foreach my $employee (@{ $form->{EMPLOYEES} }) {
      if ($employee->{id} == $form->{created_for}) {
        push @options, $locale->text('Created for') . " : " . ($employee->{name} ? "$employee->{name} ($employee->{login})" : $employee->{login});
        last;
      }
    }
  }

  push @options, $locale->text('Subject')                  . " : $form->{subject}"   if ($form->{subject});
  push @options, $locale->text('Body')                     . " : $form->{body}"      if ($form->{body});
  push @options, $locale->text('Reference')                . " : $form->{reference}" if ($form->{reference});
  push @options, $locale->text('Done')                                               if ($form->{done});
  push @options, $locale->text('Not done yet')                                       if ($form->{not_done});
  push @options, $locale->text('Only due follow-ups')                                if ($form->{due_only});
  push @options, $locale->text("Other users' follow-ups")                            if ($form->{all_users});

  my @hidden_report_params = map { +{ 'key' => $_, 'value' => $form->{$_} } } @report_params;

  my $report = SL::ReportGenerator->new(\%myconfig, $form, 'std_column_visibility' => 1);

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('report', @report_params);

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  $report->set_options('raw_top_info_text'    => $form->parse_html_template('fu/report_top',    { 'OPTIONS' => \@options }),
                       'raw_bottom_info_text' => $form->parse_html_template('fu/report_bottom', { 'HIDDEN'  => \@hidden_report_params }),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('follow_up_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  my $idx      = 0;
  my $callback = build_std_url('action=report', grep { $form->{$_} } @report_params);
  my $edit_url = build_std_url('action=edit', 'callback=' . E($callback));

  foreach my $fu (@{ $follow_ups }) {
    $idx++;

    $fu->{done} = $fu->{done} ? $locale->text('Yes') : $locale->text('No');

    my $row = { map { $_ => { 'data' => $fu->{$_} } } keys %{ $fu } };

    $row->{selected} = {
      'raw_data' =>   $cgi->hidden('-name' => "follow_up_id_${idx}", '-value' => $fu->{id})
                    . $cgi->checkbox('-name' => "selected_${idx}",   '-value' => 1, '-label' => ''),
      'valign'   => 'center',
      'align'    => 'center',
    };

    if (@{ $fu->{LINKS} }) {
      my $link = $fu->{LINKS}->[0];

      $row->{title}->{data} = $link->{title};
      $row->{title}->{link} = $link->{url};
    }

    $row->{subject}->{link} = $edit_url . '&id=' . Q($fu->{id});

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub report_for_todo_list {
  $lxdebug->enter_sub();

  my @report_params = qw(created_for subject body reference follow_up_date_from follow_up_date_to itime_from itime_to due_only all_users done not_done);

  my %params   = (
    'due_only'          => 1,
    'not_done'          => 1,
    'created_for_login' => $form->{login},
    );

  my $follow_ups = FU->follow_ups(%params);
  my $content;

  if (@{ $follow_ups }) {
    my $callback = build_std_url('action');
    my $edit_url = build_std_url('script=fu.pl', 'action=edit', 'callback=' . E($callback)) . '&id=';

    foreach my $fu (@{ $follow_ups }) {
      if (@{ $fu->{LINKS} }) {
        my $link = $fu->{LINKS}->[0];

        $fu->{reference}      = $link->{title};
        $fu->{reference_link} = $link->{url};
      }
    }

    $content = $form->parse_html_template('fu/report_for_todo_list', { 'FOLLOW_UPS' => $follow_ups,
                                                                       'callback'   => $callback,
                                                                       'edit_url'   => $edit_url, });
  }

  $lxdebug->leave_sub();

  return $content;
}

sub edit_access_rights {
  $lxdebug->enter_sub();

  my $access = FU->retrieve_access_rights();

  $form->get_lists("employees" => "EMPLOYEES");

  map { $_->{access} = $access->{$_->{id}} } @{ $form->{EMPLOYEES} };

  $form->{title} = $locale->text('Edit Access Rights for Follow-Ups');

  $form->header();
  print $form->parse_html_template('fu/edit_access_rights');

  $lxdebug->leave_sub();
}

sub save_access_rights {
  $lxdebug->enter_sub();

  my %access;

  foreach my $i (1 .. $form->{rowcount}) {
    my $id = $form->{"employee_id_$i"};

    $access{$id} = 1 if ($id && $form->{"access_$id"});
  }

  FU->save_access_rights('access' => \%access);

  $form->{SAVED_MESSAGE} = $locale->text('The access rights have been saved.');
  edit_access_rights();

  $lxdebug->leave_sub();
}

sub update {
  call_sub($form->{nextsub});
}

sub continue {
  call_sub($form->{nextsub});
}

sub save {
  if ($form->{save_nextsub}) {
    call_sub($form->{save_nextsub});
  } else {
    save_follow_up();
  }
}

sub dispatcher {
  foreach my $action (qw(finish save delete)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  call_sub($form->{default_action}) if ($form->{default_action});

  $form->error($locale->text('No action defined.'));
}

1;
