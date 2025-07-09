#!/usr/bin/perl -l

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use strict;
#use warnings; # corelist and find throw tons of warnings
use File::Find;
use Module::CoreList;
use SL::InstallationCheck;
use Term::ANSIColor;
use Getopt::Long;

my (%uselines, %modules, %supplied, %requires);

# since the information which classes belong to a cpan distribution is not
# easily obtained, I'll just hard code the bigger ones we use here. the same
# hash will be filled later with information gathered from the source files.
%requires = (
  'DateTime' => {
    'DateTime::Duration'                 => 1,
    'DateTime::Infinite'                 => 1,
  },
  'Exception::Class' => {
    'Exception::Class::Base'             => 1,
  },
  'Rose::DB' => {
    'Rose::DB::Cache'                    => 1,
  },
  'Rose::DB::Object' => {
   'Rose::DB::Object::ConventionManager' => 1,
   'Rose::DB::Object::Manager'           => 1,
   'Rose::DB::Object::Metadata'          => 1,
   'Rose::DB::Object::Helpers'           => 1,
   'Rose::DB::Object::Util'              => 1,
   'Rose::DB::Object::Constants'         => 1,
  },
  'Rose::Object' => {
    'Rose::Object::MakeMethods::Generic' => 1,
  },
  'Template' => {
    'Template::Constants'                => 1,
    'Template::Exception'                => 1,
    'Template::Iterator'                 => 1,
    'Template::Plugin'                   => 1,
    'Template::Plugin::Filter'           => 1,
    'Template::Plugin::HTML'             => 1,
    'Template::Stash'                    => 1,
  },
  'Devel::REPL' => {
    'namespace::clean'                   => 1,
  },
  'Email::MIME' => {
    'Email::MIME::Creator'               => 1,
  },
  'Test::Harness' => {
    'TAP::Parser'                        => 1,
    'TAP::Parser::Aggregator'            => 1,
  },
  'Archive::Zip' => {
    'Archive::Zip::Member'               => 1,
  },
  'HTML::Parser' => {
    'HTML::Entities'                     => 1,
  },
  'URI' => {
    'URI::Escape'                        => 1,
  },
  'File::MimeInfo' => {
    'File::MimeInfo::Magic'              => 1,
  },
);

GetOptions(
  'files-with-match|l' => \ my $l,
);

chmod($FindBin::Bin . '/..');

find(sub {
  return unless /(\.p[lm]|console)$/;

  # remember modules shipped with kivitendo
  $supplied{modulize($File::Find::name)}++
    if $File::Find::dir =~ m#modules/#;

  open my $fh, '<', $_ or warn "can't open $_: $!";
  while (<$fh>) {
    chomp;
    next if !/^use /;
    next if /SL::/;
    next if /Support::Files/; # our own test support module
    next if /use (warnings|strict|vars|lib|constant|utf8)/;
    next if /^use (it|the|with)/;

    my ($useline) = m/^use\s+(.*?)$/;

    next if  $useline =~ /^[\d._]+;/; # skip version requirements
    next if !$useline;

    $uselines{$useline} ||= [];
    push @{ $uselines{$useline} }, $File::Find::name;
  }
}, '.');

