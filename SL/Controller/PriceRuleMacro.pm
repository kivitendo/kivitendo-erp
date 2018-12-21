package SL::Controller::PriceRuleMacro;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::PriceRuleMacro;
use SL::Locale::String qw(t8);
use SL::Presenter;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw() ],
  'scalar --get_set_init' => [ qw(price_rule_macro) ],
);

__PACKAGE__->run_before('check_auth');

sub action_load {
  my ($self) = @_;

  $self->price_rule_macro->update_definition;

  if ($::request->type eq 'json') {
    return $self->render(\$self->price_rule_macro->json_definition, { process => 0, type => 'json'});
  } else {
    die "request type not supported";
  }
}

sub action_save {
  my ($self) = @_;

  my $error;
  my ($macro, $new_macro);

  eval {
    $macro     = $self->price_rule_macro;
    $new_macro = $self->from_json_definition;

    my @price_sources;
    my ($keep, $add, $remove);

    if ($macro->id) {
      ($keep, $add, $remove) = $self->reconcile_generated_price_sources($macro, $new_macro);

      # set removes rules to obsolete
      $_->assign_attributes(obsolete => 1, price_rule_macro_id => undef) for @$remove;

      $macro->definition($new_macro->definition);
      $macro->update_from_definition;
    } else {
      $macro = $new_macro;
      ($keep, $add, $remove) = ([], [ $macro->parsed_definition->price_rules ], []);
    }

    $macro->copy_attributes_to_price_rules(@$keep, @$add);

    $macro->db->with_transaction(sub {
      $_->save for @$remove;

      $macro->update_definition;
      $macro->save;
      $macro->load;

      for (@$keep, @$add) {
        $_->price_rule_macro_id($macro->id);
        $_->items($_->items); # male sure rose knows to add the rule items
        $_->save(cascade => 1);
      }
      1;
    }) or do {
      die $macro->db->error;
    }
  } or do {
    $error = $@ // $macro->db->error;
  };

  if ($::request->type eq 'json') {
    if ($error) {
      return $self->render(\SL::JSON::to_json({ error => $error }), { process => 0, type => 'json' });
    } else {
      return $self->render(\SL::JSON::to_json({ id => $macro->id }), { process => 0, type => 'json' });
    }
  } else {
    die "not supported";
  }
}

sub action_meta {
  my ($self) = @_;

  if ($::request->type eq 'json') {
    my $meta_definition = SL::DB::PriceRuleMacro->create_definition_meta;

    for (keys %$meta_definition) {
      my $entry = $meta_definition->{$_};
      my $request_suffix = $::request->type ne 'html' ? '.' . $::request->type : '';

      if ($entry->{internal_class} && $entry->{internal_class}->can('picker')) {
        $entry->{picker_url} = $self->url_for(action => 'render_picker' . $request_suffix , type => $_);
      }
    }

    return $_[0]->render(\SL::JSON::to_json($meta_definition), { process => 0, type => 'json' });
  } else {
    die "not supported";
  }
}

sub action_render_picker {
  my ($self) = @_;

  my $meta   = SL::DB::PriceRuleMacro->create_definition_meta;
  my $type  = $meta->{$::form->{type}} or die "unknown type '$::form->{type}'";
  die "type '$::form->{type}' does not support picker" unless $type->{internal_class}->can('picker');

  my $picker_html = $type->{internal_class}->picker(%{$::form});

  if ($::request->type eq 'json') {
    my $response = { html => $picker_html, js => $::request->presenter->need_reinit_widgets ? 'kivi.reinit_widgets' : '' };
    return $self->render(\SL::JSON::to_json($response), { process => 0, type => 'json' });
  } else {
    return $self->render(\$picker_html, { process => 0 });
  }
}

### internal

sub reconcile_generated_price_sources {
  my ($self, $old_macro, $new_macro) = @_;

  my @old_rules = $old_macro->price_rules;
  my @new_rules = $new_macro->parsed_definition->price_rules;

  my %new_by_digest = map { $_->digest => $_ } @new_rules;

  my (@keep, @remove, @add);
  for (@old_rules) {
    if ($new_by_digest{$_->digest}) {
      push @keep, $_;
    } else {
      push @remove, $_;
    }
  }
  push @add, values %new_by_digest;

  return (\@keep, \@add, \@remove);
}

sub init_price_rule_macro {
  my ($self) = @_;

  my $price_rule_macro = SL::DB::Manager::PriceRuleMacro->find_by_or_create(id => $::form->{price_rule_macro}{id});
}

sub from_json_definition {
  my ($self) = @_;

  my $obj = SL::DB::PriceRuleMacro->new(%{ $::form->{price_rule_macro} });
  $obj->update_from_definition;
  $obj;
}

sub check_auth {
  $::auth->assert('price_rules');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::PriceRuleMacro - controller for price rule macros

=head1 ACTIONS

=over 4

=item * C<load>

=item * C<save>

=item * C<meta>

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut

