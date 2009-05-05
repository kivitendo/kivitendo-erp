#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
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
# project administration
#======================================================================

use POSIX qw(strftime);

use SL::CVar;
use SL::Projects;
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

sub add {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  # construct callback
  $form->{callback} = build_std_url('action') unless $form->{callback};

  display_project_form();

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  $form->{title} = "Edit";

  $form->{project} = Projects->get_project('id' => $form->{id}, 'orphaned' => 1);

  display_project_form();

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  $form->{title} = $locale->text('Projects');

  $form->{CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'Projects');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CUSTOM_VARIABLES},
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  $form->header();
  print $form->parse_html_template('projects/search');

  $lxdebug->leave_sub();
}

sub project_report {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  $form->{sort} ||= 'projectnumber';
  my $filter      = $form->{filter} || { };

  Projects->search_projects(%{ $filter }, 'sort' => $form->{sort});

  my $cvar_configs = CVar->get_configs('module' => 'Projects');

  my $report       = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns      = qw(projectnumber description active);
  my @hidden_vars  = ('filter');
  my $href         = build_std_url('action=project_report', @hidden_vars);

  my @includeable_custom_variables = grep { $_->{includeable} } @{ $cvar_configs };
  my %column_defs_cvars            = ();
  foreach (@includeable_custom_variables) {
    $column_defs_cvars{"cvar_$_->{name}"} = {
      'text'    => $_->{description},
      'visible' => $form->{"l_cvar_$_->{name}"} eq 'Y',
    };
  }

  push @columns, map { "cvar_$_->{name}" } @includeable_custom_variables;

  my %column_defs  = (
    'projectnumber'            => { 'text' => $locale->text('Number'), },
    'description'              => { 'text' => $locale->text('Description'), },
    'active'                   => { 'text' => $locale->text('Active'), 'visible' => 'both' eq $filter->{active}, },
    %column_defs_cvars,
    );

  foreach (qw(projectnumber description)) {
    $column_defs{$_}->{link}    = $href . "&sort=$_";
    $column_defs{$_}->{visible} = 1;
  }

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('project_report', @hidden_vars, 'sort');

  $report->set_sort_indicator($form->{sort}, 1);

  my @options;
  push @options, $locale->text('All')                                            if ($filter->{all});
  push @options, $locale->text('Orphaned')                                       if ($filter->{orphaned});
  push @options, $locale->text('Project Number') . " : $filter->{projectnumber}" if ($filter->{projectnumber});
  push @options, $locale->text('Description') . " : $filter->{description}"      if ($filter->{description});
  push @options, $locale->text('Active')                                         if ($filter->{active} eq 'active');
  push @options, $locale->text('Inactive')                                       if ($filter->{active} eq 'inactive');
  push @options, $locale->text('Orphaned')                                       if ($filter->{status} eq 'orphaned');

  $form->{title} = $locale->text('Projects');

  $report->set_options('top_info_text'       => join("\n", @options),
                       'output_format'       => 'HTML',
                       'title'               => $form->{title},
                       'attachment_basename' => $locale->text('project_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  CVar->add_custom_variables_to_report('module'         => 'Projects',
                                       'trans_id_field' => 'id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{project_list});

  my $edit_url = build_std_url('action=edit&type=project');
  my $callback = $form->escape($href) . '&sort=' . E($form->{sort});

  foreach $project (@{ $form->{project_list} }) {
    $project->{active} = $project->{active} ? $locale->text('Yes')  : $locale->text('No');

    my $row = { map { $_ => { 'data' => $project->{$_} } } keys %{ $project } };

    $row->{projectnumber}->{link} = $edit_url . "&id=" . E($project->{id}) . "&callback=${callback}";

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub display_project_form {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  $form->{project} ||= { };

  $form->{title}     = $form->{project}->{id} ? $locale->text("Edit Project") : $locale->text("Add Project");

  $form->{CUSTOM_VARIABLES} = CVar->get_custom_variables('module' => 'Projects', 'trans_id' => $form->{project}->{id});
  $main::lxdebug->dump(0, "cv", $form->{CUSTOM_VARIABLES});
  CVar->render_inputs('variables' => $form->{CUSTOM_VARIABLES}) if (scalar @{ $form->{CUSTOM_VARIABLES} });

  $form->header();
  print $form->parse_html_template('projects/project_form');

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  $form->isblank("project.projectnumber", $locale->text('Project Number missing!'));

  my $project    = $form->{project} || { };
  my $is_new     = !$project->{id};
  $project->{id} = Projects->save_project(%{ $project });

  # saving the history
  if(!exists $form->{addition} && $project->{id} ne "") {
    $form->{id}       = $project->{id};
    $form->{snumbers} = qq|projectnumber_| . $project->{projectnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  if ($form->{callback}) {
    map { $form->{callback} .= "&new_${_}=" . $form->escape($project->{$_}); } qw(projectnumber description id);
    my $message              = $is_new ? $locale->text('The project has been added.') : $locale->text('The project has been saved.');
    $form->{callback}       .= "&message="  . E($message);
  }

  $form->redirect($locale->text('Project saved!'));

  $lxdebug->leave_sub();
}

sub save_as_new {
  $lxdebug->enter_sub();

  delete $form->{project}->{id} if ($form->{project});
  save();

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $auth->assert('project_edit');

  my $project = $form->{project} || { };
  Projects->delete_project('id' => $project->{id});

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|projectnumber_| . $project->{projectnumber};
  	$form->{addition} = "DELETED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->redirect($locale->text('Project deleted!'));

  $lxdebug->leave_sub();
}

sub continue {
  call_sub($form->{nextsub});
}