for my $useline (keys %uselines) {
  $useline =~ s/#.*//; # kill comments

  # modules can be loaded implicitly with use base qw(Module) or use parent
  # 'Module'. catch these:
  my ($module, $args) = $useline =~ /
    (?:
      (?:base|parent)
      \s
      (?:'|"|qw.)
    )?                 # optional parent block
    ([\w:]+)           # the module
    (.*)               # args
  /ix;

  # some comments looks very much like use lines
  # try to get rid of them
  next if $useline =~ /^it like a normal Perl node/;   # YAML::Dump comment
  next if $useline =~ /^most and offer that in a small/; # YAML

  my $version = Module::CoreList->first_release($module);
  $modules{$module} = { status => $supplied{$module}     ? 'included'
                                : $version               ? sprintf '%2.6f', $version
                                : is_required($module)   ? 'required'
                                : is_optional($module)   ? 'optional'
                                : is_developer($module)  ? 'developer'
                                : '!missing',
                        files  => $uselines{$useline},
                      };

  # build requirement tree
  for my $file (@{ $uselines{$useline} }) {
    next if $file =~ /\.pl$/;
    my $orig_module = modulize($file);
    $requires{$orig_module} ||= {};
    $requires{$orig_module}{$module}++;
  }
}

# have all documented modules mentioned here
$modules{$_->{name}} ||= { status => 'required' } for @SL::InstallationCheck::required_modules;
$modules{$_->{name}} ||= { status => 'optional' } for @SL::InstallationCheck::optional_modules;
$modules{$_->{name}} ||= { status => 'developer' } for @SL::InstallationCheck::developer_modules;

# build transitive closure for documented dependencies
my $changed = 1;
while ($changed) {
  $changed = 0;
  for my $src_module (keys %requires) {
    for my $dst_module (keys %{ $requires{$src_module} }) {
      if (   $modules{$src_module}
          && $modules{$dst_module}
          && $modules{$src_module}->{status} =~ /^(required|devel|optional)/
          && $modules{$dst_module}->{status} eq '!missing') {
        $modules{$dst_module}->{status} = "required"; # . ", via $src_module";
        $changed = 1;
      }
    }
  }
}

do {
  print sprintf "%8s : %s", color_text($modules{$_}->{status}), $_;
  if ($l) {
    print " $_" for @{ $modules{$_}->{files} || [] };
  }
} for sort {
       $modules{$a}->{status} cmp $modules{$b}->{status}
    ||                    $a  cmp $b
  } keys %modules;

sub modulize {
  for (my ($name) = @_) {
    s#^./modules/\w+/##;
    s#^./##;
    s#.pm$##;
    s#/#::#g;
    return $_;
  }
}

sub is_required {
  my ($module) = @_;
  grep { $_->{name} eq $module } @SL::InstallationCheck::required_modules;
}

sub is_optional {
  my ($module) = @_;
  grep { $_->{name} eq $module } @SL::InstallationCheck::optional_modules;
}

sub is_developer {
  my ($module) = @_;
  grep { $_->{name} eq $module } @SL::InstallationCheck::developer_modules;
}

sub color_text {
  my ($text) = @_;
  return color(get_color($text)) . $text . color('reset');
}

sub get_color {
  for (@_) {
    return 'yellow' if /^5./ && $_ > 5.008;
    return 'green'  if /^5./;
    return 'green'  if /^included/;
    return 'red'    if /^!missing/;
    return 'yellow';
  }
}

1;

__END__

=head1 NAME

find-use

=head1 EXAMPLE

 # perl scipts/find-use.pl
 !missing : Template::Constants
 !missing : DBI

=head1 EXPLANATION

This util is useful for package builders to identify all the CPAN dependencies
we have. It requires Module::CoreList (which is core since 5.9) to determine if
a module is distributed with perl or not.  The output will be one of the
following:

=over 4

=item VERSION

If a version string is displayed, the module is core since this version.
Everything up to 5.8 is alright. 5.10 (aka 5.010) is acceptable, but should be
documented. Please do not use 5.12 core modules without adding an explicit
requirement.

=item included

This module is included in C<modules/*>. Don't worry about it.

=item required

This module is documented in C<SL:InstallationCheck> to be necessary, or is a
dependency of one of these. Everything alright.

=item !missing

These modules are neither core, nor included, nor required. This is ok for
developer tools, but should never occur for modules the actual program uses.

=back

=head1 AUTHOR

http://www.ledgersmb.org/ - The LedgerSMB team
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=head1 LICENSE

Distributed under the terms of the GNU General Public License v2.

=cut
