use SL::Auth;
use SL::Form;
use SL::GenericTranslations;

sub edit_greetings {
  $lxdebug->enter_sub();

  $auth->assert('config');

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

  $form->{title} = $locale->text('Edit greetings');
  $form->header();
  print $form->parse_html_template('generictranslations/edit_greetings');

  $lxdebug->leave_sub();
}

sub save_greetings {
  $lxdebug->enter_sub();

  $auth->assert('config');

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

  $lxdebug->leave_sub();
}

1;
