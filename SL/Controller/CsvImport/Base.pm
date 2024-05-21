package SL::Controller::CsvImport::Base;

use strict;

use English qw(-no_match_vars);
use List::Util qw(min);
use List::MoreUtils qw(pairwise any);

use SL::Helper::Csv;

use SL::DB;
use SL::DB::BankAccount;
use SL::DB::Customer;
use SL::DB::Language;
use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Vendor;
use SL::DB::Contact;
use SL::DB::History;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(controller file csv test_run save_with_cascade) ],
 'scalar --get_set_init' => [ qw(profile displayable_columns existing_objects class manager_class cvar_columns all_cvar_configs all_languages payment_terms_by delivery_terms_by all_bank_accounts all_vc vc_by vc_counts_by clone_methods) ],
);

sub run {
  my ($self, %params) = @_;

  $self->test_run($params{test});

  $self->controller->track_progress(phase => 'parsing csv', progress => 0);

  my $profile = $self->profile;
  $self->csv(SL::Helper::Csv->new(file                   => ('SCALAR' eq ref $self->file)? $self->file: $self->file->file_name,
                                  encoding               => $self->controller->profile->get('charset'),
                                  profile                => [{ profile => $profile, class => $self->class, mapping => $self->controller->mappings_for_profile }],
                                  ignore_unknown_columns => 1,
                                  strict_profile         => 1,
                                  case_insensitive_header => 1,
                                  map { ( $_ => $self->controller->profile->get($_) ) } qw(sep_char escape_char quote_char),
                                 ));

  $self->controller->track_progress(progress => 10);

  local $::myconfig{numberformat} = $self->controller->profile->get('numberformat');
  local $::myconfig{dateformat}   = $self->controller->profile->get('dateformat');

  $self->csv->parse;

  $self->controller->track_progress(progress => 50);

  $self->controller->errors([ $self->csv->errors ]) if $self->csv->errors;

  return if ( !$self->csv->header || $self->csv->errors );

  my $headers         = { headers => [ grep { $self->csv->dispatcher->is_known($_, 0) } @{ $self->csv->header } ] };
  $headers->{methods} = [ map { $_->{path} } @{ $self->csv->specs->[0] } ];
  $headers->{used}    = { map { ($_ => 1) }  @{ $headers->{headers} } };
  $self->controller->headers($headers);
  $self->controller->raw_data_headers({ used => { }, headers => [ ] });
  $self->controller->info_headers({ used => { }, headers => [ ] });

  my $objects  = $self->csv->get_objects;
  if ($self->csv->errors) {
    $self->controller->errors([ $self->csv->errors ]) ;
    return;
  }

  $self->controller->track_progress(progress => 70);

  my @raw_data = @{ $self->csv->get_data };

  $self->controller->track_progress(progress => 80);

  $self->controller->data([ pairwise { { object => $a, raw_data => $b, errors => [], information => [], info_data => {} } } @$objects, @raw_data ]);

  $self->controller->track_progress(progress => 90);

  $self->check_objects;
  if ( $self->controller->profile->get('duplicates', 'no_check') ne 'no_check' ) {
    $self->check_std_duplicates();
    $self->check_duplicates();
  }
  $self->fix_field_lengths;

  $self->controller->track_progress(progress => 100);
}

sub add_columns {
  my ($self, @columns) = @_;

  my $h = $self->controller->headers;

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{methods} }, $column;
    push @{ $h->{headers} }, $column;
  }
}

sub add_info_columns {
  my ($self, @columns) = @_;

  my $h = $self->controller->info_headers;

  foreach my $column (grep { !$h->{used}->{ $_->{method} } } map { ref $_ eq 'HASH' ? $_ : { method => $_, header => $_ } } @columns) {
    $h->{used}->{ $column->{method} } = 1;
    push @{ $h->{methods} }, $column->{method};
    push @{ $h->{headers} }, $column->{header};
  }
}

sub add_raw_data_columns {
  my ($self, @columns) = @_;

  my $h = $self->controller->raw_data_headers;

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{headers} }, $column;
  }
}

sub add_cvar_raw_data_columns {
  my ($self) = @_;

  map { $self->add_raw_data_columns($_) if exists $self->controller->data->[0]->{raw_data}->{$_} } @{ $self->cvar_columns };
}

sub init_all_cvar_configs {
  # Must be overridden by derived specialized importer classes.
  return [];
}

sub init_cvar_columns {
  my ($self) = @_;

  return [ map { "cvar_" . $_->name } (@{ $self->all_cvar_configs }) ];
}

