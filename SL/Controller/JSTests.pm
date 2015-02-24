package SL::Controller::JSTests;

use strict;

use parent qw(SL::Controller::Base);

use File::Find ();
use File::Spec ();
use List::UtilsBy qw(sort_by);

use SL::System::Process;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(all_scripts scripts_to_run) ],
);

#
# actions
#

sub action_run {
  my ($self) = @_;

  $::request->layout->use_stylesheet("css/qunit.css");
  $self->render('js_tests/run', title => $::locale->text('Run JavaScript unit tests'));
}

#
# helpers
#

sub init_all_scripts {
  my ($self) = @_;

  my $exe_dir = SL::System::Process->exe_dir;

  my @scripts;
  my $wanted = sub {
    return if ( ! -f $File::Find::name ) || ($File::Find::name !~ m{\.js$});
    push @scripts, File::Spec->abs2rel($File::Find::name, $exe_dir);
  };

  File::Find::find($wanted, $exe_dir . '/js/t');

  return [ sort_by { lc } @scripts ];
}

sub init_scripts_to_run {
  my ($self) = @_;
  my $filter = $::form->{file_filter} || '.';
  return [ grep { m{$filter} } @{ $self->all_scripts } ];
}

1;
