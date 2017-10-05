use SL::Auth;
use SL::Form;
use SL::GenericTranslations;
use SL::Locale::String qw(t8);

use strict;

# convention:
# preset_text_$formname will generate a input textarea
# and will be preset in $form email dialog if the form name matches

my %mail_strings = (
  salutation_male                             => t8('Salutation male'),
  salutation_female                           => t8('Salutation female'),
  salutation_general                          => t8('Salutation general'),
  salutation_punctuation_mark                 => t8('Salutation punctuation mark'),
  preset_text_sales_quotation                 => t8('Preset email text for sales quotations'),
  preset_text_sales_order                     => t8('Preset email text for sales orders'),
  preset_text_sales_delivery_order            => t8('Preset email text for sales delivery orders'),
  preset_text_invoice                         => t8('Preset email text for sales invoices'),
  preset_text_request_quotation               => t8('Preset email text for requests (rfq)'),
  preset_text_purchase_order                  => t8('Preset email text for purchase orders'),
  preset_text_periodic_invoices_email_body    => t8('Preset email body for periodic invoices'),
  preset_text_periodic_invoices_email_subject => t8('Preset email subject for periodic invoices'),
);

sub edit_greetings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');

  my $translation_list = GenericTranslations->list();
  my %translations     = ();

  my @types            = qw(male female);

  foreach my $translation (@{ $translation_list }) {
    $translation->{language_id}                                                          ||= 'default';
    $translations{$translation->{language_id} . '::' . $translation->{translation_type}}   = $translation;
  }

  unshift @{ $form->{LANGUAGES} }, { 'id' => 'default', };

  foreach my $language (@{ $form->{LANGUAGES} }) {
    foreach my $type (@types) {
      $language->{$type} = { };
      my $translation    = $translations{"$language->{id}::greetings::${type}"} || { };
      $language->{$type} = $translation->{translation};
    }
  }

  setup_generictranslations_edit_greetings_action_bar();

  $form->{title} = $locale->text('Edit greetings');
  $form->header();
  print $form->parse_html_template('generictranslations/edit_greetings');

  $main::lxdebug->leave_sub();
}

sub save_greetings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');

  unshift @{ $form->{LANGUAGES} }, { };

  my @types  = qw(male female);

  foreach my $language (@{ $form->{LANGUAGES} }) {
    foreach my $type (@types) {
      GenericTranslations->save('translation_type' => "greetings::${type}",
                                'translation_id'   => undef,
                                'language_id'      => $language->{id},
                                'translation'      => $form->{"translation__" . ($language->{id} || 'default') . "__${type}"},);
    }
  }

  $form->{message} = $locale->text('The greetings have been saved.');

  edit_greetings();

  $main::lxdebug->leave_sub();
}

sub edit_sepa_strings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');

  my $translation_list = GenericTranslations->list(translation_type => 'sepa_remittance_info_pfx');
  my %translations     = map { ( ($_->{language_id} || 'default') => $_->{translation} ) } @{ $translation_list };

  my $translation_list_vc = GenericTranslations->list(translation_type => 'sepa_remittance_vc_no_pfx');
  my %translations_vc     =  map { ( ($_->{language_id} || 'default') => $_->{translation} ) } @{ $translation_list_vc };

  unshift @{ $form->{LANGUAGES} }, { 'id' => 'default', };

  foreach my $language (@{ $form->{LANGUAGES} }) {
    $language->{translation}    = $translations{$language->{id}};
    $language->{translation_vc} = $translations_vc{$language->{id}};
  }

  setup_generictranslations_edit_sepa_strings_action_bar();

  $form->{title} = $locale->text('Edit SEPA strings');
  $form->header();
  print $form->parse_html_template('generictranslations/edit_sepa_strings');

  $main::lxdebug->leave_sub();
}

sub save_sepa_strings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');

  unshift @{ $form->{LANGUAGES} }, { };

  foreach my $language (@{ $form->{LANGUAGES} }) {
    GenericTranslations->save('translation_type' => 'sepa_remittance_info_pfx',
                              'translation_id'   => undef,
                              'language_id'      => $language->{id},
                              'translation'      => $form->{"translation__" . ($language->{id} || 'default')},);
    GenericTranslations->save('translation_type' => 'sepa_remittance_vc_no_pfx',
                              'translation_id'   => undef,
                              'language_id'      => $language->{id},
                              'translation'      => $form->{"translation__" . ($language->{id} || 'default') . "__vc" },);
  }

  $form->{message} = $locale->text('The SEPA strings have been saved.');

  edit_sepa_strings();

  $main::lxdebug->leave_sub();
}
sub edit_email_strings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');
  unshift @{ $form->{LANGUAGES} }, { 'id' => 'default', };

  my (%translations, $translation_list);
  foreach (keys %mail_strings)  {
    $translation_list = GenericTranslations->list(translation_type => $_);
    %translations     = map { ( ($_->{language_id} || 'default') => $_->{translation} ) } @{ $translation_list };

    foreach my $language (@{ $form->{LANGUAGES} }) {
      $language->{$_} = $translations{$language->{id}};
    }
  }
  setup_generictranslations_edit_email_strings_action_bar();

  $form->{title} = $locale->text('Edit preset email strings');
  $form->header();
  print $form->parse_html_template('generictranslations/edit_email_strings',{ 'MAIL_STRINGS' => \%mail_strings });

  $main::lxdebug->leave_sub();
}

sub save_email_strings {
  $main::lxdebug->enter_sub();

  $main::auth->assert('config');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->get_lists('languages' => 'LANGUAGES');

  unshift @{ $form->{LANGUAGES} }, { };
  foreach my $language (@{ $form->{LANGUAGES} }) {
    foreach (keys %mail_strings)  {
      GenericTranslations->save('translation_type' => $_,
                                'translation_id'   => undef,
                                'language_id'      => $language->{id},
                                'translation'      => $form->{"translation__" . ($language->{id} || 'default') . "__" . $_},
                               );
    }
  }
  $form->{message} = $locale->text('The Mail strings have been saved.');

  edit_email_strings();

  $main::lxdebug->leave_sub();
}

sub setup_generictranslations_edit_greetings_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save_greetings" } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_generictranslations_edit_sepa_strings_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save_sepa_strings" } ],
        accesskey => 'enter',
      ],
    );
  }
}
sub setup_generictranslations_edit_email_strings_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save_email_strings" } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