sub init_all_languages {
  my ($self) = @_;

  return SL::DB::Manager::Language->get_all;
}

sub init_all_bank_accounts {
  my ($self) = @_;

  return SL::DB::Manager::BankAccount->get_all_sorted( query => [ obsolete => 0 ] );
}

sub init_payment_terms_by {
  my ($self) = @_;

  my $all_payment_terms = SL::DB::Manager::PaymentTerm->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_payment_terms } } ) } qw(id description) };
}

sub init_delivery_terms_by {
  my ($self) = @_;

  my $all_delivery_terms = SL::DB::Manager::DeliveryTerm->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_delivery_terms } } ) } qw(id description) };
}

sub init_all_vc {
  my ($self) = @_;

  return { customers => SL::DB::Manager::Customer->get_all,
           vendors   => SL::DB::Manager::Vendor->get_all };
}

sub init_clone_methods {
  {}
}

sub force_allow_columns {
  return ();
}

sub init_vc_by {
  my ($self)    = @_;

  my %by_id     = map { ( $_->id => $_ ) } @{ $self->all_vc->{customers} }, @{ $self->all_vc->{vendors} };
  my %by_number = ( customers => { map { ( $_->customernumber => $_ ) } @{ $self->all_vc->{customers} } },
                    vendors   => { map { ( $_->vendornumber   => $_ ) } @{ $self->all_vc->{vendors}   } } );
  my %by_name   = ( customers => { map { ( $_->name           => $_ ) } @{ $self->all_vc->{customers} } },
                    vendors   => { map { ( $_->name           => $_ ) } @{ $self->all_vc->{vendors}   } } );
  my %by_gln    = ( customers => { map { ( $_->gln            => $_ ) } grep $_->gln, @{ $self->all_vc->{customers} } },
                    vendors   => { map { ( $_->gln            => $_ ) } grep $_->gln, @{ $self->all_vc->{vendors}   } } );

  return { id     => \%by_id,
           number => \%by_number,
           name   => \%by_name,
           gln    => \%by_gln };
}

sub init_vc_counts_by {
  my ($self) = @_;

  my $vc_counts_by = {};

  $vc_counts_by->{number}->{customers}->{$_->customernumber}++ for @{ $self->all_vc->{customers} };
  $vc_counts_by->{number}->{vendors}->  {$_->vendornumber}++   for @{ $self->all_vc->{vendors} };
  $vc_counts_by->{name}->  {customers}->{$_->name}++           for @{ $self->all_vc->{customers} };
  $vc_counts_by->{name}->  {vendors}->  {$_->name}++           for @{ $self->all_vc->{vendors} };
  $vc_counts_by->{gln}->   {customers}->{$_->gln}++            for grep $_->gln, @{ $self->all_vc->{customers} };
  $vc_counts_by->{gln}->   {vendors}->  {$_->gln}++            for grep $_->gln, @{ $self->all_vc->{vendors} };

  return $vc_counts_by;
}

sub check_vc {
  my ($self, $entry, $id_column) = @_;

  if ($entry->{object}->$id_column) {
    $entry->{object}->$id_column(undef) if !$self->vc_by->{id}->{ $entry->{object}->$id_column };
  }

  my $is_ambiguous;
  if (!$entry->{object}->$id_column) {
    my $vc;
    if ($entry->{raw_data}->{customernumber}) {
      $vc = $self->vc_by->{number}->{customers}->{ $entry->{raw_data}->{customernumber} };
      if ($vc && $self->vc_counts_by->{number}->{customers}->{ $entry->{raw_data}->{customernumber} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    } elsif ($entry->{raw_data}->{vendornumber}) {
      $vc = $self->vc_by->{number}->{vendors}->{ $entry->{raw_data}->{vendornumber} };
      if ($vc && $self->vc_counts_by->{number}->{vendors}->{ $entry->{raw_data}->{vendornumber} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    }

    $entry->{object}->$id_column($vc->id) if $vc;
  }

  if (!$entry->{object}->$id_column) {
    my $vc;
    if ($entry->{raw_data}->{customer}) {
      $vc = $self->vc_by->{name}->{customers}->{ $entry->{raw_data}->{customer} };
      if ($vc && $self->vc_counts_by->{name}->{customers}->{ $entry->{raw_data}->{customer} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    } elsif ($entry->{raw_data}->{vendor}) {
      $vc = $self->vc_by->{name}->{vendors}->{ $entry->{raw_data}->{vendor} };
      if ($vc && $self->vc_counts_by->{name}->{vendors}->{ $entry->{raw_data}->{vendor} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    }

    $entry->{object}->$id_column($vc->id) if $vc;
  }

  if (!$entry->{object}->$id_column) {
    my $vc;
    if ($entry->{raw_data}->{customer_gln}) {
      $vc = $self->vc_by->{gln}->{customers}->{ $entry->{raw_data}->{customer_gln} };
      if ($vc && $self->vc_counts_by->{gln}->{customers}->{ $entry->{raw_data}->{customer_gln} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    } elsif ($entry->{raw_data}->{vendor_gln}) {
      $vc = $self->vc_by->{gln}->{vendors}->{ $entry->{raw_data}->{vendor_gln} };
      if ($vc && $self->vc_counts_by->{gln}->{vendors}->{ $entry->{raw_data}->{vendor_gln} } > 1) {
        $vc = undef;
        $is_ambiguous = 1;
      }
    }
    $entry->{object}->$id_column($vc->id) if $vc;
  }

  if ($entry->{object}->$id_column) {
    $entry->{info_data}->{vc_name} = $self->vc_by->{id}->{ $entry->{object}->$id_column }->name;
  } else {
    if ($is_ambiguous) {
      push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor is ambiguous');
    } else {
      push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor not found');
    }
  }
}

sub handle_cvars {
  my ($self, $entry) = @_;

  my $object = $entry->{object_to_save} || $entry->{object};
  return unless $object->can('cvars_by_config');

  my %type_to_column = ( text      => 'text_value',
                         textfield => 'text_value',
                         htmlfield => 'text_value',
                         select    => 'text_value',
                         date      => 'timestamp_value_as_date',
                         timestamp => 'timestamp_value_as_date',
                         number    => 'number_value_as_number',
                         bool      => 'bool_value' );

  # autovivify all cvars (cvars_by_config will do that for us)
  my @cvars;
  my %changed_cvars;
  foreach my $config (@{ $self->all_cvar_configs }) {
    next unless exists $entry->{raw_data}->{ "cvar_" . $config->name };
    my $value  = $entry->{raw_data}->{ "cvar_" . $config->name };
    my $column = $type_to_column{ $config->type } || die "Program logic error: unknown custom variable storage type";

    my $new_cvar = SL::DB::CustomVariable->new(config_id => $config->id, $column => $value, sub_module => '');

    push @cvars, $new_cvar;
    $changed_cvars{$config->name} = $new_cvar;
  }

  # merge existing with new cvars. swap every existing with the imported one, push the rest
  my @orig_cvars = @{ $object->cvars_by_config };
  for (@orig_cvars) {
    $_ = $changed_cvars{ $_->config->name } if $changed_cvars{ $_->config->name };
    delete $changed_cvars{ $_->config->name };
  }
  push @orig_cvars, values %changed_cvars;
  $object->custom_variables(\@orig_cvars);
}

sub init_profile {
  my ($self) = @_;

  eval "require " . $self->class;

  my %unwanted = map { ( $_ => 1 ) } (qw(itime mtime), map { $_->name } @{ $self->class->meta->primary_key_columns });
  delete $unwanted{$_} for ($self->force_allow_columns);

  my %profile;
  for my $col ($self->class->meta->columns) {
    next if $unwanted{$col};

    my $name = $col->isa('Rose::DB::Object::Metadata::Column::Numeric')   ? "$col\_as_number"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Date')      ? "$col\_as_date"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Timestamp') ? "$col\_as_date"
      :                                                                     $col->name;

    $profile{$col} = $name;
  }

  $profile{ 'cvar_' . $_->name } = '' for @{ $self->all_cvar_configs };

  \%profile;
}

sub add_displayable_columns {
  my ($self, @columns) = @_;

  my @cols       = @{ $self->controller->displayable_columns || [] };
  my %ex_col_map = map { $_->{name} => $_ } @cols;

  foreach my $column (@columns) {
    if ($ex_col_map{ $column->{name} }) {
      @{ $ex_col_map{ $column->{name} } }{ keys %{ $column } } = @{ $column }{ keys %{ $column } };
    } else {
      push @cols, $column;
    }
  }

  $self->controller->displayable_columns([ sort { $a->{name} cmp $b->{name} } @cols ]);
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->add_displayable_columns(map { { name => $_ } } keys %{ $self->profile });
}

sub add_cvar_columns_to_displayable_columns {
  my ($self) = @_;

  $self->add_displayable_columns(map { { name        => 'cvar_' . $_->name,
                                         description => $::locale->text('#1 (custom variable)', $_->description) } }
                                     @{ $self->all_cvar_configs });
}

sub init_existing_objects {
  my ($self) = @_;

  eval "require " . $self->class;
  $self->existing_objects($self->manager_class->get_all);
}

sub init_class {
  die "class not set";
}

sub init_manager_class {
  my ($self) = @_;

  $self->class =~ m/^SL::DB::(.+)/;
  $self->manager_class("SL::DB::Manager::" . $1);
}

sub is_multiplexed { 0 }

sub check_objects {
}

sub check_duplicates {
}

sub check_auth {
  $::auth->assert('config');
}

sub check_std_duplicates {
  my $self = shift;

  my $duplicates = {};

  my $all_fields = $self->get_duplicate_check_fields();

  foreach my $key (keys(%{ $all_fields })) {
    if ( $self->controller->profile->get('duplicates_'. $key) && (!exists($all_fields->{$key}->{std_check}) || $all_fields->{$key}->{std_check} )  ) {
      $duplicates->{$key} = {};
    }
  }

  my @duplicates_keys = keys(%{ $duplicates });

  if ( !scalar(@duplicates_keys) ) {
    return;
  }

  if ( $self->controller->profile->get('duplicates') eq 'check_db' ) {
    foreach my $object (@{ $self->existing_objects }) {
      foreach my $key (@duplicates_keys) {
        my $value = exists($all_fields->{$key}->{maker}) ? $all_fields->{$key}->{maker}->($object, $self) : $object->$key;
        $duplicates->{$key}->{$value} = 'db';
      }
    }
  }

  foreach my $entry (@{ $self->controller->data }) {
    if ( @{ $entry->{errors} } ) {
      next;
    }

    my $object = $entry->{object};

    foreach my $key (@duplicates_keys) {
      my $value = exists($all_fields->{$key}->{maker}) ? $all_fields->{$key}->{maker}->($object, $self) : $object->$key;

      if ( exists($duplicates->{$key}->{$value}) ) {
        push(@{ $entry->{errors} }, $duplicates->{$key}->{$value} eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file'));
        last;
      } else {
        $duplicates->{$key}->{$value} = 'csv';
      }

    }
  }

}

sub get_duplicate_check_fields {
  return {};
}

sub check_payment {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not payment ID is valid.
  if ($object->payment_id && !$self->payment_terms_by->{id}->{ $object->payment_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->payment_id && $entry->{raw_data}->{payment}) {
    my $terms = $self->payment_terms_by->{description}->{ $entry->{raw_data}->{payment} };

    if (!$terms) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
      return 0;
    }

    $object->payment_id($terms->id);

    # register payment_id for method copying later
    $self->clone_methods->{payment_id} = 1;
  }

  return 1;
}

sub check_delivery_term {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not delivery term ID is valid.
  if ($object->delivery_term_id && !$self->delivery_terms_by->{id}->{ $object->delivery_term_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid delivery terms');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->delivery_term_id && $entry->{raw_data}->{delivery_term}) {
    my $terms = $self->delivery_terms_by->{description}->{ $entry->{raw_data}->{delivery_term} };

    if (!$terms) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid delivery terms');
      return 0;
    }

    $object->delivery_term_id($terms->id);

    # register delivery_term_id for method copying later
    $self->clone_methods->{delivery_term_id} = 1;
  }

  return 1;
}

sub save_objects {
  my ($self, %params) = @_;

  my $data = $params{data} || $self->controller->data;

  return unless $data->[0];
  return unless $data->[0]{object};

  # If we store into tables which get numbers from the TransNumberGenerator
  # we have to lock all tables referenced by the storage table (or by
  # tables stored alongside with the storage table) that are handled by
  # the TransNumberGenerator, too.
  # Otherwise we can run into a deadlock if someone saves a document via
  # the user interface. The exact behavoir depends on timing.
  # E.g. we are importing orders and a user want to
  # book an invoice:
  # web: locks ar (via before-save hook and TNG (or SL::TransNumber))
  # importer: locks oe (via before-save hook and TNG) (*)
  # importer: locks defaults (via before-save hook and TNG)
  # web: wants to lock defaults (via before-save hook and TNG (or SL::TransNumber)) -> is waiting
  # importer: wants to save oe and wants to lock referenced tables (here ar) -> is waiting
  # --> deadlock
  #
  # (*) if the importer locks ar here, too, everything is fine, because it will wait here
  # before locking the defaults table.
  #
  # List of referenced tables:
  # (Locking is done in the transaction below)
  my %referenced_tables_by_type = (
    orders          => [qw(ar customer vendor)],
    delivery_orders => [qw(customer vendor)   ],
    ar_transactions => [qw(customer)          ],
    ap_transactions => [qw(vendor)            ],
  );

  $self->controller->track_progress(phase => 'saving data', progress => 0); # scale from 45..95%;

  my $last_index = $#$data;
  my $chunk_size = 100;      # one transaction and progress update every 100 objects

  for my $chunk (0 .. $last_index / $chunk_size) {
    $self->controller->track_progress(progress => ($chunk_size * $chunk)/scalar(@$data) * 100); # scale from 45..95%;
    SL::DB->client->with_transaction(sub {

      foreach my $refs (@{ $referenced_tables_by_type{$self->controller->{type}} || [] }) {
        SL::DB->client->dbh->do("LOCK " . $refs) || die SL::DB->client->dbh->errstr;
      }

      foreach my $entry_index ($chunk_size * $chunk .. min( $last_index, $chunk_size * ($chunk + 1) - 1 )) {
        my $entry = $data->[$entry_index];

        my $object = $entry->{object_to_save} || $entry->{object};
        $self->save_additions_always($object);

        next if @{ $entry->{errors} };

        my $ret;
        if (!eval { $ret = $object->save(cascade => !!$self->save_with_cascade()); 1 }) {
          push @{ $entry->{errors} }, $::locale->text('Error when saving: #1', $EVAL_ERROR);
        } elsif ( !$ret ) {
          push @{ $entry->{errors} }, $::locale->text('Error when saving: #1', $object->db->error);
        } else {
          $self->_save_history($object);
          $self->save_additions($object);
          $self->controller->num_imported($self->controller->num_imported + 1);
        }
      }
      1;
    }) or do { die SL::DB->client->error };
  }
  $self->controller->track_progress(progress => 100);
}

sub field_lengths {
  my ($self) = @_;

  return map { $_->name => $_->length } grep { $_->type eq 'varchar' } @{$self->class->meta->columns};
}

sub fix_field_lengths {
  my ($self) = @_;

  my %field_lengths = $self->field_lengths;
  foreach my $entry (@{ $self->controller->data }) {
    next unless @{ $entry->{errors} };
    map { $entry->{object}->$_(substr($entry->{object}->$_, 0, $field_lengths{$_})) if $entry->{object}->$_ } keys %field_lengths;
  }
}

sub clean_fields {
  my ($self, $illegal_chars, $object, @fields) = @_;

  my @cleaned_fields;
  foreach my $field (grep { $object->can($_) } @fields) {
    my $value = $object->$field;

    next unless defined($value) && ($value =~ s/$illegal_chars/ /g);

    $object->$field($value);
    push @cleaned_fields, $field;
  }

  return @cleaned_fields;
}

sub save_additions {
  my ($self, $object) = @_;

  # Can be overridden by derived specialized importer classes to save
  # additional tables (e.g. record links).
  # This sub is called after the object is saved successfully in an transaction.

  return;
}

sub save_additions_always {
  my ($self, $object) = @_;

  # Can be overridden by derived specialized importer classes to save
  # additional tables always.
  # This sub is called before the object is saved. Therefore this
  # hook will always be executed whether or not the import entry can be saved successfully.

  return;
}


sub _save_history {
  my ($self, $object) = @_;

  if (any { $self->controller->{type} && $_ eq $self->controller->{type} } qw(parts customers_vendors orders delivery_orders ar_transactions)) {
    my $snumbers = $self->controller->{type} eq 'parts'             ? 'partnumber_' . $object->partnumber
                 : $self->controller->{type} eq 'customers_vendors' ?
                     ($self->table eq 'customer' ? 'customernumber_' . $object->customernumber : 'vendornumber_' . $object->vendornumber)
                 : $self->controller->{type} eq 'orders'            ? 'ordnumber_' . $object->ordnumber
                 : $self->controller->{type} eq 'delivery_orders'   ? 'donumber_'  . $object->donumber
                 : $self->controller->{type} eq 'ar_transactions'   ? 'invnumber_' . $object->invnumber
                 : '';

    my $what_done = '';
    if ($self->controller->{type} eq 'orders') {
      $what_done = $object->customer_id ? 'sales_order' : 'purchase_order';
    }
    if ($self->controller->{type} eq 'delivery_orders') {
      $what_done = $object->customer_id ? 'sales_delivery_order' : 'purchase_delivery_order';
    }

    SL::DB::History->new(
      trans_id    => $object->id,
      snumbers    => $snumbers,
      employee_id => $self->controller->{employee_id},
      addition    => 'SAVED',
      what_done   => $what_done,
    )->save();
  }
}

1;
