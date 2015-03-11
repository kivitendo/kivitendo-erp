#=====================================================================
# LX-Office ERP
# Copyright (C) 2008
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
#
# Letter module
#
#=====================================================================

package SL::Letter;

use strict;
use List::Util qw(max);

use SL::Common;
use SL::CT;
use SL::DBUtils;
use SL::MoreCommon;
use SL::TransNumber;
use SL::DB::Manager::Customer;

my $DEFINITION = <<SQL;
                                      Table "public.letter"
        Column       |            Type             |                Modifiers
  -------------------+-----------------------------+------------------------------------------
   id                | integer                     | not null default nextval('id'::regclass)
   vc_id             | integer                     | not null
   letternumber      | text                        |
   jobnumber         | text                        |
   text_created_for  | text                        |
   date              | date                        |
   subject           | text                        |
   greeting          | text                        |
   body              | text                        |
   close             | text                        |
   company_name      | text                        |
   employee_id       | integer                     |
   employee_position | text                        |
   salesman_id       | integer                     |
   salesman_position | text                        |
   itime             | timestamp without time zone | default now()
   mtime             | timestamp without time zone |
   page_created_for  | text                        |
   intnotes          | text                        |
   cp_id             | integer                     |
   reference         | text                        |
  Indexes:
      "letter_pkey" PRIMARY KEY, btree (id)
  Foreign-key constraints:
      "letter_cp_id_fkey" FOREIGN KEY (cp_id) REFERENCES contacts(cp_id)
      "letter_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES employee(id)
      "letter_salesman_id_fkey" FOREIGN KEY (salesman_id) REFERENCES employee(id)
SQL

# XXX not working yet
#sub customer {
#  my $self = shift;
#
#  die 'not a setter' if @_;
#
#  return unless $self->{customer_id};
#
#  # resolve customer_obj
#}

sub new {
  my $class  = ref $_[0] || $_[0]; shift;
  my %params = @_;
  my $ref    = $_[0];

  $ref = ref $_[0] eq 'HASH' ? $ref : \%params; # don't like it either...

  my $self = bless $ref, $class;

  $self->_lastname_used;
  $self->_resolve_customer;
  $self->set_greetings;

  return $self;
}

sub _create {
  my $self = shift;
  my $dbh  = $::form->get_standard_dbh;
  ($self->{id}) = selectfirst_array_query($::form, $dbh, "select nextval('id')");

  do_query($::form, $dbh, <<SQL, $self->{id}, $self->{customer_id});
    INSERT INTO letter (id, vc_id) VALUES (?, ?);
SQL
}

sub _create_draft {
  my $self = shift;
  my $dbh  = $::form->get_standard_dbh;
  ($self->{draft_id}) = selectfirst_array_query($::form, $dbh, "select nextval('id')");

  do_query($::form, $dbh, <<SQL, $self->{draft_id}, $self->{customer_id});
    INSERT INTO letter_draft (id, vc_id) VALUES (?, ?);
SQL
}


sub save {
  $::lxdebug->enter_sub;

  my $self     = shift;
  my %params   = @_;
  my $dbh      = $::form->get_standard_dbh;
  my ($table, $update_value);

  if ($params{draft}) {
    $self->_create_draft unless $self->{draft_id};
    $table = 'letter_draft';
    $update_value = 'draft_id';
  } else {
    $self->_create unless $self->{id};
    $table = 'letter';
    $update_value = 'id';
  }

  my %fields         = __PACKAGE__->_get_fields;
  my %field_mappings = __PACKAGE__->_get_field_mappings;

  delete $fields{id};

  my @update_fields = keys %fields;
  my $set_clause    = join ', ', map { "$_ = ?" } @update_fields;
  my @values        = map { _escaper($_)->( $self->{ $field_mappings{$_} || $_ } ) } @update_fields, $update_value;

  my $query = "UPDATE $table SET $set_clause WHERE id = ?";

  do_query($::form, $dbh, $query, @values);

  $dbh->commit;

  $::lxdebug->leave_sub;
}

