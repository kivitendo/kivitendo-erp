package SL::Controller::Base;

use parent qw(Rose::Object);

use List::Util qw(first);

sub parse_html_template {
  my $self = shift;
  my $name = shift;

  return $::form->parse_html_template($name, { @_, SELF => $self });
}

sub url_for {
  my $self = shift;

  return $_[0] if scalar(@_) == 1;

  my %params      = @_;
  my $controller  = delete($params{controller}) || $self->_controller_name;
  my $action      = delete($params{action})     || 'dispatch';
  $params{action} = "${controller}/${action}";
  my $query       = join('&', map { $::form->escape($_) . '=' . $::form->escape($params{$_}) } keys %params);

  return "controller.pl?${query}";
}

sub _run_action {
  my $self   = shift;
  my $action = "action_" . shift;

  return $self->_dispatch(@_) if $action eq 'action_dispatch';

  $::form->error("Invalid action ${action} for controller " . ref($self)) if !$self->can($action);
  $self->$action(@_);
}

sub _controller_name {
  return (split(/::/, ref($_[0])))[-1];
}

sub _dispatch {
  my $self    = shift;

  my @actions = grep { m/^action_/ } keys %{ ref($self) . "::" };
  my $action  = first { $::form->{$_} } @actions;

  $self->$action(@_);
}

1;
