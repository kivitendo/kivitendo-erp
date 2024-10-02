package SL::Controller::CsvImport::BankTransaction;

use strict;

use SL::Helper::Csv;
use SL::Controller::CsvImport::Helper::Consistency;
use SL::DB::BankTransaction;

use Data::Dumper;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(bank_accounts_by) ],
);

sub set_profile_defaults {
  my ($self) = @_;

  $self->controller->profile->_set_defaults(
                       charset       => 'UTF8',  # override charset from defaults
                       update_policy => 'skip',
                      );
};

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::BankTransaction');
}

sub init_bank_accounts_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_bank_accounts } } ) } qw(id account_number iban) };
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);
  my $update_policy  = $self->controller->profile->get('update_policy') || 'skip';

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_bank_account($entry);
    $self->check_currency($entry, take_default => 1);
    $self->join_purposes($entry);
    $self->join_remote_names($entry);
    $self->extract_end_to_end_id($entry);
    $self->check_existing($entry) unless @{ $entry->{errors} };
  } continue {
    $i++;
  }

  $self->add_info_columns({ header => $::locale->text('Bank account'), method => 'local_bank_name' });
  $self->add_raw_data_columns("currency", "currency_id") if grep { /^currency(?:_id)?$/ } @{ $self->csv->header };
  $self->add_info_columns({ header => $::locale->text('End to end ID'), method => 'end_to_end_id' });
}

sub check_existing {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # for each imported entry (line) we make a database call to find existing entries
  # we don't use the init_by hash because we have to check several fields
  # this means that we can't detect duplicates in the import file

  if ( $object->amount ) {
    # check for same
    # * purpose
    # * transdate
    # * remote_account_number  (may be empty for records of our own bank)
    # * amount
    # * local_bank_account_id (case flatrate bank charges for two accounts in one bank: same purpose, transdate, remote_account_number(empty), amount. Just different local_bank_account_id)
    my $num;

    my @conditions;

    if ($object->end_to_end_id && $::instance_conf->get_check_bt_duplicates_endtoend) {
      push @conditions, ( end_to_end_id => $object->end_to_end_id );
    } else {
      push @conditions, ( purpose => $object->purpose );
    }

    if ( $num = SL::DB::Manager::BankTransaction->get_all_count(query =>[ remote_account_number => $object->remote_account_number, transdate => $object->transdate, amount => $object->amount, local_bank_account_id => $object->local_bank_account_id, @conditions] ) ) {
      push(@{$entry->{errors}}, $::locale->text('Skipping due to existing bank transaction in database'));
    };
  } else {
      push(@{$entry->{errors}}, $::locale->text('Skipping because transfer amount is empty.'));
  };
}

sub _displayable_columns {
 (
   { name => 'local_bank_code',       description => $::locale->text('Own bank code') },
   { name => 'local_account_number',  description => $::locale->text('Own bank account number or IBAN') },
   { name => 'local_bank_account_id', description => $::locale->text('ID of own bank account') },
   { name => 'remote_bank_code',      description => $::locale->text('Bank code of the goal/source') },
   { name => 'remote_account_number', description => $::locale->text('Account number of the goal/source') },
   { name => 'transdate',             description => $::locale->text('Transdate') },
   { name => 'valutadate',            description => $::locale->text('Valutadate') },
   { name => 'amount',                description => $::locale->text('Amount') },
   { name => 'currency',              description => $::locale->text('Currency') },
   { name => 'currency_id',           description => $::locale->text('Currency (database ID)')          },
   { name => 'remote_name',           description => $::locale->text('Name of the goal/source (if field names remote_name and remote_name_1 exist they will be combined into field "remote_name")') },
   { name => 'remote_name_1',          description => $::locale->text('Name of the goal/source (if field names remote_name and remote_name_1 exist they will be combined into field "remote_name")') },
   { name => 'purpose',               description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose1',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose2',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose3',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose4',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose5',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose6',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose7',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose8',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose9',              description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose10',             description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose11',             description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose12',             description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'purpose13',             description => $::locale->text('Purpose (if field names purpose, purpose1, purpose2 ... exist they will all combined into the field "purpose")') },
   { name => 'qr_reference',          description => $::locale->text('QR reference') }
 );
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns($self->_displayable_columns);
}