sub find {
  $::lxdebug->enter_sub;

  my $class    = ref $_[0] || $_[0]; shift;
  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $dbh      = $form->get_standard_dbh($myconfig);
  my %params   = @_;
  my $letter_table = 'letter';

  $letter_table = 'letter_draft' if $params{draft};
  %params = %$form if  !scalar keys %params;

  my (@wheres, @values);
  my $add_token = sub { add_token(\@wheres, \@values, @_) };

  $add_token->(col => 'letter.id',           val => $params{id},           esc => 'id'    ) if $params{id};
  $add_token->(col => 'letter.letternumber', val => $params{letternumber}, esc => 'substr') if $params{letternumber};
  $add_token->(col => 'vc.name',             val => $params{customer},     esc => 'substr') if $params{customer};
  $add_token->(col => 'vc.id',               val => $params{customer_id},  esc => 'id'    ) if $params{customer_id};
  $add_token->(col => 'letter.cp_id',        val => $params{cp_id},        esc => 'id'    ) if $params{cp_id};
  $add_token->(col => 'ct.cp_name',          val => $params{contact},      esc => 'substr') if $params{contact};
  $add_token->(col => 'letter.subject',      val => $params{subject},      esc => 'substr') if $params{subject};
  $add_token->(col => 'letter.body',         val => $params{body},         esc => 'substr') if $params{body};
  $add_token->(col => 'letter.date',         val => $params{date_from}, method => '>='    ) if $params{date_from};
  $add_token->(col => 'letter.date',         val => $params{date_to},   method => '<='    ) if $params{date_to};

  my $query = qq|
    SELECT $letter_table.*, vc.name AS customer, vc.id AS customer_id, ct.cp_name AS contact FROM $letter_table
      LEFT JOIN customer vc ON vc.id = $letter_table.vc_id
      LEFT JOIN contacts ct ON $letter_table.cp_id = ct.cp_id
  |;

  if (@wheres) {
    $query .= ' WHERE ' . join ' AND ', @wheres;
  }

  my @results = selectall_hashref_query($form, $dbh, $query, @values);
  my @objects = map { $class->new($_) } @results;

  $::lxdebug->leave_sub;

  return @objects;
}

sub delete {
  $::lxdebug->enter_sub;

  my $self     = shift;

  do_query($::form, $::form->get_standard_dbh, <<SQL, $self->{id});
    DELETE FROM letter WHERE id = ?
SQL

  $::form->get_standard_dbh->commit;

  $::lxdebug->leave_sub;
}

sub delete_drafts {
  $::lxdebug->enter_sub;

  my $self        = shift;
  my @draft_ids   = @_;

  my $form        = $main::form;
  my $myconfig = \%main::myconfig;
  my $dbh         = $form->get_standard_dbh($myconfig);


  return $main::lxdebug->leave_sub() unless (@draft_ids);

  my  $query = qq|DELETE FROM letter_draft WHERE id IN (| . join(", ", map { "?" } @draft_ids) . qq|)|;
  do_query($form, $dbh, $query, @draft_ids);

  $dbh->commit;

  $::lxdebug->leave_sub;
}


sub check_number {
  my $self = shift;

  return if $self->{letternumber}
         && $self->{id}
         && 1 == scalar __PACKAGE__->find(letternumber => $self->{letternumber});

  $self->{letternumber} = SL::TransNumber->new(type => 'letter', id => $self->{id}, number => $self->{letternumber})->create_unique;
}

sub check_name {
  my $self   = shift;
  my %params = @_;

  unless ($params{_name_selected}) {
    $::form->{$_} = $self->{$_} for qw(oldcustomer customer selectcustomer customer_id);

    if (::check_name('customer')) {
      $self->_set_customer_from($::form);
    }
  } else {
    $self->_set_customer_from($::form);
  }
}

sub _set_customer_from {
  my $self = shift;
  my $from = shift;

  $self->{$_} = $from->{$_} for qw(oldcustomer customer_id customer selectcustomer);

  $self;
}

sub check_date {
  my $self = shift;
  $self->{date} ||= $::form->current_date(\%::myconfig);
}

