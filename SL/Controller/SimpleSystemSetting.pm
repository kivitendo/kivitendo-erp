package SL::Controller::SimpleSystemSetting;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::System::Process;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(type config) ],
  'scalar --get_set_init' => [ qw(defaults object all_objects class manager_class list_attributes list_url supports_reordering) ],
);

__PACKAGE__->run_before('check_type_and_auth');
__PACKAGE__->run_before('setup_javascript', only => [ qw(add create edit update delete) ]);

# Make locales.pl happy: $self->render("simple_system_setting/_default_form")

my %supported_types = (
  bank_account => {
    # Make locales.pl happy: $self->render("simple_system_setting/_bank_account_form")
    class  => 'BankAccount',
    titles => {
      list => t8('Bank accounts'),
      add  => t8('Add bank account'),
      edit => t8('Edit bank account'),
    },
    list_attributes => [
      { method => 'name',                                      title => t8('Name'), },
      { method => 'iban',                                      title => t8('IBAN'), },
      { method => 'qr_iban',                                   title => t8('QR-IBAN (Swiss)'), },
      { method => 'bank',                                      title => t8('Bank'), },
      { method => 'bank_code',                                 title => t8('Bank code'), },
      { method => 'bank_account_id',                           title => t8('Bank Account Id Number (Swiss)'), },
      { method => 'bic',                                       title => t8('BIC'), },
      {                                                        title => t8('Use with bank import'), formatter => sub { $_[0]->use_with_bank_import ? t8('yes') : t8('no') } },
      {                                                        title => t8('Use for Factur-X/ZUGFeRD'), formatter => sub { $_[0]->use_for_zugferd ? t8('yes') : t8('no') } },
      {                                                        title => t8('Use for Swiss QR-Bill'), formatter => sub { $_[0]->use_for_qrbill ? t8('yes') : t8('no') } },
      { method => 'reconciliation_starting_date_as_date',      title => t8('Date'),    align => 'right' },
      { method => 'reconciliation_starting_balance_as_number', title => t8('Balance'), align => 'right' },
    ],
  },

  business => {
    # Make locales.pl happy: $self->render("simple_system_setting/_business_form")
    class  => 'Business',
    titles => {
      list => t8('Businesses'),
      add  => t8('Add business'),
      edit => t8('Edit business'),
    },
    list_attributes => [
      { method => 'description',         title => t8('Description'), },
      {                                  title => t8('Discount'), formatter => sub { $_[0]->discount_as_percent . ' %' }, align => 'right' },
      { method => 'customernumberinit',  title => t8('Customernumberinit'), },
    ],
  },

  contact_department => {
    class  => 'ContactDepartment',
    auth   => 'config',
    titles => {
      list => t8('Contact Departments'),
      add  => t8('Add department'),
      edit => t8('Edit department'),
    },
  },

  contact_title => {
    class  => 'ContactTitle',
    auth   => 'config',
    titles => {
      list => t8('Contact Titles'),
      add  => t8('Add title'),
      edit => t8('Edit title'),
    },
  },

  department => {
    class  => 'Department',
    titles => {
      list => t8('Departments'),
      add  => t8('Add department'),
      edit => t8('Edit department'),
    },
  },

  greeting => {
    class  => 'Greeting',
    auth   => 'config',
    titles => {
      list => t8('Greetings'),
      add  => t8('Add greeting'),
      edit => t8('Edit greeting'),
    },
  },

  language => {
    # Make locales.pl happy: $self->render("simple_system_setting/_language_form")
    class  => 'Language',
    titles => {
      list => t8('Languages'),
      add  => t8('Add language'),
      edit => t8('Edit language'),
    },
    list_attributes => [
      { method => 'description',   title => t8('Description'), },
      { method => 'template_code', title => t8('Template Code'), },
      { method => 'article_code',  title => t8('Article Code'), },
      {                            title => t8('Number Format'), formatter => sub { $_[0]->output_numberformat || t8('use program settings') } },
      {                            title => t8('Date Format'),   formatter => sub { $_[0]->output_dateformat   || t8('use program settings') } },
      {                            title => t8('Long Dates'),    formatter => sub { $_[0]->output_longdates ? t8('yes') : t8('no') } },
      {                            title => t8('Obsolete'),      formatter => sub { $_[0]->obsolete  ? t8('yes') : t8('no') } },
    ],
  },

  part_classification => {
    # Make locales.pl happy: $self->render("simple_system_setting/_part_classification_form")
    class  => 'PartClassification',
    titles => {
      list => t8('Part classifications'),
      add  => t8('Add part classification'),
      edit => t8('Edit part classification'),
    },
    list_attributes => [
      { title => t8('Description'),       formatter => sub { t8($_[0]->description) } },
      { title => t8('Type abbreviation'), formatter => sub { t8($_[0]->abbreviation) } },
      { title => t8('Used for Purchase'), formatter => sub { $_[0]->used_for_purchase ? t8('yes') : t8('no') } },
      { title => t8('Used for Sale'),     formatter => sub { $_[0]->used_for_sale     ? t8('yes') : t8('no') } },
      { title => t8('Report separately'), formatter => sub { $_[0]->report_separate   ? t8('yes') : t8('no') } },
    ],
  },

  parts_group => {
    # Make locales.pl happy: $self->render("simple_system_setting/_parts_group_form")
    class  => 'PartsGroup',
    titles => {
      list => t8('Partsgroups'),
      add  => t8('Add partsgroup'),
      edit => t8('Edit partsgroup'),
    },
    list_attributes => [
      { method => 'partsgroup', title => t8('Description') },
      { method => 'obsolete',   title => t8('Obsolete'), formatter => sub { $_[0]->obsolete ? t8('yes') : t8('no') } },
    ],
  },

  price_factor => {
    # Make locales.pl happy: $self->render("simple_system_setting/_price_factor_form")
    class  => 'PriceFactor',
    titles => {
      list => t8('Price Factors'),
      add  => t8('Add Price Factor'),
      edit => t8('Edit Price Factor'),
    },
    list_attributes => [
      { method => 'description',      title => t8('Description') },
      { method => 'factor_as_number', title => t8('Factor'), align => 'right' },
    ],
  },

  pricegroup => {
    # Make locales.pl happy: $self->render("simple_system_setting/_pricegroup_form")
    class  => 'Pricegroup',
    titles => {
      list => t8('Pricegroups'),
      add  => t8('Add pricegroup'),
      edit => t8('Edit pricegroup'),
    },
    list_attributes => [
      { method => 'pricegroup', title => t8('Description') },
      { method => 'obsolete',   title => t8('Obsolete'), formatter => sub { $_[0]->obsolete ? t8('yes') : t8('no') } },
    ],
  },

  order_status => {
    # Make locales.pl happy: $self->render("simple_system_setting/_order_status_form")
    class  => 'OrderStatus',
    titles => {
      list => t8('RFQ/Order Statuses'),
      add  => t8('Add rfq/order status'),
      edit => t8('Edit rfq/order status'),
    },
    list_attributes => [
      { method => 'name',        title => t8('Name') },
      { method => 'description', title => t8('Description') },
      { method => 'obsolete',    title => t8('Obsolete'), formatter => sub { $_[0]->obsolete ? t8('yes') : t8('no') } },
    ],
  },

  project_status => {
    class  => 'ProjectStatus',
    titles => {
      list => t8('Project statuses'),
      add  => t8('Add project status'),
      edit => t8('Edit project status'),
    },
  },

  project_type => {
    class  => 'ProjectType',
    titles => {
      list => t8('Project types'),
      add  => t8('Add project type'),
      edit => t8('Edit project type'),
    },
  },

  requirement_spec_acceptance_status => {
    # Make locales.pl happy: $self->render("simple_system_setting/_requirement_spec_acceptance_status_form")
    class  => 'RequirementSpecAcceptanceStatus',
    titles => {
      list => t8('Acceptance Statuses'),
      add  => t8('Add acceptance status'),
      edit => t8('Edit acceptance status'),
    },
    list_attributes => [
      { method => 'name',        title => t8('Name') },
      { method => 'description', title => t8('Description') },
    ],
  },

  requirement_spec_complexity => {
    class  => 'RequirementSpecComplexity',
    titles => {
      list => t8('Complexities'),
      add  => t8('Add complexity'),
      edit => t8('Edit complexity'),
    },
  },

  requirement_spec_predefined_text => {
    # Make locales.pl happy: $self->render("simple_system_setting/_requirement_spec_predefined_text_form")
    class  => 'RequirementSpecPredefinedText',
    titles => {
      list => t8('Pre-defined Texts'),
      add  => t8('Add pre-defined text'),
      edit => t8('Edit pre-defined text'),
    },
    list_attributes => [
      { method => 'description', title => t8('Description') },
      { method => 'title',       title => t8('Title') },
      {                          title => t8('Content'),                 formatter => sub { my $t = $_[0]->text_as_stripped_html; length($t) > 50 ? substr($t, 0, 50) . '…' : $t } },
      {                          title => t8('Useable for text blocks'), formatter => sub { $_[0]->useable_for_text_blocks ? t8('yes') : t8('no') } },
      {                          title => t8('Useable for sections'),    formatter => sub { $_[0]->useable_for_sections    ? t8('yes') : t8('no') } },
    ],
  },

  requirement_spec_risk => {
    class  => 'RequirementSpecRisk',
    titles => {
      list => t8('Risk levels'),
      add  => t8('Add risk level'),
      edit => t8('Edit risk level'),
    },
  },

  requirement_spec_status => {
    # Make locales.pl happy: $self->render("simple_system_setting/_requirement_spec_status_form")
    class  => 'RequirementSpecStatus',
    titles => {
      list => t8('Requirement Spec Statuses'),
      add  => t8('Add requirement spec status'),
      edit => t8('Edit requirement spec status'),
    },
    list_attributes => [
      { method => 'name',        title => t8('Name') },
      { method => 'description', title => t8('Description') },
    ],
  },

  requirement_spec_type => {
    # Make locales.pl happy: $self->render("simple_system_setting/_requirement_spec_type_form")
    class  => 'RequirementSpecType',
    titles => {
      list => t8('Requirement Spec Types'),
      add  => t8('Add requirement spec type'),
      edit => t8('Edit requirement spec type'),
    },
    list_attributes => [
      { method => 'description',                  title => t8('Description') },
      { method => 'section_number_format',        title => t8('Section number format') },
      { method => 'function_block_number_format', title => t8('Function block number format') },
    ],
  },

  time_recording_article => {
    # Make locales.pl happy: $self->render("simple_system_setting/_time_recording_article_form")
    class  => 'TimeRecordingArticle',
    auth   => 'config',
    titles => {
      list => t8('Time Recording Articles'),
      add  => t8('Add time recording article'),
      edit => t8('Edit time recording article'),
    },
    list_attributes => [
      { title => t8('Article'), formatter => sub { $_[0]->part->displayable_name } },
    ],
  },

);

