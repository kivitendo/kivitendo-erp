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
# administration
#
#======================================================================

use SL::AM;
use SL::CVar;
use SL::Form;

use Data::Dumper;

1;

require "bin/mozilla/common.pl";

# end of main

our %translations = ('text'      => $locale->text('Free-form text'),
                     'textfield' => $locale->text('Text field'),
                     'number'    => $locale->text('Number'),
                     'date'      => $locale->text('Date'),
                     'timestamp' => $locale->text('Timestamp'),
                     'bool'      => $locale->text('Yes/No (Checkbox)'),
                     'select'    => $locale->text('Selection'),
                     );

our @types = qw(text textfield number date bool select); # timestamp

sub add {
  add_cvar_config();
}

sub edit {
  edit_cvar_config();
}

sub list_cvar_configs {
  $lxdebug->enter_sub();

  $auth->assert('config');

  $form->{module} ||= $form->{cvar_module};

  my @configs = grep { $_->{module} eq $form->{module} } @{ CVar->get_configs() };

  my $previous_config;

  foreach my $config (@configs) {
    $config->{type_tr} = $translations{$config->{type}};

    foreach my $flag (split m/:/, $config->{flags}) {
      if ($flag =~ m/(.*?)=(.*)/) {
        $config->{"flag_${1}"}    = $2;
      } else {
        $config->{"flag_${flag}"} = 1;
      }
    }

    if ($previous_config) {
      $previous_config->{next_id} = $config->{id};
      $config->{previous_id}      = $previous_config->{id};
    }

    $previous_config = $config;
  }

  $form->{title} = $locale->text('List of custom variables');
  $form->header();
  print $form->parse_html_template('amcvar/list_cvar_configs', { 'CONFIGS' => \@configs });

  $lxdebug->leave_sub();
}

sub add_cvar_config {
  $lxdebug->enter_sub();

  $auth->assert('config');

  $form->{module} ||= $form->{cvar_module};

  $form->{edit} = 0;
  display_cvar_config_form();

  $lxdebug->leave_sub();
}

sub edit_cvar_config {
  $lxdebug->enter_sub();

  $auth->assert('config');

  my $config = CVar->get_config('id' => $form->{id});

  map { $form->{$_} = $config->{$_} } keys %{ $config };

  $form->{edit} = 1;
  display_cvar_config_form();

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  $auth->assert('config');

  $form->isblank('name',        $locale->text('The name is missing.'));
  $form->isblank('description', $locale->text('The description is missing.'));
  $form->isblank('options',     $locale->text('The option field is empty.')) if ($form->{type} eq 'select');

  if ($form->{name} !~ /^[a-z][a-z0-9_]*$/i) {
    $form->error($locale->text('The name must only consist of letters, numbers and underscores and start with a letter.'));
  }

  if (($form->{type} eq 'number') && ($form->{default_value} ne '')) {
    $form->{default_value} = $form->parse_amount(\%myconfig, $form->{default_value});
  }

  $form->{included_by_default} = $form->{inclusion} eq 'yes_default_on';
  $form->{includeable}         = $form->{inclusion} ne 'no';
  $form->{flags}               = join ':', map { m/^flag_(.*)/; "${1}=" . $form->{$_} } grep { m/^flag_/ } keys %{ $form };

  CVar->save_config('module' => $form->{module},
                    'config' => $form);

  $form->{MESSAGE} = $locale->text('The custom variable has been saved.');

  list_cvar_configs();

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  CVar->delete_config('id' => $form->{id});

  $form->{MESSAGE} = $locale->text('The custom variable has been deleted.');

  list_cvar_configs();

  $lxdebug->leave_sub();
}

sub display_cvar_config_form {
  $lxdebug->enter_sub();

  $auth->assert('config');

  my @types = map { { 'type' => $_, 'type_tr' => $translations{$_} } } @types;

  if (($form->{type} eq 'number') && ($form->{default_value} ne '')) {
    $form->{default_value} = $form->format_amount(\%myconfig, $form->{default_value});
  }

  $form->{title} = $form->{edit} ? $locale->text("Edit custom variable") : $locale->text("Add custom variable");

  $form->header();
  print $form->parse_html_template("amcvar/display_cvar_config_form", { 'TYPES' => \@types });

  $lxdebug->leave_sub();
}

sub swap_cvar_configs {
  $lxdebug->enter_sub();

  AM->swap_sortkeys(\%myconfig, $form, 'custom_variable_configs');

  list_cvar_configs();

  $lxdebug->leave_sub();
}

1;
