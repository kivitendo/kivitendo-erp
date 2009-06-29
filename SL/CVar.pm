package CVar;

use List::Util qw(first);

use SL::DBUtils;

sub get_configs {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my ($where, @values);
  if ($params{module}) {
    $where = 'WHERE module = ?';
    push @values, $params{module};
  }

  my $query    = qq|SELECT * FROM custom_variable_configs $where ORDER BY sortkey|;

  my $configs  = selectall_hashref_query($form, $dbh, $query, @values);

  foreach my $config (@{ $configs }) {
    if ($config->{type} eq 'select') {
      $config->{OPTIONS} = [ map { { 'value' => $_ } } split(m/\#\#/, $config->{options}) ];

    } elsif ($config->{type} eq 'number') {
      $config->{precision} = $1 if ($config->{options} =~ m/precision=(\d+)/i);

    }
  }

  $main::lxdebug->leave_sub();

  return $configs;
}

sub get_config {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT * FROM custom_variable_configs WHERE id = ?|;

  my $config   = selectfirst_hashref_query($form, $dbh, $query, conv_i($params{id})) || { };

  $main::lxdebug->leave_sub();

  return $config;
}

sub save_config {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(module config));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $q_id     = qq|SELECT nextval('custom_variable_configs_id')|;
  my $h_id     = prepare_query($form, $dbh, $q_id);

  my $q_new    =
    qq|INSERT INTO custom_variable_configs (name, description, type, default_value, options, searchable, includeable, included_by_default, module, flags, id, sortkey)
       VALUES                              (?,    ?,           ?,    ?,             ?,       ?,          ?,           ?,                   ?,      ?,     ?,
         (SELECT COALESCE(MAX(sortkey) + 1, 1) FROM custom_variable_configs))|;
  my $h_new    = prepare_query($form, $dbh, $q_new);

  my $q_update =
    qq|UPDATE custom_variable_configs SET
         name        = ?, description         = ?,
         type        = ?, default_value       = ?,
         options     = ?, searchable          = ?,
         includeable = ?, included_by_default = ?,
         module      = ?, flags               = ?
       WHERE id  = ?|;
  my $h_update = prepare_query($form, $dbh, $q_update);

  my @configs;
  if ('ARRAY' eq ref $params{config}) {
    @configs = @{ $params{config} };
  } else {
    @configs = ($params{config});
  }

  foreach my $config (@configs) {
    my ($h_actual, $q_actual);

    if (!$config->{id}) {
      do_statement($form, $h_id, $q_id);
      ($config->{id}) = $h_id->fetchrow_array();

      $h_actual       = $h_new;
      $q_actual       = $q_new;

    } else {
      $h_actual       = $h_update;
      $q_actual       = $q_update;
    }

    do_statement($form, $h_actual, $q_actual, @{$config}{qw(name description type default_value options)},
                 $config->{searchable} ? 't' : 'f', $config->{includeable} ? 't' : 'f', $config->{included_by_default} ? 't' : 'f',
                 $params{module}, $config->{flags}, conv_i($config->{id}));
  }

  $h_id->finish();
  $h_new->finish();
  $h_update->finish();

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub delete_config {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  do_query($form, $dbh, qq|DELETE FROM custom_variables        WHERE config_id = ?|, conv_i($params{id}));
  do_query($form, $dbh, qq|DELETE FROM custom_variable_configs WHERE id        = ?|, conv_i($params{id}));

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub get_custom_variables {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(module));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $trans_id = $params{trans_id} ? 'OR (v.trans_id = ?) ' : '';

  my $q_cfg    =
    qq|SELECT id, name, description, type, default_value, options,
         date_trunc('seconds', localtimestamp) AS current_timestamp, current_date AS current_date
       FROM custom_variable_configs
       WHERE module = ?
       ORDER BY sortkey|;

  my $q_var    =
    qq|SELECT text_value, timestamp_value, timestamp_value::date AS date_value, number_value, bool_value
       FROM custom_variables
       WHERE (config_id = ?) AND (trans_id = ?)|;
  my $h_var    = prepare_query($form, $dbh, $q_var);

  my $custom_variables = selectall_hashref_query($form, $dbh, $q_cfg, $params{module});

  foreach my $cvar (@{ $custom_variables }) {
    if ($cvar->{type} eq 'textfield') {
      $cvar->{width}  = 30;
      $cvar->{height} =  5;

      $cvar->{width}  = $1 if ($cvar->{options} =~ m/width=(\d+)/i);
      $cvar->{height} = $1 if ($cvar->{options} =~ m/height=(\d+)/i);

    } elsif ($cvar->{type} eq 'text') {
      $cvar->{maxlength} = $1 if ($cvar->{options} =~ m/maxlength=(\d+)/i);

    } elsif ($cvar->{type} eq 'number') {
      $cvar->{precision} = $1 if ($cvar->{options} =~ m/precision=(\d+)/i);

    } elsif ($cvar->{type} eq 'select') {
      $cvar->{OPTIONS} = [ map { { 'value' => $_ } } split(m/\#\#/, $cvar->{options}) ];
    }

    my $act_var;
    if ($params{trans_id}) {
      do_statement($form, $h_var, $q_var, conv_i($cvar->{id}), conv_i($params{trans_id}));
      $act_var = $h_var->fetchrow_hashref();
    }

    if ($act_var) {
      $cvar->{value} = $cvar->{type} eq 'date'      ? $act_var->{date_value}
                     : $cvar->{type} eq 'timestamp' ? $act_var->{timestamp_value}
                     : $cvar->{type} eq 'number'    ? $act_var->{number_value}
                     : $cvar->{type} eq 'bool'      ? $act_var->{bool_value}
                     :                                $act_var->{text_value};

    } else {
      if ($cvar->{type} eq 'date') {
        if ($cvar->{default_value} eq 'NOW') {
          $cvar->{value} = $cvar->{current_date};
        } else {
          $cvar->{value} = $cvar->{default_value};
        }

      } elsif ($cvar->{type} eq 'timestamp') {
        if ($cvar->{default_value} eq 'NOW') {
          $cvar->{value} = $cvar->{current_timestamp};
        } else {
          $cvar->{value} = $cvar->{default_value};
        }

      } elsif ($cvar->{type} eq 'bool') {
        $cvar->{value} = $cvar->{default_value} * 1;

      } elsif ($cvar->{type} eq 'number') {
        $cvar->{value} = $cvar->{default_value} * 1 if ($cvar->{default_value} ne '');

      } else {
        $cvar->{value} = $cvar->{default_value};
      }
    }

    if ($cvar->{type} eq 'number') {
      $cvar->{value} = $form->format_amount($myconfig, $cvar->{value} * 1, $cvar->{precision});
    }
  }

  $h_var->finish();

  $main::lxdebug->leave_sub();

  return $custom_variables;
}

sub save_custom_variables {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(module trans_id variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @configs  = grep { $_->{module} eq $params{module} } @{ CVar->get_configs() };

  my $query    =
    qq|DELETE FROM custom_variables
       WHERE (trans_id  = ?)
         AND (config_id IN (SELECT DISTINCT id
                            FROM custom_variable_configs
                            WHERE module = ?))|;
  do_query($form, $dbh, $query, conv_i($params{trans_id}), $params{module});

  $query  =
    qq|INSERT INTO custom_variables (config_id, trans_id, bool_value, timestamp_value, text_value, number_value)
       VALUES                       (?,         ?,        ?,          ?,               ?,          ?)|;
  my $sth = prepare_query($form, $dbh, $query);

  foreach my $config (@configs) {
    my @values = (conv_i($config->{id}), conv_i($params{trans_id}));

    my $value  = $params{variables}->{"cvar_$config->{name}"};

    if (($config->{type} eq 'text') || ($config->{type} eq 'textfield') || ($config->{type} eq 'select')) {
      push @values, undef, undef, $value, undef;

    } elsif (($config->{type} eq 'date') || ($config->{type} eq 'timestamp')) {
      push @values, undef, conv_date($value), undef, undef;

    } elsif ($config->{type} eq 'number') {
      push @values, undef, undef, undef, conv_i($form->parse_amount($myconfig, $value));

    } elsif ($config->{type} eq 'bool') {
      push @values, $value ? 't' : 'f', undef, undef, undef;
    }

    do_statement($form, $sth, $query, @values);
  }

  $sth->finish();

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub render_inputs {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  foreach my $var (@{ $params{variables} }) {
    $var->{HTML_CODE} = $form->parse_html_template('amcvar/render_inputs', { 'var' => $var });
  }

  $main::lxdebug->leave_sub();
}

sub render_search_options {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  $params{include_prefix}   = 'l_' unless defined($params{include_prefix});
  $params{include_value}  ||= '1';

  my $filter  = $form->parse_html_template('amcvar/search_filter',  \%params);
  my $include = $form->parse_html_template('amcvar/search_include', \%params);

  $main::lxdebug->leave_sub();

  return ($filter, $include);
}

sub build_filter_query {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(module trans_id_field filter));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $configs  = $self->get_configs(%params);

  my (@where, @values);

  foreach my $config (@{ $configs }) {
    next unless ($config->{searchable});

    my $name = "cvar_$config->{name}";

    my (@sub_values, @sub_where, $not);

    if (($config->{type} eq 'text') || ($config->{type} eq 'textfield')) {
      next unless ($params{filter}->{$name});

      push @sub_where,  qq|cvar.text_value ILIKE ?|;
      push @sub_values, '%' . $params{filter}->{$name} . '%'

    } elsif ($config->{type} eq 'select') {
      next unless ($params{filter}->{$name});

      push @sub_where,  qq|cvar.text_value = ?|;
      push @sub_values, $params{filter}->{$name};

    } elsif (($config->{type} eq 'date') || ($config->{type} eq 'timestamp')) {
      my $name_from = "${name}_from";
      my $name_to   = "${name}_to";

      if ($params{filter}->{$name_from}) {
        push @sub_where,  qq|cvar.timestamp_value >= ?|;
        push @sub_values, conv_date($params{filter}->{$name_from});
      }

      if ($params{filter}->{$name_to}) {
        push @sub_where,  qq|cvar.timestamp_value <= ?|;
        push @sub_values, conv_date($params{filter}->{$name_to});
      }

    } elsif ($config->{type} eq 'number') {
      next if ($params{filter}->{$name} eq '');

      my $f_op = $params{filter}->{"${name}_qtyop"};

      if ($f_op eq '==') {
        $op  = '=';

      } elsif ($f_op eq '=/=') {
        $not = 'NOT';
        $op  = '<>';

      } elsif ($f_op eq '<') {
        $not = 'NOT';
        $op  = '>=';

      } elsif ($f_op eq '<=') {
        $not = 'NOT';
        $op  = '>';

      } elsif (($f_op eq '>') || ($f_op eq '>=')) {
        $op  = $f_op;

      } else {
        $op  = '=';
      }

      push @sub_where,  qq|cvar.number_value $op ?|;
      push @sub_values, $form->parse_amount($myconfig, $params{filter}->{$name});

    } elsif ($config->{type} eq 'bool') {
      next unless ($params{filter}->{$name});

      $not = 'NOT' if ($params{filter}->{$name} eq 'no');
      push @sub_where,  qq|COALESCE(cvar.bool_value, false) = TRUE|;
    }

    if (@sub_where) {
      push @where,
        qq|$not EXISTS(
             SELECT cvar.id
             FROM custom_variables cvar
             LEFT JOIN custom_variable_configs cvarcfg ON (cvar.config_id = cvarcfg.id)
             WHERE (cvarcfg.module = ?)
               AND (cvarcfg.id     = ?)
               AND (cvar.trans_id  = $params{trans_id_field})
               AND | . join(' AND ', map { "($_)" } @sub_where) . qq|)|;
      push @values, $params{module}, conv_i($config->{id}), @sub_values;
    }
  }

  my $query = join ' AND ', @where;

  $main::lxdebug->leave_sub();

  return ($query, @values);
}

sub add_custom_variables_to_report {
  $main::lxdebug->enter_sub();

  my $self      = shift;
  my %params    = @_;

  Common::check_params(\%params, qw(module trans_id_field column_defs data configs));

  my $myconfig  = \%main::myconfig;
  my $form      = $main::form;
  my $locale    = $main::locale;

  my $dbh       = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $configs   = [ grep { $_->{includeable} && $params{column_defs}->{"cvar_$_->{name}"}->{visible} } @{ $params{configs} } ];

  if (!scalar(@{ $params{data} }) || ! scalar(@{ $configs })) {
    $main::lxdebug->leave_sub();
    return;
  }

  my %cfg_map   = map { $_->{id} => $_ } @{ $configs };
  my @cfg_ids   = keys %cfg_map;

  my $query     =
    qq|SELECT text_value, timestamp_value, timestamp_value::date AS date_value, number_value, bool_value, config_id
       FROM custom_variables
       WHERE (config_id IN (| . join(', ', ('?') x scalar(@cfg_ids)) . qq|)) AND (trans_id = ?)|;
  my $sth       = prepare_query($form, $dbh, $query);

  foreach my $row (@{ $params{data} }) {
    do_statement($form, $sth, $query, @cfg_ids, conv_i($row->{$params{trans_id_field}}));

    while (my $ref = $sth->fetchrow_hashref()) {
      my $cfg = $cfg_map{$ref->{config_id}};

      $row->{"cvar_$cfg->{name}"} =
          $cfg->{type} eq 'date'      ? $ref->{date_value}
        : $cfg->{type} eq 'timestamp' ? $ref->{timestamp_value}
        : $cfg->{type} eq 'number'    ? $form->format_amount($myconfig, $ref->{number_value} * 1, $config->{precision})
        : $cfg->{type} eq 'bool'      ? ($ref->{bool_value} ? $locale->text('Yes') : $locale->text('No'))
        :                               $ref->{text_value};
    }
  }

  $sth->finish();

  $main::lxdebug->leave_sub();
}

sub get_field_format_list {
  $main::lxdebug->enter_sub();

  my $self          = shift;
  my %params        = @_;

  Common::check_params(\%params, qw(module));

  my $myconfig      = \%main::myconfig;
  my $form          = $main::form;

  my $dbh           = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $configs       = $self->get_configs(%params);

  my $date_fields   = [];
  my $number_fields = {};

  foreach my $config (@{ $configs }) {
    my $name = "$params{prefix}cvar_$config->{name}";

    if ($config->{type} eq 'date') {
      push @{ $date_fields }, $name;

    } elsif ($config->{type} eq 'number') {
      $number_fields->{$config->{precision}} ||= [];
      push @{ $number_fields->{$config->{precision}} }, $name;
    }
  }

  $main::lxdebug->leave_sub();

  return ($date_fields, $number_fields);
}


1;
