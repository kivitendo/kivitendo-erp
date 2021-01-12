use POSIX qw(strftime);

use SL::FU;
use SL::Locale::String qw(t8);
use SL::ReportGenerator;

require "bin/mozilla/reportgenerator.pl";

use strict;

sub _collect_links {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $dest = shift;

  my $form     = $main::form;

  $dest->{LINKS} = [];

  foreach my $i (1 .. $form->{trans_rowcount}) {
    next if (!$form->{"trans_id_$i"} || !$form->{"trans_type_$i"});

    push @{ $dest->{LINKS} }, { map { +"trans_$_" => $form->{"trans_${_}_$i"} } qw(id type info) };
  }

  $main::lxdebug->leave_sub();
}

sub add {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _collect_links($form);

  $form->get_employee($form->get_standard_dbh(\%myconfig));
  $form->{created_for_user} = $form->{employee_id};

  $form->{subject} = $form->{trans_subject_1} if $form->{trans_subject_1};

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

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

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

  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;

  $form->get_lists("employees" => "EMPLOYEES");

  my %params;
  $params{not_id}     = $form->{id} if ($form->{id});
  $params{trans_id}   = $form->{LINKS}->[0]->{trans_id} if (@{ $form->{LINKS} });
  $form->{FOLLOW_UPS} = FU->follow_ups(%params);

  setup_fu_display_form_action_bar() unless $::form->{POPUP_MODE};

  $form->header(no_layout => $::form->{POPUP_MODE});
  print $form->parse_html_template('fu/add_edit');

  $main::lxdebug->leave_sub();
}

sub save_follow_up {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->isblank('created_for_user', $locale->text('You must chose a user.'));
  $form->isblank('follow_up_date',   $locale->text('The follow-up date is missing.'));
  $form->isblank('subject',          $locale->text('The subject is missing.'));

  my %params = (map({ $_ => $form->{$_} } qw(id subject body note_id created_for_user follow_up_date)), 'done' => 0);

  _collect_links(\%params);

  FU->save(%params);

  if ($form->{POPUP_MODE}) {
    $form->header();
    print $form->parse_html_template('fu/close_window');
    $::dispatcher->end_request;
  }

  $form->{SAVED_MESSAGE} = $locale->text('Follow-Up saved.');

  if ($form->{callback}) {
    $form->redirect();
  }

  delete @{$form}{qw(id subject body created_for_user follow_up_date)};

  map { $form->{$_} = 1 } qw(due_only all_users not_done);

  report();

  $main::lxdebug->leave_sub();
}

sub finish {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

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
    $::dispatcher->end_request;
  }

  $form->redirect() if ($form->{callback});

  report();

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

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
    $::dispatcher->end_request;
  }

  $form->redirect() if ($form->{callback});

  report();

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists("employees" => "EMPLOYEES");

  $form->{title}    = $locale->text('Follow-Ups');

  setup_fu_search_action_bar();
  $form->header();
  print $form->parse_html_template('fu/search');

  $main::lxdebug->leave_sub();
}

sub report {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

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

  $report->set_export_options('report', @report_params, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  $report->set_options('raw_top_info_text'    => $form->parse_html_template('fu/report_top',    { 'OPTIONS' => \@options }),
                       'raw_bottom_info_text' => $form->parse_html_template('fu/report_bottom', { 'HIDDEN'  => \@hidden_report_params }),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('follow_up_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

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

  setup_fu_report_action_bar();
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub report_for_todo_list {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;

  my @report_params = qw(created_for subject body reference follow_up_date_from follow_up_date_to itime_from itime_to due_only all_users done not_done);

  my %params   = (
    'due_only'          => 1,
    'not_done'          => 1,
    'created_for_login' => $::myconfig{login},
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

  $main::lxdebug->leave_sub();

  return $content;
}

sub edit_access_rights {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $access = FU->retrieve_access_rights();

  $form->{EMPLOYEES} = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);

  map { $_->{access} = $access->{$_->{id}} } @{ $form->{EMPLOYEES} };

  $form->{title} = $locale->text('Edit Access Rights for Follow-Ups');

  setup_fu_edit_access_rights_action_bar();

  $form->header();
  print $form->parse_html_template('fu/edit_access_rights');

  $main::lxdebug->leave_sub();
}

sub save_access_rights {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

  my %access;

  foreach my $i (1 .. $form->{rowcount}) {
    my $id = $form->{"employee_id_$i"};

    $access{$id} = 1 if ($id && $form->{"access_$id"});
  }

  FU->save_access_rights('access' => \%access);

  $form->{SAVED_MESSAGE} = $locale->text('The access rights have been saved.');
  edit_access_rights();

  $main::lxdebug->leave_sub();
}

sub update {
  call_sub($main::form->{nextsub});
}

sub continue {
  call_sub($main::form->{nextsub});
}

sub save {
  $main::auth->assert('productivity');

  if ($main::form->{save_nextsub}) {
    call_sub($main::form->{save_nextsub});
  } else {
    save_follow_up();
  }
}

sub dispatcher {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  foreach my $action (qw(finish save delete)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  call_sub($form->{default_action}) if ($form->{default_action});

  $form->error($locale->text('No action defined.'));
}

sub setup_fu_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form', { action => "report" } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_fu_display_form_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save" } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Finish'),
        submit   => [ '#form', { action => "finish" } ],
        disabled => !$::form->{id} ? t8('The object has not been saved yet.') : undef,
      ],
      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "delete" } ],
        disabled => !$::form->{id} ? t8('The object has not been saved yet.') : undef,
        confirm  => t8('Do you really want to delete this object?'),
      ],
    );
  }
}

sub setup_fu_report_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Finish'),
        submit => [ '#form', { action => "finish" } ],
        checks => [ [ 'kivi.check_if_entries_selected', '[name^=selected_]' ] ],
      ],
      action => [
        t8('Delete'),
        submit  => [ '#form', { action => "delete" } ],
        checks  => [ [ 'kivi.check_if_entries_selected', '[name^=selected_]' ] ],
        confirm => t8('Do you really want to delete the selected objects?'),
      ],
    );
  }
}

sub setup_fu_edit_access_rights_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save_access_rights" } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
