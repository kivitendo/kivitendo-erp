#!/usr/bin/perl -l
use strict;
#use warnings; # corelist and find throw tons of warnings
use Module::CoreList;
use File::Find;
use SL::InstallationCheck;

my (%uselines, %modules, %supplied);

find(sub {
  return unless /(\.p[lm]|console)$/;

  # remember modules shipped with Lx-Office
  $supplied{modulize($File::Find::name)}++
    if $File::Find::dir =~ m#modules/#;

  open my $fh, '<', $_ or warn "can't open $_: $!";
  while (<$fh>) {
    chomp;
    next if !/^use /;
    next if /SL::/;
    next if /Support::Files/; # our own test support module
    next if /use (warnings|strict|vars|lib|constant|utf8)/;

    my ($useline) = m/^use\s+(.*?)$/;

    next if  $useline =~ /^[\d.]+;/; # skip version requirements
    next if !$useline;

    $uselines{$useline}++;
  }
}, '.');

for my $useline (keys %uselines) {
  $useline =~ s/#.*//; # kill comments

  # modules can be loaded implicit with use base qw(Module) or use parent
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
  $modules{$module} = $supplied{$module}     ? 'included'
                    : $version               ? sprintf '%2.6f', $version
                    : is_documented($module) ? 'required'
                    : '!missing';
}

print sprintf "%8s : %s", $modules{$_}, $_
  for sort {
       $modules{$a} cmp $modules{$b}
    ||          $a  cmp $b
  } keys %modules;

sub modulize {
  for (my ($name) = @_) {
    s#^./modules/\w+/##;
    s#.pm$##;
    s#/#::#g;
    return $_;
  }
}

sub is_documented {
  my ($module) = @_;
  return grep { $_->{name} eq $module } @SL::InstallationCheck::required_modules;
}

__END__

=head1 NAME

find-use

=head1 EXAMPLE

 # perl scipts/find-use.pl
 missing : Perl::Tags
 missing : Template::Constants
 missing : DBI

=head1 EXPLANATION

This util is useful for package builders to identify all the CPAN dependencies
we've made. It requires Module::CoreList (which is core, but is not in most
stable releases of perl) to determine if a module is distributed with perl or
not.  The output reports which version of perl the module is in.  If it reports
0.000000, then the module is not in core perl, and needs to be installed before
Lx-Office will operate.

=head1 AUTHOR

http://www.ledgersmb.org/ - The LedgerSMB team
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=head1 LICENSE

Distributed under the terms of the GNU General Public License v2.

=cut


