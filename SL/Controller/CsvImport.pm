package SL::Controller::CsvImport;

use strict;

use SL::DB::Buchungsgruppe;
use SL::DB::CsvImportProfile;
use SL::Helper::Flash;
use SL::SessionFile;
use SL::Controller::CsvImport::Contact;
use SL::Controller::CsvImport::CustomerVendor;
use SL::Controller::CsvImport::Part;
use SL::Controller::CsvImport::Shipto;

use List::MoreUtils qw(none);

use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(type profile file all_profiles all_charsets sep_char all_sep_chars quote_char all_quote_chars escape_char all_escape_chars all_buchungsgruppen
                import_status errors headers raw_data_headers info_headers data num_imported num_importable displayable_columns) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('ensure_form_structure');
__PACKAGE__->run_before('check_type');
__PACKAGE__->run_before('load_all_profiles');

#
# actions
#

sub action_new {
  my ($self) = @_;

  $self->load_default_profile unless $self->profile;
  $self->render_inputs;
}

sub action_test {
  my ($self) = @_;
  $self->test_and_import(test => 1);
}

sub action_import {
  my $self = shift;
  $self->test_and_import(test => 0);
}

sub action_save {
  my ($self) = @_;

  $self->profile_from_form(SL::DB::Manager::CsvImportProfile->find_by(name => $::form->{profile}->{name}));
  $self->profile->save;

  flash_later('info', $::locale->text("The profile has been saved under the name '#1'.", $self->profile->name));
  $self->redirect_to(action => 'new', 'profile.type' => $self->type, 'profile.id' => $self->profile->id);
}