sub load {
  my $self   = shift;
  my $table  = 'letter';
  my $draft = $self->{draft};
  $table     = 'letter_draft' if $draft;


  return $self unless $self && $self->{id}; # no id? dont load.

  my %mappings      = _get_field_mappings();
  my $mapped_select = join ', ', '*', map { "$_ AS $mappings{$_}" } keys %mappings;

  my ($db_letter) = selectfirst_hashref_query($::form, $::form->get_standard_dbh, <<SQL, $self->{id});
    SELECT $mapped_select FROM $table WHERE id = ?
SQL

  $self->update_from($db_letter);
  $self->_resolve_customer;
  $self->set_greetings;
  $self->{draft_id} = delete $self->{id} if $draft;  # set draft if we have one

  return $self;
}

sub update_from {
  my $self   = shift;
  my $src    = shift;
  my %fields = $self->_get_fields;

  $fields{$_} = $src->{$_} for qw{customer_id customer selectcustomer oldcustomer}; # customer stuff

  $self->{$_} = $src->{$_} for keys %fields;

  return $self;
}

sub export_to {
  my $self = shift;
  my $form = shift;

  my %fields         = $self->_get_fields;
  my %field_mappings = $self->_get_field_mappings;

  for (keys %fields) {
    $form->{$_} =  _escaper($_)->( $self->{ $field_mappings{$_} || $_ } );
  }
}

sub language {
  my $self = shift;
  die 'not a setter' if @_;

  return unless $self->{cp_id};

  # umetec/cetaq only!
  # contacts have a custom variable called "mailing"
  # it contains either a language code or the string "No"

  my $custom_variables = CVar->get_custom_variables(
    module      => 'Contacts',
    name_prefix => 'cp',
    trans_id    => $self->{cp_id},
  );

  my ($mailing) = grep { $_->{name} eq 'Mailing' } @$custom_variables;

  return $mailing->{value} eq 'No' ? undef : $mailing->{value};
}

sub set_greetings {
  $::lxdebug->enter_sub;

  my $self = shift;
  return $::lxdebug->leave_sub if $self->{greeting};

  # automatically set greetings
  # greetings depend mainly on contact person
#   my $contact = $self->_get_contact;

  $self->{greeting} = $::locale->text('Dear Sir or Madam,');

  $::lxdebug->leave_sub;
}

sub _lastname_used {
  # wrapper for form lastname_used
  # sets customer to last used customer,
  # also used to initalize customer for new objects
  my $self = shift;

  return if $self->{customer_id};

  my $saved_form = save_form($::form);

  $::form->lastname_used($::form->get_standard_dbh, \%::myconfig, 'customer');

  $self->{customer_id} = $::form->{customer_id};
  $self->{customer}    = $::form->{customer};

  restore_form($saved_form);

  return $self;
}

sub _resolve_customer {
  # used if an object is created with only id.
  my $self = shift;

  return unless $self->{customer_id} && !$self->{customer};

#  my ($customer) = CT->find_by_id(cv => 'customer', id => $self->{customer_id});
#  my ($customer) = CT->find_by_id(cv => 'customer', id => $self->{customer_id});
  # SL/CVar.pm:        : $cfg->{type} eq 'customer'  ? (SL::DB::Manager::Customer->find_by(id => 1*$ref->{number_value}) || SL::DB::Customer->new)->name
  $self->{customer} = SL::DB::Manager::Customer->find_by(id => $self->{customer_id})->name; # || SL::DB::Customer->new)->name


}

sub _get_definition {
  $DEFINITION;
}

sub _get_field_mappings {
  return (
    vc_id => 'customer_id',
  );
}

sub _get_fields {
  my %fields = _get_definition() =~ /(\w+) \s+ \| \s+ (integer|text|timestamp|numeric|date)/xg;
}

sub _escaper {
  my $field_name = shift;
  my %fields     = __PACKAGE__->_get_fields;

  for ($fields{$field_name}) {
    return sub { conv_i(shift) } if /integer/;
    return sub { shift };
  }
}

1;
