package CVar;

use strict;

use Carp;
use List::MoreUtils qw(any);
use List::Util qw(first);
use Scalar::Util qw(blessed);
use Data::Dumper;

use SL::DBUtils;
use SL::MoreCommon qw(listify);
use SL::Util qw(trim);
use SL::DB;

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

  my $query    = <<SQL;
    SELECT *, date_trunc('seconds', localtimestamp) AS current_timestamp
    FROM custom_variable_configs $where ORDER BY sortkey
SQL

  $::form->{CVAR_CONFIGS} = {} unless 'HASH' eq ref $::form->{CVAR_CONFIGS};
  if (!$::form->{CVAR_CONFIGS}->{$params{module}}) {
    my $configs  = selectall_hashref_query($form, $dbh, $query, @values);

    foreach my $config (@{ $configs }) {
      if ($config->{type} eq 'select') {
        $config->{OPTIONS} = [ map { { 'value' => $_ } } split(m/\#\#/, $config->{options}) ];

      } elsif ($config->{type} eq 'number') {
        $config->{precision} = $1 if ($config->{options} =~ m/precision=(\d+)/i);

      } elsif ($config->{type} eq 'textfield') {
        $config->{width}  = 30;
        $config->{height} =  5;
        $config->{width}  = $1 if ($config->{options} =~ m/width=(\d+)/i);
        $config->{height} = $1 if ($config->{options} =~ m/height=(\d+)/i);

      } elsif ($config->{type} eq 'text') {
        $config->{maxlength} = $1 if ($config->{options} =~ m/maxlength=(\d+)/i);

      }

      $self->_unpack_flags($config);

      my $cvar_config = SL::DB::CustomVariableConfig->new(id => $config->{id})->load;
      @{$config->{'partsgroups'}} = map {$_->id} @{$cvar_config->partsgroups};

    }
    $::form->{CVAR_CONFIGS}->{$params{module}} = $configs;
  }

  $main::lxdebug->leave_sub();

  return $::form->{CVAR_CONFIGS}->{$params{module}};
}

sub _unpack_flags {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my $config = shift;

  foreach my $flag (split m/:/, $config->{flags}) {
    if ($flag =~ m/(.*?)=(.*)/) {
      $config->{"flag_${1}"}    = $2;
    } else {
      $config->{"flag_${flag}"} = 1;
    }
  }

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

  my $sub_module = $params{sub_module} ? $params{sub_module} : '';

  my $q_var    =
    qq|SELECT text_value, timestamp_value, timestamp_value::date AS date_value, number_value, bool_value
       FROM custom_variables
       WHERE (config_id = ?) AND (trans_id = ?) AND (sub_module = ?)|;
  my $h_var    = prepare_query($form, $dbh, $q_var);

  my $custom_variables = $self->get_configs(module => $params{module});

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

    my ($act_var, $valid);
    if ($params{trans_id}) {
      my @values = (conv_i($cvar->{id}), conv_i($params{trans_id}), $sub_module);

      do_statement($form, $h_var, $q_var, @values);
      $act_var = $h_var->fetchrow_hashref();

      $valid = $self->get_custom_variables_validity(config_id => $cvar->{id}, trans_id => $params{trans_id}, sub_module => $params{sub_module});
    } else {
      $valid = !$cvar->{flag_defaults_to_invalid};
    }

    if ($act_var) {
      $cvar->{value} = $cvar->{type} eq 'date'      ? $act_var->{date_value}
                     : $cvar->{type} eq 'timestamp' ? $act_var->{timestamp_value}
                     : $cvar->{type} eq 'number'    ? $act_var->{number_value}
                     : $cvar->{type} eq 'customer'  ? $act_var->{number_value}
                     : $cvar->{type} eq 'vendor'    ? $act_var->{number_value}
                     : $cvar->{type} eq 'part'      ? $act_var->{number_value}
                     : $cvar->{type} eq 'bool'      ? $act_var->{bool_value}
                     :                                $act_var->{text_value};
      $cvar->{valid} = $valid;
    } else {
      $cvar->{valid} = $valid // 1;

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
    } elsif ($cvar->{type} eq 'customer') {
      require SL::DB::Customer;
      $cvar->{value} = SL::DB::Manager::Customer->find_by(id => $cvar->{value} * 1);
    } elsif ($cvar->{type} eq 'vendor') {
      require SL::DB::Vendor;
      $cvar->{value} = SL::DB::Manager::Vendor->find_by(id => $cvar->{value} * 1);
    } elsif ($cvar->{type} eq 'part') {
      require SL::DB::Part;
      $cvar->{value} = SL::DB::Manager::Part->find_by(id => $cvar->{value} * 1);
    }
  }

  $h_var->finish();

  $main::lxdebug->leave_sub();

  return $custom_variables;
}