my @default_list_attributes = (
  { method => 'description', title => t8('Description') },
);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_list_action_bar;
  $self->render('simple_system_setting/list', title => $self->config->{titles}->{list});
}

sub action_new {
  my ($self) = @_;

  $self->object($self->class->new);
  $self->render_form(title => $self->config->{titles}->{add});
}

sub action_edit {
  my ($self) = @_;

  $self->render_form(title => $self->config->{titles}->{edit});
}

sub action_create {
  my ($self) = @_;

  $self->object($self->class->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;

  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ($self->object->can('orphaned') && !$self->object->orphaned) {
    flash_later('error', t8('The object is in use and cannot be deleted.'));

  } elsif ( eval { $self->object->delete; 1; } ) {
    flash_later('info',  t8('The object has been deleted.'));

  } else {
    flash_later('error', t8('The object is in use and cannot be deleted.'));
  }

  $self->redirect_to($self->list_url);
}

sub action_reorder {
  my ($self) = @_;

  $self->class->reorder_list(@{ $::form->{object_id} || [] });
  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_type_and_auth {
  my ($self) = @_;

  $self->type($::form->{type});
  $self->config($supported_types{$self->type}) || die "Unsupported type";

  $::auth->assert($self->config->{auth} || 'config');

  my $pm = (map { s{::}{/}g; "${_}.pm" } $self->class)[0];
  require $pm;

  my $setup = "setup_" . $self->type;
  $self->$setup if $self->can($setup);

  1;
}

sub setup_javascript {
  $::request->layout->use_javascript("${_}.js") for qw();
}

sub init_class               { "SL::DB::"          . $_[0]->config->{class}                  }
sub init_manager_class       { "SL::DB::Manager::" . $_[0]->config->{class}                  }
sub init_object              { $_[0]->class->new(id => $::form->{id})->load                  }
sub init_all_objects         { $_[0]->manager_class->get_all_sorted                          }
sub init_list_url            { $_[0]->url_for(action => 'list', type => $_[0]->type)         }
sub init_supports_reordering { $_[0]->class->new->can('reorder_list')                        }
sub init_defaults            { SL::DB::Default->get                                          }

sub init_list_attributes {
  my ($self) = @_;

  my $method = "list_attributes_" . $self->type;

  return $self->$method if $self->can($method);
  return $self->config->{list_attributes} // \@default_list_attributes;
}

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->object->id;

  my $params = delete($::form->{object}) || { };

  $self->object->assign_attributes(%{ $params });

  my @errors;

  push @errors, $self->object->validate if $self->object->can('validate');

  if (@errors) {
    flash('error', @errors);
    return $self->render_form(title => $self->config->{titles}->{$is_new ? 'add' : 'edit'});
  }

  $self->object->save;

  flash_later('info', $is_new ? t8('The object has been created.') : t8('The object has been saved.'));

  $self->redirect_to($self->list_url);
}

sub render_form {
  my ($self, %params) = @_;

  my $sub_form_template = SL::System::Process->exe_dir . '/templates/webpages/simple_system_setting/_' . $self->type . '_form.html';

  $self->setup_render_form_action_bar;
  $self->render(
    'simple_system_setting/form',
    %params,
    sub_form_template => (-f $sub_form_template ? $self->type : 'default'),
  );
}

#
# type-specific helper functions
#

sub setup_requirement_spec_acceptance_status {
  my ($self) = @_;

  no warnings 'once';
  $self->{valid_names} = \@SL::DB::RequirementSpecAcceptanceStatus::valid_names;
}

sub setup_requirement_spec_status {
  my ($self) = @_;

  no warnings 'once';
  $self->{valid_names} = \@SL::DB::RequirementSpecStatus::valid_names;
}

sub setup_language {
  my ($self) = @_;

  $self->{numberformats} = [ '1,000.00', '1000.00', '1.000,00', '1000,00', "1'000.00" ];
  $self->{dateformats}   = [ qw(mm/dd/yy dd/mm/yy dd.mm.yy yyyy-mm-dd) ];
}

#
# action bar
#

sub setup_list_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'new', type => $self->type),
      ],
    );
  }
}

sub setup_render_form_action_bar {
  my ($self) = @_;

  my $is_new         = !$self->object->id;
  my $can_be_deleted = !$is_new
                    && (!$self->object->can("orphaned")       || $self->object->orphaned)
                    && (!$self->object->can("can_be_deleted") || $self->object->can_be_deleted);

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'SimpleSystemSetting/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'SimpleSystemSetting/delete' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new          ? t8('This object has not been saved yet.')
                  : !$can_be_deleted ? t8('The object is in use and cannot be deleted.')
                  :                    undef,
      ],

      link => [
        t8('Abort'),
        link => $self->list_url,
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::SimpleSystemSettings — a common CRUD controller for
various settings in the "System" menu

=head1 AUTHOR

Moritz Bunkus <m.bunkus@linet-services.de>

=cut
