package SL::DBUpgrade2;

use SL::Common;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(parse_dbupdate_controls sort_dbupdate_controls);

sub parse_dbupdate_controls {
  $main::lxdebug->enter_sub();

  my ($form, $dbdriver) = @_;

  my $locale = $main::locale;

  local *IN;
  my %all_controls;

  my $path = "sql/${dbdriver}-upgrade2";

  foreach my $file_name (<$path/*.sql>, <$path/*.pl>) {
    next unless (open(IN, $file_name));

    my $file = $file_name;
    $file =~ s|.*/||;

    my $control = {
      "priority" => 1000,
      "depends" => [],
    };

    while (<IN>) {
      chomp();
      next unless (/^(--|\#)\s*\@/);
      s/^(--|\#)\s*\@//;
      s/\s*$//;
      next if ($_ eq "");

      my @fields = split(/\s*:\s*/, $_, 2);
      next unless (scalar(@fields) == 2);

      if ($fields[0] eq "depends") {
        push(@{$control->{"depends"}}, split(/\s+/, $fields[1]));
      } else {
        $control->{$fields[0]} = $fields[1];
      }
    }

    $control->{charset} ||= Common::DEFAULT_CHARSET;

    _control_error($form, $file_name,
                   $locale->text("Missing 'tag' field."))
      unless ($control->{"tag"});

    _control_error($form, $file_name,
                   $locale->text("The 'tag' field must only consist of " .
                                 "alphanumeric characters or the carachters " .
                                 "- _ ( )"))
      if ($control->{"tag"} =~ /[^a-zA-Z0-9_\(\)\-]/);

    _control_error($form, $file_name,
                   sprintf($locale->text("More than one control file " .
                                         "with the tag '%s' exist."),
                           $control->{"tag"}))
      if (defined($all_controls{$control->{"tag"}}));

    _control_error($form, $file_name,
                   sprintf($locale->text("Missing 'description' field.")))
      unless ($control->{"description"});

    $control->{"priority"} *= 1;
    $control->{"priority"} = 1000 unless ($control->{"priority"});

    $control->{"file"} = $file;

    map({ delete($control->{$_}); } qw(depth applied));

    $all_controls{$control->{"tag"}} = $control;

    close(IN);
  }

  foreach my $control (values(%all_controls)) {
    foreach my $dependency (@{$control->{"depends"}}) {
      _control_error($form, $control->{"file"},
                     sprintf($locale->text("Unknown dependency '%s'."),
                             $dependency))
        if (!defined($all_controls{$dependency}));
    }

    map({ $_->{"loop"} = 0; } values(%all_controls));
    _check_for_loops($form, $control->{"file"}, \%all_controls,
                     $control->{"tag"});
  }

  map({ _dbupdate2_calculate_depth(\%all_controls, $_->{"tag"}) }
      values(%all_controls));

  $main::lxdebug->leave_sub();

  return \%all_controls;
}

sub _check_for_loops {
  my ($form, $file_name, $controls, $tag, @path) = @_;

  push(@path, $tag);

  my $ctrl = $controls->{$tag};

  if ($ctrl->{"loop"} == 1) {
    # Not done yet.
    _control_error($form, $file_name,
                   $main::locale->text("Dependency loop detected:") .
                   " " . join(" -> ", @path))
  } elsif ($ctrl->{"loop"} == 0) {
    # Not checked yet.
    $ctrl->{"loop"} = 1;
    map({ _check_for_loops($form, $file_name, $controls, $_, @path); }
        @{ $ctrl->{"depends"} });
    $ctrl->{"loop"} = 2;
  }
}

sub _control_error {
  my ($form, $file_name, $message) = @_;

  $form = $main::form;
  my $locale = $main::locale;

  $form->error(sprintf($locale->text("Error in database control file '%s': %s"),
                       $file_name, $message));
}

sub _dbupdate2_calculate_depth {
  $main::lxdebug->enter_sub();

  my ($tree, $tag) = @_;

  my $node = $tree->{$tag};

  return $main::lxdebug->leave_sub() if (defined($node->{"depth"}));

  my $max_depth = 0;

  foreach $tag (@{$node->{"depends"}}) {
    _dbupdate2_calculate_depth($tree, $tag);
    my $value = $tree->{$tag}->{"depth"};
    $max_depth = $value if ($value > $max_depth);
  }

  $node->{"depth"} = $max_depth + 1;

  $main::lxdebug->leave_sub();
}

sub sort_dbupdate_controls {
  return
    sort({ $a->{"depth"} != $b->{"depth"} ? $a->{"depth"} <=> $b->{"depth"} :
             $a->{"priority"} != $b->{"priority"} ?
             $a->{"priority"} <=> $b->{"priority"} :
             $a->{"tag"} cmp $b->{"tag"} } values(%{$_[0]}));
}


1;
