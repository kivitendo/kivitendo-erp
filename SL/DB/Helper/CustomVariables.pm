package SL::DB::Helper::CustomVariables;

use strict;
use Carp;
use Data::Dumper;
use List::Util qw(first);
use List::UtilsBy qw(partition_by);

use constant META_CVARS => 'cvars_config';

sub import {
  my ($class, %params) = @_;
  my $caller_package = caller;

  # TODO: if module is empty, module overloading needs to take effect
  # certain stuff may have more than one overload, or even more than one type
  defined $caller_package     or croak 'need to be included from a caller reference';

  $params{module}     ||= _calc_modules_from_overloads(%params) if $params{overloads};
  $params{sub_module} ||= '';
  $params{id}         ||= _get_primary_key_column($caller_package);

  $params{module} || $params{sub_module}  or croak 'need param module or sub_module';

  return unless save_meta_info($caller_package, %params);
  make_cvar_accessor($caller_package, %params);
  make_cvar_alias($caller_package, %params)      if $params{cvars_alias};
  make_cvar_by_configs($caller_package, %params);
  make_cvar_by_name($caller_package, %params);
  make_cvar_as_hashref($caller_package, %params);
  make_cvar_value_parser($caller_package, %params);
  make_cvar_custom_filter($caller_package, %params);
}

sub save_meta_info {
  my ($caller_package, %params) = @_;

  my $meta = $caller_package->meta;
  return 0 if $meta->{META_CVARS()};

  $meta->{META_CVARS()} = \%params;

  return 1;
}

sub make_cvar_accessor {
  my ($caller_package, %params) = @_;

  my $modules = ('ARRAY' eq ref $params{module}) ?
      join ',', @{ $params{module} } :
      $params{module};
  my @module_filter = $modules ?
    ("config_id" => [ \"(SELECT custom_variable_configs.id FROM custom_variable_configs WHERE custom_variable_configs.module IN ( '$modules' ))" ]) : # " make emacs happy
    ();

  $caller_package->meta->add_relationships(
    custom_variables => {
      type         => 'one to many',
      class        => 'SL::DB::CustomVariable',
      column_map   => { $params{id} => 'trans_id' },
      query_args   => [ sub_module => $params{sub_module}, @module_filter ],
    }
  );
}

sub make_cvar_alias {
  my ($caller_package) = @_;
  no strict 'refs';
  *{ $caller_package . '::cvars' } =  sub {
    goto &{ $caller_package . '::custom_variables' };
  }
}

# this is used for templates where you need to list every applicable config
# auto vivifies non existent cvar objects as necessary.
sub make_cvar_by_configs {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::cvars_by_config' } = sub {
    my ($self) = @_;
    @_ > 1 and croak "not an accessor";

    my $configs     = _all_configs(%params);
    my $cvars       = $self->custom_variables;
    my %cvars_by_config = map { $_->config_id => $_ } @$cvars;
    my $invalids    = _all_invalids($self->${\ $self->meta->primary_key_columns->[0]->name }, $configs, %params);
    my %invalids_by_config = map { $_->config_id => 1 } @$invalids;

    my @return = map(
      {
        my $cvar;
        if ( $cvars_by_config{$_->id} ) {
          $cvar = $cvars_by_config{$_->id};
        }
        else {
          $cvar = _new_cvar($self, %params, config => $_);
          $self->add_custom_variables($cvar);
        }
        $cvar->{is_valid} = !$invalids_by_config{$_->id};
        $cvar->{config}   = $_;
        $cvar;
      }
      @$configs
    );

    return \@return;
  }
}

# this is used for print templates where you need to refer to a variable by name
# TODO typically these were referred as prefix_'cvar'_name
sub make_cvar_by_name {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::cvar_by_name' } = sub {
    my ($self, $name) = @_;

    my $configs = _all_configs(%params);
    my $cvars   = $self->custom_variables;
    my $config  = first { $_->name eq $name } @$configs;

    croak "unknown cvar name $name" unless $config;

    my $cvar    = first { $_->config_id eq $config->id } @$cvars;

    if (!$cvar) {
      $cvar = _new_cvar($self, %params, config => $config);
      $self->add_custom_variables($cvar);
    }

    return $cvar;
  }
}