sub check_bank_account {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # import via id: check whether or not local_bank_account ID exists and is valid.
  if ($object->local_bank_account_id && !$self->bank_accounts_by->{id}->{ $object->local_bank_account_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: unknown local bank account id');
    return 0;
  }

  # Check whether or not local_bank_account ID, local_account_number and local_bank_code are consistent.
  if ($object->local_bank_account_id && $entry->{raw_data}->{local_account_number}) {
    my $bank_account = $self->bank_accounts_by->{id}->{ $object->local_bank_account_id };
    if ($bank_account->account_number ne $entry->{raw_data}->{local_account_number}) {
      push @{ $entry->{errors} }, $::locale->text('Error: local bank account id doesn\'t match local bank account number');
      return 0;
    }
    if ($entry->{raw_data}->{local_bank_code} && $entry->{raw_data}->{local_bank_code} ne $bank_account->bank_code) {
      push @{ $entry->{errors} }, $::locale->text('Error: local bank account id doesn\'t match local bank code');
      return 0;
    }

  }

  # Map account information to ID via local_account_number if no local_bank_account_id was given
  # local_account_number checks for match of account number or IBAN
  if (!$object->local_bank_account_id && $entry->{raw_data}->{local_account_number}) {
    my $bank_account = $self->bank_accounts_by->{account_number}->{ $entry->{raw_data}->{local_account_number} };
    if (!$bank_account) {
       $bank_account = $self->bank_accounts_by->{iban}->{ $entry->{raw_data}->{local_account_number} };
    };
    if (!$bank_account) {
      push @{ $entry->{errors} }, $::locale->text('Error: unknown local bank account') . ": " . $entry->{raw_data}->{local_account_number};
      return 0;
    }
    if ($entry->{raw_data}->{local_bank_code} && $entry->{raw_data}->{local_bank_code} ne $bank_account->bank_code) {
      push @{ $entry->{errors} }, $::locale->text('Error: Found local bank account number but local bank code doesn\'t match') . ": " . $entry->{raw_data}->{local_bank_code};
      return 0;
    }

    $object->local_bank_account_id($bank_account->id);
    $entry->{info_data}->{local_bank_name} = $bank_account->name;
  }

  # Check if local bank account is marked for bank import
  if ($object->local_bank_account_id && !$self->bank_accounts_by->{id}->{ $object->local_bank_account_id }->use_with_bank_import) {
    push @{ $entry->{errors} }, $::locale->text('Error: local bank account is not marked for bank import, check settings under System -> Bank Accounts');
    return 0;
  }

  return $object->local_bank_account_id ? 1 : 0;
}

sub join_purposes {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $purpose =
    join ' ',
    grep { ($_ // '') !~ m{^ *$} }
    map  { $entry->{raw_data}->{"purpose$_"} }
    ('', 1..13);

  $object->purpose($purpose);

}

sub join_remote_names {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $remote_name = join(' ', $entry->{raw_data}->{remote_name},
                             $entry->{raw_data}->{remote_name_1} );
  $object->remote_name($remote_name);
}

sub extract_end_to_end_id {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  return if $object->purpose !~ m{\b(?:end\W?to\W?end:|eref\+) *([^ ]+)}i;

  my $id = $1;

  $object->end_to_end_id($id) if $id !~ m{notprovided}i;
  $entry->{info_data}->{end_to_end_id} = $object->end_to_end_id;
}

sub check_auth {
  $::auth->assert('config') if ! $::auth->assert('bank_transaction',1);
}

1;
