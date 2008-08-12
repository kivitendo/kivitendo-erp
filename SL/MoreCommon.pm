package SL::MoreCommon;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(save_form restore_form compare_numbers any);

use YAML;

use SL::AM;

sub save_form {
  $main::lxdebug->enter_sub();

  my @dont_dump_keys = @_;
  my %not_dumped_values;

  foreach my $key (@dont_dump_keys) {
    $not_dumped_values{$key} = $main::form->{$key};
    delete $main::form->{$key};
  }

  my $old_form = YAML::Dump($main::form);
  $old_form =~ s|!|!:|g;
  $old_form =~ s|\n|!n|g;
  $old_form =~ s|\r|!r|g;

  map { $main::form->{$_} = $not_dumped_values{$_} } keys %not_dumped_values;

  $main::lxdebug->leave_sub();

  return $old_form;
}

sub restore_form {
  $main::lxdebug->enter_sub();

  my ($old_form, $no_delete, @keep_vars) = @_;

  my $form          = $main::form;
  my %keep_vars_map = map { $_ => 1 } @keep_vars;

  map { delete $form->{$_} if (!$keep_vars_map{$_}); } keys %{$form} unless ($no_delete);

  $old_form =~ s|!r|\r|g;
  $old_form =~ s|!n|\n|g;
  $old_form =~ s|![!:]|!|g;

  my $new_form = YAML::Load($old_form);
  map { $form->{$_} = $new_form->{$_} if (!$keep_vars_map{$_}) } keys %{ $new_form };

  $main::lxdebug->leave_sub();
}

sub compare_numbers {
  $main::lxdebug->enter_sub();

  my $a      = shift;
  my $a_unit = shift;
  my $b      = shift;
  my $b_unit = shift;

  $main::all_units ||= AM->retrieve_units(\%main::myconfig, $main::form);
  my $units          = $main::all_units;

  if (!$units->{$a_unit} || !$units->{$b_unit} || ($units->{$a_unit}->{base_unit} ne $units->{$b_unit}->{base_unit})) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  $a *= $units->{$a_unit}->{factor};
  $b *= $units->{$b_unit}->{factor};

  $main::lxdebug->leave_sub();

  return $a <=> $b;
}

sub any (&@) {
  my $f = shift;
  return if ! @_;
  for (@_) {
    return 1 if $f->();
  }
  return 0;
}

1;