sub save_custom_variables {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save_custom_variables, $self, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save_custom_variables {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(module trans_id variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my @configs  = $params{configs} ? @{ $params{configs} } : grep { $_->{module} eq $params{module} } @{ CVar->get_configs() };

  my $query    =
    qq|DELETE FROM custom_variables
       WHERE (trans_id  = ?)
         AND (config_id IN (SELECT DISTINCT id
                            FROM custom_variable_configs
                            WHERE module = ?))|;
  my @values   = (conv_i($params{trans_id}), $params{module});

  if ($params{sub_module}) {
    $query .= qq| AND (sub_module = ?)|;
    push @values, $params{sub_module};
  }

  do_query($form, $dbh, $query, @values);

  $query  =
    qq|INSERT INTO custom_variables (config_id, sub_module, trans_id, bool_value, timestamp_value, text_value, number_value)
       VALUES                       (?,         ?,          ?,        ?,          ?,               ?,          ?)|;
  my $sth = prepare_query($form, $dbh, $query);

  foreach my $config (@configs) {
    if ($params{save_validity}) {
      my $valid_index = "$params{name_prefix}cvar_$config->{name}$params{name_postfix}_valid";
      my $new_valid   = $params{variables}{$valid_index} || $params{always_valid} ? 1 : 0;
      my $old_valid   = $self->get_custom_variables_validity(trans_id => $params{trans_id}, config_id => $config->{id});

      $self->save_custom_variables_validity(trans_id  => $params{trans_id},
                                            config_id => $config->{id},
                                            validity  => $new_valid,
                                           );

      if (!$new_valid || !$old_valid) {
        # When activating a cvar (old_valid == 0 && new_valid == 1)
        # the input to hold the variable's value wasn't actually
        # rendered, meaning saving the value now would only save an
        # empty value/the value 0. This means that the next time the
        # form is rendered, an existing value is found and used
        # instead of the variable's default value from the
        # configuration. Therefore don't save the values in such
        # cases.
        next;
      }
    }

    my @values = (conv_i($config->{id}), "$params{sub_module}", conv_i($params{trans_id}));

    my $value  = $params{variables}->{"$params{name_prefix}cvar_$config->{name}$params{name_postfix}"};

    if (($config->{type} eq 'text') || ($config->{type} eq 'textfield') || ($config->{type} eq 'select')) {
      push @values, undef, undef, $value, undef;

    } elsif (($config->{type} eq 'date') || ($config->{type} eq 'timestamp')) {
      push @values, undef, conv_date($value), undef, undef;

    } elsif ($config->{type} eq 'number') {
      push @values, undef, undef, undef, conv_i($form->parse_amount($myconfig, $value));

    } elsif ($config->{type} eq 'bool') {
      push @values, $value ? 't' : 'f', undef, undef, undef;
    } elsif (any { $config->{type} eq $_ } qw(customer vendor part)) {
      push @values, undef, undef, undef, $value * 1;
    }

    do_statement($form, $sth, $query, @values);
  }

  $sth->finish();

  return 1;
}

sub render_inputs {
  $main::lxdebug->enter_sub(2);

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my %options  = ( name_prefix           => "$params{name_prefix}",
                   name_postfix          => "$params{name_postfix}",
                   hide_non_editable     => $params{hide_non_editable},
                   show_disabled_message => $params{show_disabled_message},
                 );

  # should this cvar be filtered by partsgroups?
  foreach my $var (@{ $params{variables} }) {
    if ($var->{flag_partsgroup_filter}) {
      if (!$params{partsgroup_id} || (!grep {$params{partsgroup_id} == $_} @{ $var->{partsgroups} })) {
        $var->{partsgroup_filtered} = 1;
      }
    }

    $var->{HTML_CODE} = $form->parse_html_template('amcvar/render_inputs',     { var => $var, %options });
    $var->{VALID_BOX} = $form->parse_html_template('amcvar/render_checkboxes', { var => $var, %options });
  }

  $main::lxdebug->leave_sub(2);
}

sub render_search_options {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(variables));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  $params{hidden_cvar_filters} = $myconfig->{hide_cvar_search_options};

  $params{include_prefix}   = 'l_' unless defined($params{include_prefix});
  $params{include_value}  ||= '1';
  $params{filter_prefix}  ||= '';

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
      push @sub_values, like($params{filter}->{$name});

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

      my $op;
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
      push @sub_values, $form->parse_amount($myconfig, trim($params{filter}->{$name}));

    } elsif ($config->{type} eq 'bool') {
      next unless ($params{filter}->{$name});

      $not = 'NOT' if ($params{filter}->{$name} eq 'no');
      push @sub_where,  qq|COALESCE(cvar.bool_value, false) = TRUE|;
    } elsif (any { $config->{type} eq $_ } qw(customer vendor)) {
      next unless $params{filter}->{$name};

      my $table = $config->{type};
      push @sub_where, qq|cvar.number_value * 1 IN (SELECT id FROM $table WHERE name ILIKE ?)|;
      push @sub_values, like($params{filter}->{$name});
    } elsif ($config->{type} eq 'part') {
      next unless $params{filter}->{$name};

      push @sub_where, qq|cvar.number_value * 1 IN (SELECT id FROM parts WHERE partnumber ILIKE ?)|;
      push @sub_values, like($params{filter}->{$name});
    }

    if (@sub_where) {
      add_token(\@sub_where, \@sub_values, col => 'cvar.sub_module', val => $params{sub_module} || '');

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

  # allow sub_module to be a coderef or a fixed value
  if (ref $params{sub_module} ne 'CODE') {
    my $sub_module = "$params{sub_module}";
    $params{sub_module} = sub { $sub_module };
  }

  my %cfg_map   = map { $_->{id} => $_ } @{ $configs };
  my @cfg_ids   = keys %cfg_map;

  my $query     =
    qq|SELECT text_value, timestamp_value, timestamp_value::date AS date_value, number_value, bool_value, config_id
       FROM custom_variables
       WHERE (config_id IN (| . join(', ', ('?') x scalar(@cfg_ids)) . qq|))
         AND (trans_id = ?)
         AND (sub_module = ?)|;
  my $sth       = prepare_query($form, $dbh, $query);

  foreach my $row (@{ $params{data} }) {
    do_statement($form, $sth, $query, @cfg_ids, conv_i($row->{$params{trans_id_field}}), $params{sub_module}->($row));

    while (my $ref = $sth->fetchrow_hashref()) {
      my $cfg = $cfg_map{$ref->{config_id}};

      $row->{"cvar_$cfg->{name}"} =
          $cfg->{type} eq 'date'      ? $ref->{date_value}
        : $cfg->{type} eq 'timestamp' ? $ref->{timestamp_value}
        : $cfg->{type} eq 'number'    ? $form->format_amount($myconfig, $ref->{number_value} * 1, $cfg->{precision})
        : $cfg->{type} eq 'customer'  ? (SL::DB::Manager::Customer->find_by(id => 1*$ref->{number_value}) || SL::DB::Customer->new)->name
        : $cfg->{type} eq 'vendor'    ? (SL::DB::Manager::Vendor->find_by(id => 1*$ref->{number_value})   || SL::DB::Vendor->new)->name
        : $cfg->{type} eq 'part'      ? (SL::DB::Manager::Part->find_by(id => 1*$ref->{number_value})     || SL::DB::Part->new)->partnumber
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

sub save_custom_variables_validity {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save_custom_variables_validity, $self, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save_custom_variables_validity {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(config_id trans_id validity));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my (@where, @values);
  add_token(\@where, \@values, col => "config_id", val => $params{config_id}, esc => \&conv_i);
  add_token(\@where, \@values, col => "trans_id",  val => $params{trans_id},  esc => \&conv_i);

  my $where = scalar @where ? "WHERE " . join ' AND ', @where : '';
  my $query = qq|DELETE FROM custom_variables_validity $where|;

  do_query($form, $dbh, $query, @values);

  $query  =
    qq|INSERT INTO custom_variables_validity (config_id, trans_id)
       VALUES                                (?,         ?       )|;
  my $sth = prepare_query($form, $dbh, $query);

  unless ($params{validity}) {
    foreach my $config_id (listify($params{config_id})) {
      foreach my $trans_id (listify($params{trans_id})) {
        do_statement($form, $sth, $query, conv_i($config_id), conv_i($trans_id));
      }
    }
  }

  $sth->finish();

  return 1;
}

my %_validity_sub_module_mapping = (
  orderitems           => { table => 'orderitems',           result_column => 'parts_id', trans_id_column => 'id', },
  delivery_order_items => { table => 'delivery_order_items', result_column => 'parts_id', trans_id_column => 'id', },
  invoice              => { table => 'invoice',              result_column => 'parts_id', trans_id_column => 'id', },
);

sub get_custom_variables_validity {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(config_id trans_id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query;

  if ($params{sub_module}) {
    my %mapping = %{ $_validity_sub_module_mapping{ $params{sub_module} } || croak("Invalid sub_module '" . $params{sub_module} . "'") };
    $query = <<SQL;
      SELECT cvv.id
      FROM $mapping{table} mt
      LEFT JOIN custom_variables_validity cvv ON (cvv.trans_id = mt.$mapping{result_column})
      WHERE (cvv.config_id                = ?)
        AND (mt.$mapping{trans_id_column} = ?)
      LIMIT 1
SQL
  } else {
    $query = <<SQL;
      SELECT id
      FROM custom_variables_validity
      WHERE (config_id = ?)
        AND (trans_id  = ?)
      LIMIT 1
SQL
  }

  my ($invalid) = selectfirst_array_query($form, $dbh, $query, conv_i($params{config_id}), conv_i($params{trans_id}));

  return !$invalid;
}

sub custom_variables_validity_by_trans_id {
  $main::lxdebug->enter_sub(2);

  my $self     = shift;
  my %params   = @_;

  return sub { 0 } unless $params{trans_id};

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT DISTINCT config_id FROM custom_variables_validity WHERE trans_id = ?|;

  my %invalids = map { +($_->{config_id} => 1) } selectall_hashref_query($form, $dbh, $query, $params{trans_id});

  $main::lxdebug->leave_sub(2);

  return sub { !$invalids{+shift} };
}

sub parse {
  my ($self, $value, $config) = @_;

  return $::form->parse_amount(\%::myconfig, $value)          if $config->{type} eq 'number';
  return DateTime->from_lxoffice($value)                      if $config->{type} eq 'date';
  return !ref $value ? SL::DB::Manager::Customer->find_by(id => $value * 1) : $value  if $config->{type} eq 'customer';
  return !ref $value ? SL::DB::Manager::Vendor->find_by(id => $value * 1)   : $value  if $config->{type} eq 'vendor';
  return !ref $value ? SL::DB::Manager::Part->find_by(id => $value * 1)     : $value  if $config->{type} eq 'part';
  return $value;
}

sub format_to_template {
  my ($self, $value, $config) = @_;
  # stupid template expects everything formated. except objects
  # do not use outside of print routines for legacy templates

  return $::form->format_amount(\%::myconfig, $value) if $config->{type} eq 'number';
  return $value->to_lxoffice if $config->{type} eq 'date' && blessed $value && $value->can('to_lxoffice');
  return $value;
}

sub get_non_editable_ic_cvars {
  $main::lxdebug->enter_sub(2);
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(form dbh row sub_module may_converted_from));
  my $form               = $params{form};
  my $dbh                = $params{dbh};
  my $row                = $params{row};
  my $sub_module         = $params{sub_module};
  my $may_converted_from = $params{may_converted_from};

  my $cvars;
  if (! $form->{"${sub_module}_id_${row}"}) {
    my $conv_from = 0;
    foreach (@{ $may_converted_from }) {
      if ($form->{"converted_from_${_}_id_$row"}) {
        $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                            module     => 'IC',
                                            sub_module => $_,
                                            trans_id   => $form->{"converted_from_${_}_id_$row"},
                                           );
        $conv_from = 1;
        last;
      }
    }
    # get values for CVars from master data for new items
    if (!$conv_from) {
      $cvars = CVar->get_custom_variables(dbh      => $dbh,
                                          module   => 'IC',
                                          trans_id => $form->{"id_$row"},
                                         );
    }
  } else {
    # get values for CVars from custom_variables for existing items
    $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                        module     => 'IC',
                                        sub_module => $sub_module,
                                        trans_id   => $form->{"${sub_module}_id_${row}"},
                                       );
  }
  # map only non-editable CVars to form
  foreach (@{ $cvars }) {
    next if $_->{flag_editable};
    $form->{"ic_cvar_$_->{name}_$row"} = $_->{value}
  }

  $main::lxdebug->leave_sub(2);
}

1;

__END__

=head1 NAME

SL::CVar.pm - Custom Variables module

=head1 SYNOPSIS

  # dealing with configs

  my $all_configs = CVar->get_configs()

  # dealing with custom vars

  CVar->get_custom_variables(module => 'ic')

=head2 VALIDITY

Suppose the following scenario:

You have a lot of parts in your database, and a set of properties configured. Now not every part has every of these properties, some combinations will just make no sense. In order to clean up your inputs a bit, you want to mark certain combinations as invalid, blocking them from modification and possibly display.

Validity is assumed. If you modify validity, you actually save B<invalidity>.
Invalidity is saved as a function of config_id, and the trans_id

In the naive way, disable an attribute for a specific id (simple)

=cut