sub make_cvar_as_hashref {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::cvar_as_hashref' } = sub {
    my ($self) = @_;
    @_ > 1 and croak "not an accessor";

    my $cvars_by_config = $self->cvars_by_config;

    my %return = map {
      $_->config->name => { value => $_->value_as_text, is_valid => $_->is_valid }
    } @$cvars_by_config;

    return \%return;
  }
}

sub make_cvar_value_parser {
  my ($caller_package) = @_;
  no strict 'refs';
  *{ $caller_package . '::parse_custom_variable_values' } =  sub {
    my ($self) = @_;

    $_->parse_value for @{ $self->custom_variables || [] };

    return $self;
  };

  $caller_package->before_save('parse_custom_variable_values');
}

sub _all_configs {
  my (%params) = @_;

  require SL::DB::CustomVariableConfig;

  my $cache  = $::request->cache("::SL::DB::Helper::CustomVariables::object_cache");

  if (!$cache->{all}) {
    my $configs = SL::DB::Manager::CustomVariableConfig->get_all_sorted;
    $cache->{all}    =  $configs;
    $cache->{module} = { partition_by { $_->module } @$configs };
  }

  return $params{module} && !ref $params{module} ? $cache->{module}{$params{module}}
       : $params{module} &&  ref $params{module} ? [ map { @{ $cache->{module}{$_} // [] } } @{ $params{module} } ]
       : $cache->{all};
}

sub _overload_by_module {
  my ($module, %params) = @_;

  keys %{ $params{overloads} }; # reset each iterator
  while (my ($fk, $def) = each %{ $params{overloads} }) {
    return ($fk, $def->{class}) if $def->{module} eq $module;
  }

  croak "unknown overload, cannot resolve module $module";
}

sub _new_cvar {
  my ($self, %params) = @_;
  my $inherited_value;
  # check overloading first
  if ($params{sub_module}) {
    my ($fk, $class) = _overload_by_module($params{config}->module, %params);
    my $base_cvar = $class->new(id => $self->$fk)->load->cvar_by_name($params{config}->name);
    $inherited_value = $base_cvar->value;
  }

  my $cvar = SL::DB::CustomVariable->new(
    config     => $params{config},
    trans_id   => $self->${ \ $params{id} },
    sub_module => $params{sub_module},
  );
  # value needs config
  $inherited_value
   ? $cvar->value($inherited_value)
   : $cvar->value($params{config}->type_dependent_default_value);
  return $cvar;
}

sub _calc_modules_from_overloads {
  my (%params) = @_;
  my %modules;

  for my $def (values %{ $params{overloads} || {} }) {
    $modules{$def->{module}} = 1;
  }

  return [ keys %modules ];
}

sub _get_primary_key_column {
  my ($caller_package) = @_;
  my $meta             = $caller_package->meta;

  my $column_name;
  $column_name = $meta->{primary_key}->{columns}->[0] if $meta->{primary_key} && (ref($meta->{primary_key}->{columns}) eq 'ARRAY') && (1 == scalar(@{ $meta->{primary_key}->{columns} }));

  croak "Unable to retrieve primary key column name: meta information for package $caller_package not set up correctly" unless $column_name;

  return $column_name;
}

sub make_cvar_custom_filter {
  my ($caller_package, %params) = @_;

  my $manager    = $caller_package->meta->convention_manager->auto_manager_class_name;

  return unless $manager->can('filter');

  $manager->add_filter_specs(
    cvar => sub {
      my ($key, $value, $prefix, $config_id) = @_;
      my $config = SL::DB::Manager::CustomVariableConfig->find_by(id => $config_id);

      if (!$config) {
        die "invalid config_id in $caller_package\::cvar custom filter: $config_id";
      }

      if ($config->module != $params{module}) {
        die "invalid config_id in $caller_package\::cvar custom filter: expected module $params{module} - got @{[ $config->module ]}";
      }

      my @filter;
      if ($config->type eq 'bool') {
        @filter = $value ? ($config->value_col => 1) : (or => [ $config->value_col => undef, $config->value_col => 0 ]);
      } else {
        @filter = ($config->value_col => $value);
      }

      my (%query, %bind_vals);
      ($query{customized}, $bind_vals{customized}) = Rose::DB::Object::QueryBuilder::build_select(
        dbh                  => $config->dbh,
        select               => 'trans_id',
        tables               => [ 'custom_variables' ],
        columns              => { custom_variables => [ qw(trans_id config_id text_value number_value bool_value timestamp_value sub_module) ] },
        query                => [
          config_id          => $config_id,
          sub_module         => $params{sub_module},
          @filter,
        ],
        query_is_sql         => 1,
      );

      if ($config->type eq 'bool') {
        if ($value) {
          @filter = (
            '!default_value' => undef,
            '!default_value' => '',
            default_value    => '1',
          );

        } else {
          @filter = (
            or => [
              default_value => '0',
              default_value => '',
              default_value => undef,
            ],
          );
        }

      } else {
        @filter = (
          '!default_value' => undef,
          '!default_value' => '',
          default_value    => $value,
        );
      }


      my $conversion  = $config->type =~ m{^(?:date|timestamp)$}       ? $config->type
                      : $config->type =~ m{^(?:customer|vendor|part)$} ? 'integer'
                      : $config->type eq 'number'                      ? 'numeric'
                      :                                                  '';

      ($query{config}, $bind_vals{config}) = Rose::DB::Object::QueryBuilder::build_select(
        dbh                => $config->dbh,
        select             => 'id',
        tables             => [ 'custom_variable_configs' ],
        columns            => { custom_variable_configs => [ qw(id default_value) ] },
        query              => [
          id               => $config->id,
          @filter,
        ],
        query_is_sql       => 1,
      );

      $query{config} =~ s{ (?<! NOT\( ) default_value (?! \s*is\s+not\s+null) }{default_value::${conversion}}x if $conversion;

      ($query{not_customized}, $bind_vals{not_customized}) = Rose::DB::Object::QueryBuilder::build_select(
        dbh          => $config->dbh,
        select       => 'trans_id',
        tables       => [ 'custom_variables' ],
        columns      => { custom_variables => [ qw(trans_id config_id sub_module) ] },
        query        => [
          config_id  => $config_id,
          sub_module => $params{sub_module},
        ],
        query_is_sql => 1,
      );

      foreach my $key (keys %query) {
        # remove rose aliases. query builder sadly is not reentrant, and will reuse the same aliases. :(
        $query{$key} =~ s{\bt\d+(?:\.)?\b}{}g;

        # manually inline the values. again, rose doesn't know how to handle bind params in subqueries :(
        $query{$key} =~ s{\?}{ $config->dbh->quote(shift @{ $bind_vals{$key} }) }xeg;

        $query{$key} =~ s{\n}{ }g;
      }

      my $qry_config = "EXISTS (" . $query{config} . ")";

      my @result = (
        'or' => [
          $prefix . 'id'   => [ \$query{customized} ],
          and              => [
            "!${prefix}id" => [ \$query{not_customized}  ],
            \$qry_config,
          ]
        ],
      );

      return @result;
    }
  );
}


sub _all_invalids {
  my ($trans_id, $configs, %params) = @_;

  require SL::DB::CustomVariableValidity;

  # easy 1: no trans_id, all valid by default.
  return [] unless $trans_id;

  # easy 2: no module in params? no validity
  return [] unless $params{module};

  my %wanted_modules = ref $params{module} ? map { $_ => 1 } @{ $params{module} } : ($params{module} => 1);
  my @module_configs = grep { $wanted_modules{$_->module} } @$configs;

  return [] unless @module_configs;

  # nor find all entries for that and return
  SL::DB::Manager::CustomVariableValidity->get_all(
    query => [
      config_id => [ map { $_->id } @module_configs ],
      trans_id => $trans_id,
    ]
  );
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::CustomVariables - Mixin to provide custom variable relations

=head1 SYNOPSIS

  # use in a primary class
  use SL::DB::Helper::CustomVariables (
    module      => 'IC',
    cvars_alias => 1,
  );

  # use overloading in a secondary class
  use SL::DB::Helper::CustomVariables (
    sub_module  => 'orderitems',
    cvars_alias => 1,
    overloads   => {
      parts_id    => {
        class => 'SL::DB::Part',
        module => 'IC',
      }
    }
  );

=head1 DESCRIPTION

This module provides methods to deal with named custom variables. Two concepts are understood.

=head2 Primary CVar Classes

Primary classes are those that feature cvars for themselves. Currently those
are Part, Contact, Customer and Vendor. cvars for these will get saved directly
for the object.

=head2 Secondary CVar Classes

Secondary classes inherit their cvars from member relationships. This is built
so that orders can save a copy of the cvars of their parts, customers and the
like to be immutable later on.

Secondary classes may currently not have cvars of their own.

=head1 INSTALLED METHODS

=over 4

=item C<custom_variables [ CUSTOM_VARIABLES ]>

This is a Rose::DB::Object::Relationship accessor, generated for cvars. Use it
like any other OneToMany relationship.

Note that unlike L</cvars_by_config> this accessor only returns
variables that have already been created for this object. No variables
will be autovivified for configs for which no variable has been
created yet.

=item C<cvars [ CUSTOM_VARIABLES ]>

Alias to C<custom_variables>. Will only be installed if C<cvars_alias> was
passed to import.

=item C<cvars_by_config>

This will return a list of CVars with the following changes over the standard accessor:

=over 4

=item *

The list will be returned in the sorted order of the configs.

=item *

For every config exactly one CVar will be returned.

=item *

If no cvar was found for a config, a new one will be vivified, set to the
correct config, module etc, and registered into the object.

=item *

Vivified cvars for secondary classes will first try to find their base object
and use that value. If no such value or cvar is found the default value from
configs applies.

=back

This is useful if you need to list every possible CVar, like in CRUD masks.

=item C<cvar_by_name NAME [ VALUE ]>

Returns the CVar object for this object which matches the given internal name.
Useful for print templates. If the requested cvar is not present, it will be
vivified with the same rules as in C<cvars_by_config>.

=item C<parse_custom_variable_values>

When you want to edit custom variables in a form then you have
unparsed values from the user. These should be written to the
variable's C<unparsed_value> field.

This function then processes all variables and parses their
C<unparsed_value> field into the proper field. It returns C<$self> for
easy chaining.

This is automatically called in a C<before_save> hook so you don't
have to do it manually if you save directly after assigning the
values.

In an HTML form you could e.g. use something like the following:

  [%- FOREACH var = SELF.project.cvars_by_config.as_list %]
    [% HTML.escape(var.config.description) %]:
    [% L.hidden_tag('project.custom_variables[+].config_id', var.config.id) %]
    [% PROCESS 'common/render_cvar_input.html' var_name='project.custom_variables[].unparsed_value' %]
  [%- END %]

Later in the controller when you want to save this project you don't
have to do anything special:

  my $project = SL::DB::Project->new;
  my $params  = $::form->{project} || {};

  $project->assign_attributes(%{ $params });

  $project->parse_custom_variable_values->save;

However, if you need access to a variable's value before saving in
some way then you have to call this function manually. For example:

  my $project = SL::DB::Project->new;
  my $params  = $::form->{project} || {};

  $project->assign_attributes(%{ $params });

  $project->parse_custom_variable_values;

  print STDERR "CVar[0] value: " . $project->custom_variables->[0]->value . "\n";

=back

=head1 INSTALLED MANAGER METHODS

=over 4

=item Custom filter for GetModels

If the Manager for the calling C<SL::DB::Object> has included the helper L<SL::DB::Helper::Filtered>, a custom filter for cvars will be added to the specs, with the following syntax:

  filter.cvar.$config_id

=back

=head1 BUGS AND CAVEATS

=over 4

=item * Conditional method export

Prolonged use has shown that users expect all methods to be present or none.
Future versions of this will likely remove the optional aliasing.

=item * Semantics need to be updated

There are a few transitions that are currently neither supported nor well
defined, most of them happening when the config of a cvar gets changed, but
whose instances have already been saved. This needs to be cleaned up.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