sub action_destroy {
  my $self = shift;

  my $profile = SL::DB::CsvImportProfile->new(id => $::form->{profile}->{id});
  $profile->delete(cascade => 1);

  flash_later('info', $::locale->text('The profile \'#1\' has been deleted.', $profile->name));
  $self->redirect_to(action => 'new', 'profile.type' => $self->type);
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub check_type {
  my ($self) = @_;

  die "Invalid CSV import type" if none { $_ eq $::form->{profile}->{type} } qw(parts customers_vendors addresses contacts);
  $self->type($::form->{profile}->{type});
}

sub ensure_form_structure {
  my ($self, %params) = @_;

  $::form->{profile}  = {} unless ref $::form->{profile}  eq 'HASH';
  $::form->{settings} = {} unless ref $::form->{settings} eq 'HASH';
}

#
# helpers
#

sub render_inputs {
  my ($self, %params) = @_;

  $self->all_charsets([ [ 'UTF-8',       'UTF-8'                 ],
                        [ 'ISO-8859-1',  'ISO-8859-1 (Latin 1)'  ],
                        [ 'ISO-8859-15', 'ISO-8859-15 (Latin 9)' ],
                        [ 'CP850',       'CP850 (DOS/ANSI)'      ],
                        [ 'CP1252',      'CP1252 (Windows)'      ],
                      ]);

  my %char_map = $self->char_map;

  foreach my $type (qw(sep quote escape)) {
    my $sub = "all_${type}_chars";
    $self->$sub([ sort { $a->[0] cmp $b->[0] } values %{ $char_map{$type} } ]);

    my $char = $self->profile->get($type . '_char');
    $sub     = "${type}_char";
    $self->$sub(($char_map{$type}->{$char} || [])->[0] || $char);
  }

  $self->file(SL::SessionFile->new($self->csv_file_name));

  my $title = $self->type eq 'customers_vendors' ? $::locale->text('CSV import: customers and vendors')
            : $self->type eq 'addresses'         ? $::locale->text('CSV import: shipping addresses')
            : $self->type eq 'contacts'          ? $::locale->text('CSV import: contacts')
            : $self->type eq 'parts'             ? $::locale->text('CSV import: parts and services')
            : die;

  $self->all_buchungsgruppen(SL::DB::Manager::Buchungsgruppe->get_all_sorted);

  $self->setup_help;

  $self->render('csv_import/form', title => $title);
}

sub test_and_import {
  my ($self, %params) = @_;

  $self->profile_from_form;

  if ($::form->{file}) {
    my $file = SL::SessionFile->new($self->csv_file_name, mode => '>');
    $file->fh->print($::form->{file});
    $file->fh->close;
  }

  my $file = SL::SessionFile->new($self->csv_file_name, mode => '<', encoding => $self->profile->get('charset'));
  if (!$file->fh) {
    flash('error', $::locale->text('No file has been uploaded yet.'));
    return $self->action_new;
  }

  my $worker = $self->create_worker($file);
  $worker->run;
  $worker->save_objects if !$params{test};

  $self->num_importable(scalar grep { !$_ } map { scalar @{ $_->{errors} } } @{ $self->data || [] });
  $self->import_status($params{test} ? 'tested' : 'imported');

  flash('info', $::locale->text('Objects have been imported.')) if !$params{test};

  $self->action_new;
}

sub load_default_profile {
  my ($self) = @_;

  if ($::form->{profile}->{id}) {
    $self->profile(SL::DB::CsvImportProfile->new(id => $::form->{profile}->{id})->load);

  } else {
    $self->profile(SL::DB::Manager::CsvImportProfile->find_by(type => $self->{type}, is_default => 1));
    $self->profile(SL::DB::CsvImportProfile->new(type => $self->{type})) unless $self->profile;
  }

  $self->profile->set_defaults;
}

sub load_all_profiles {
  my ($self, %params) = @_;

  $self->all_profiles(SL::DB::Manager::CsvImportProfile->get_all(where => [ type => $self->type ], sort_by => 'name'));
}

sub profile_from_form {
  my ($self, $existing_profile) = @_;

  delete $::form->{profile}->{id};

  my %char_map = $self->char_map;
  my @settings;

  foreach my $type (qw(sep quote escape)) {
    my %rev_chars = map { $char_map{$type}->{$_}->[0] => $_ } keys %{ $char_map{$type} };
    my $char      = $::form->{"${type}_char"} eq 'custom' ? $::form->{"custom_${type}_char"} : $rev_chars{ $::form->{"${type}_char"} };

    push @settings, { key => "${type}_char", value => $char };
  }

  if ($self->type eq 'parts') {
    $::form->{settings}->{sellprice_adjustment} = $::form->parse_amount(\%::myconfig, $::form->{settings}->{sellprice_adjustment});
  }

  delete $::form->{profile}->{id};
  $self->profile($existing_profile || SL::DB::CsvImportProfile->new);
  $self->profile->assign_attributes(%{ $::form->{profile} });
  $self->profile->settings(map({ { key => $_, value => $::form->{settings}->{$_} } } keys %{ $::form->{settings} }),
                           @settings);
  $self->profile->set_defaults;
}

sub char_map {
  return ( sep    => { ','  => [ 'comma',     $::locale->text('Comma')     ],
                       ';'  => [ 'semicolon', $::locale->text('Semicolon') ],
                       "\t" => [ 'tab',       $::locale->text('Tab')       ],
                       ' '  => [ 'space',     $::locale->text('Space')     ],
                     },
           quote  => { '"' => [ 'quote', $::locale->text('Quotes') ],
                       "'" => [ 'singlequote', $::locale->text('Single quotes') ],
                     },
           escape => { '"' => [ 'quote', $::locale->text('Quotes') ],
                       "'" => [ 'singlequote', $::locale->text('Single quotes') ],
                     },
         );
}

sub csv_file_name {
  my ($self) = @_;
  return "csv-import-" . $self->type . ".csv";
}

sub create_worker {
  my ($self, $file) = @_;

  return $self->{type} eq 'customers_vendors' ? SL::Controller::CsvImport::CustomerVendor->new(controller => $self, file => $file)
       : $self->{type} eq 'contacts'          ? SL::Controller::CsvImport::Contact->new(       controller => $self, file => $file)
       : $self->{type} eq 'addresses'         ? SL::Controller::CsvImport::Shipto->new(        controller => $self, file => $file)
       : $self->{type} eq 'parts'             ? SL::Controller::CsvImport::Part->new(          controller => $self, file => $file)
       :                                        die "Program logic error";
}

sub setup_help {
  my ($self) = @_;

  $self->create_worker->setup_displayable_columns;
}


1;
