package GenericTranslations;

use SL::DBUtils;
use SL::DB;

use strict;

sub get {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(translation_type));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $joins    = '';

  my @values   = ($params{translation_type});
  my @where    = ('gt.translation_type = ?');

  if ($params{translation_id}) {
    push @values, conv_i($params{translation_id});
    push @where,  'gt.translation_id = ?';

  } else {
    push @where,  'gt.translation_id IS NULL';
  }

  if ($params{language_id}) {
    push @values, conv_i($params{language_id});
    push @where,  $params{allow_fallback} ? '(gt.language_id IS NULL) OR (gt.language_id = ?)' : 'gt.language_id = ?';

  } else {
    push @where,  'gt.language_id IS NULL';
  }

  my $query           = qq|SELECT gt.translation
                           FROM generic_translations gt
                           $joins
                           WHERE | . join(' AND ', map { "($_)" } @where) . qq|
                           ORDER BY gt.language_id ASC|;

  my ($translation)   = selectfirst_array_query($form, $dbh, $query, @values);
  $translation      ||= $params{default};

  $main::lxdebug->leave_sub();

  return $translation;
}

sub list {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @values   = ();
  my @where    = ();

  if ($params{translation_type}) {
    push @values, $params{translation_type};
    push @where,  'translation_type = ?';
  }

  if ($params{translation_id}) {
    push @values, conv_i($params{translation_id});
    push @where,  'translation_id = ?';
  }

  my $where_s  = scalar(@where) ? 'WHERE ' . join(' AND ', map { "($_)" } @where) : '';

  my $query    = qq|SELECT id, language_id, translation_type, translation_id, translation
                    FROM generic_translations
                    $where_s|;

  my $results  = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return $results;
}

sub save {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(translation_type));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  $params{translation} =~ s/^\s+//;
  $params{translation} =~ s/\s+$//;

  my @v_insert = (conv_i($params{language_id}), $params{translation_type}, conv_i($params{translation_id}), $params{translation});
  my @v_seldel = ($params{translation_type});
  my @w_seldel = ('translation_type = ?');

  foreach (qw(language_id translation_id)) {
    if ($params{$_}) {
      push @v_seldel, conv_i($params{$_});
      push @w_seldel, "$_ = ?";
    } else {
      push @w_seldel, "$_ IS NULL";
    }
  }

  my $q_lookup = qq|SELECT id
                    FROM generic_translations
                    WHERE | . join(' AND ', map { "($_)" } @w_seldel);
  my $q_delete = qq|DELETE FROM generic_translations
                    WHERE | . join(' AND ', map { "($_)" } @w_seldel);
  my $q_update = qq|UPDATE generic_translations
                    SET translation = ?
                    WHERE id = ?|;
  my $q_insert = qq|INSERT INTO generic_translations (language_id, translation_type, translation_id, translation)
                    VALUES (?, ?, ?, ?)|;

  my ($id)     = selectfirst_array_query($form, $dbh, $q_lookup, @v_seldel);

  if ($id && !$params{translation}) {
    do_query($form, $dbh, $q_delete, @v_seldel);
  } elsif ($id) {
    do_query($form, $dbh, $q_update, $params{translation}, $id);
  } elsif ($params{translation}) {
    do_query($form, $dbh, $q_insert, @v_insert);
  }

  return 1;
}


1;
