#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;
use FindBin;
use List::Util qw(first max);
use Template;

my $rel_dir = $FindBin::Bin . '/..';
my @actions;

foreach (read_file("${rel_dir}/SL/ClientJS.pm")) {
  chomp;

  next unless (m/^my \%supported_methods/ .. m/^\);/);

  push @actions, [ 'action',  $1, $2, $3 ] if m/^ \s+ '? ([a-zA-Z_:]+) '? \s*=>\s* (-? \d+) , (?: \s* \# \s+ (.+))? $/x;
  push @actions, [ 'comment', $1, $2     ] if m/^ \s+\# \s+ (.+?) (?: \s* pattern: \s+ (.+))? $/x;
}

my $longest         = max map { length($_->[1]) } grep { $_->[0] eq 'action' } @actions;
my $first           = 1;
my $default_pattern = '$(<TARGET>).<FUNCTION>(<ARGS>)';
my $pattern         = $default_pattern;
my $output          = '';

foreach my $action (@actions) {
  if ($action->[0] eq 'comment') {
    $output .= "\n" unless $first;
    $output .= "      // " . $action->[1] . "\n";

    $pattern = $action->[2] eq '<DEFAULT>' ? $default_pattern : $action->[2] if $action->[2];

  } else {
    my $args = $action->[2] == 1 ? ''
             : $action->[2] <  0 ? 'action.slice(2, action.length)'
             :                     join(', ', map { "action[$_]" } (2..$action->[2]));

    $output .= sprintf('      %s if (action[0] == \'%s\')%s ',
                       $first ? '    ' : 'else',
                       $action->[1],
                       ' ' x ($longest - length($action->[1])));

    my $function =  $action->[1];
    $function    =~ s/.*://;

    my $call     =  $action->[3] || $pattern;
    $call        =~ s/<TARGET>/'action[1]'/eg;
    $call        =~ s/<FUNCTION>/$function/eg;
    $call        =~ s/<ARGS>/$args/eg;
    $call        =~ s/<ARG(\d+)>/'action[' . ($1 + 1) . ']'/eg;

    $output .= $call . ";\n";
    $first   = 0;
  }
}

$output .= sprintf "\n      else\%sconsole.log('Unknown action: ' + action[0]);\n", ' ' x (4 + 2 + 6 + 3 + 4 + 2 + $longest + 1);

my $template = Template->new({ ABSOLUTE => 1 });
$template->process($rel_dir . '/scripts/generate_client_js_actions.tpl', { actions => $output }, $rel_dir . '/js/client_js.js') || die $template->error(), "\n";
print "js/client_js.js generated automatically.\n";
