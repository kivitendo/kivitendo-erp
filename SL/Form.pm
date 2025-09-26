#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors: Thomas Bayen <bayen@gmx.de>
#               Antti Kaihola <akaihola@siba.fi>
#               Moritz Bunkus (tex code)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
# Utilities for parsing forms
# and supporting routines for linking account numbers
# used in AR, AP and IS, IR modules
#
#======================================================================

package Form;

use Carp;
use Data::Dumper;

use Carp;
use CGI;
use Cwd;
use Encode;
use File::Copy;
use File::Temp ();
use IO::File;
use Math::BigInt;
use Params::Validate qw(:all);
use POSIX qw(strftime);
use SL::Auth;
use SL::Auth::DB;
use SL::Auth::LDAP;
use SL::AM;
use SL::Common;
use SL::CVar;
use SL::DB;
use SL::DBConnect;
use SL::DBUtils;
use SL::DB::AdditionalBillingAddress;
use SL::DB::Customer;
use SL::DB::CustomVariableConfig;
use SL::DB::Default;
use SL::DB::PaymentTerm;
use SL::DB::Vendor;
use SL::DO;
use SL::Helper::Flash qw();
use SL::IC;
use SL::IS;
use SL::Layout::Dispatcher;
use SL::Locale;
use SL::Locale::String;
use SL::Mailer;
use SL::Menu;
use SL::MoreCommon qw(uri_encode uri_decode);
use SL::OE;
use SL::PrefixedNumber;
use SL::Request;
use SL::Template;
use SL::User;
use SL::Util;
use SL::Version;
use SL::X;
use Template;
use URI;
use List::Util qw(first max min sum);
use List::MoreUtils qw(all any apply);
use SL::DB::Tax;
use SL::Helper::File qw(:all);
use SL::Helper::Number;
use SL::Helper::CreatePDF qw(merge_pdfs);

use strict;

sub read_version {
  SL::Version->get_version;
}

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;

  my $self = {};

  no warnings 'once';
  if ($LXDebug::watch_form) {
    require SL::Watchdog;
    tie %{ $self }, 'SL::Watchdog';
  }

  bless $self, $type;

  $main::lxdebug->leave_sub();

  return $self;
}

sub _flatten_variables_rec {
  $main::lxdebug->enter_sub(2);

  my $self   = shift;
  my $curr   = shift;
  my $prefix = shift;
  my $key    = shift;

  my @result;

  if ('' eq ref $curr->{$key}) {
    @result = ({ 'key' => $prefix . $key, 'value' => $curr->{$key} });

  } elsif ('HASH' eq ref $curr->{$key}) {
    foreach my $hash_key (sort keys %{ $curr->{$key} }) {
      push @result, $self->_flatten_variables_rec($curr->{$key}, $prefix . $key . '.', $hash_key);
    }

  } else {
    foreach my $idx (0 .. scalar @{ $curr->{$key} } - 1) {
      my $first_array_entry = 1;

      my $element = $curr->{$key}[$idx];

      if ('HASH' eq ref $element) {
        foreach my $hash_key (sort keys %{ $element }) {
          push @result, $self->_flatten_variables_rec($element, $prefix . $key . ($first_array_entry ? '[+].' : '[].'), $hash_key);
          $first_array_entry = 0;
        }
      } else {
        push @result, { 'key' => $prefix . $key . '[]', 'value' => $element };
      }
    }
  }

  $main::lxdebug->leave_sub(2);

  return @result;
}

sub flatten_variables {
  $main::lxdebug->enter_sub(2);

  my $self = shift;
  my @keys = @_;

  my @variables;

  foreach (@keys) {
    push @variables, $self->_flatten_variables_rec($self, '', $_);
  }

  $main::lxdebug->leave_sub(2);

  return @variables;
}

sub flatten_standard_variables {
  $main::lxdebug->enter_sub(2);

  my $self      = shift;
  my %skip_keys = map { $_ => 1 } (qw(login password header stylesheet titlebar), @_);

  my @variables;

  foreach (grep { ! $skip_keys{$_} } keys %{ $self }) {
    push @variables, $self->_flatten_variables_rec($self, '', $_);
  }

  $main::lxdebug->leave_sub(2);

  return @variables;
}

sub escape {
  my ($self, $str) = @_;

  return uri_encode($str);
}

sub unescape {
  my ($self, $str) = @_;

  return uri_decode($str);
}

sub quote {
  $main::lxdebug->enter_sub();
  my ($self, $str) = @_;

  if ($str && !ref($str)) {
    $str =~ s/\"/&quot;/g;
  }

  $main::lxdebug->leave_sub();

  return $str;
}

sub unquote {
  $main::lxdebug->enter_sub();
  my ($self, $str) = @_;

  if ($str && !ref($str)) {
    $str =~ s/&quot;/\"/g;
  }

  $main::lxdebug->leave_sub();

  return $str;
}

sub hide_form {
  $main::lxdebug->enter_sub();
  my $self = shift;

  if (@_) {
    map({ print($::request->{cgi}->hidden("-name" => $_, "-default" => $self->{$_}) . "\n"); } @_);
  } else {
    for (sort keys %$self) {
      next if (($_ eq "header") || (ref($self->{$_}) ne ""));
      print($::request->{cgi}->hidden("-name" => $_, "-default" => $self->{$_}) . "\n");
    }
  }
  $main::lxdebug->leave_sub();
}

sub throw_on_error {
  my ($self, $code) = @_;
  local $self->{__ERROR_HANDLER} = sub { SL::X::FormError->throw(error => $_[0]) };
  $code->();
}

sub error {
  $main::lxdebug->enter_sub();

  $main::lxdebug->show_backtrace();

  my ($self, $msg) = @_;

  if ($self->{__ERROR_HANDLER}) {
    $self->{__ERROR_HANDLER}->($msg);

  } elsif ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;
    $self->show_generic_error($msg);

  } else {
    confess "Error: $msg\n";
  }

  $main::lxdebug->leave_sub();
}

sub info {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $self->header;
    print $self->parse_html_template('generic/form_info', { message => $msg });

  } elsif ($self->{info_function}) {
    &{ $self->{info_function} }($msg);
  } else {
    print "$msg\n";
  }

  $main::lxdebug->leave_sub();
}

# calculates the number of rows in a textarea based on the content and column number
# can be capped with maxrows
sub numtextrows {
  $main::lxdebug->enter_sub();
  my ($self, $str, $cols, $maxrows, $minrows) = @_;

  $minrows ||= 1;

  my $rows   = sum map { int((length() - 2) / $cols) + 1 } split /\r/, $str;
  $maxrows ||= $rows;

  $main::lxdebug->leave_sub();

  return max(min($rows, $maxrows), $minrows);
}

sub dberror {
  my ($self, $msg) = @_;

  SL::X::DBError->throw(
    msg      => $msg,
    db_error => $DBI::errstr,
  );
}

sub isblank {
  $main::lxdebug->enter_sub();

  my ($self, $name, $msg) = @_;

  my $curr = $self;
  foreach my $part (split m/\./, $name) {
    if (!$curr->{$part} || ($curr->{$part} =~ /^\s*$/)) {
      $self->error($msg);
    }
    $curr = $curr->{$part};
  }

  $main::lxdebug->leave_sub();
}

sub _get_request_uri {
  my $self = shift;

  return URI->new($ENV{HTTP_REFERER})->canonical() if $ENV{HTTP_X_FORWARDED_FOR};
  return URI->new                                  if !$ENV{REQUEST_URI}; # for testing

  my $scheme =  $::request->is_https ? 'https' : 'http';
  my $port   =  $ENV{SERVER_PORT};
  $port      =  undef if (($scheme eq 'http' ) && ($port == 80))
                      || (($scheme eq 'https') && ($port == 443));

  my $uri    =  URI->new("${scheme}://");
  $uri->scheme($scheme);
  $uri->port($port);
  $uri->host($ENV{HTTP_HOST} || $ENV{SERVER_ADDR});
  $uri->path_query($ENV{REQUEST_URI});
  $uri->query('');

  return $uri;
}

sub _add_to_request_uri {
  my $self              = shift;

  my $relative_new_path = shift;
  my $request_uri       = shift || $self->_get_request_uri;
  my $relative_new_uri  = URI->new($relative_new_path);
  my @request_segments  = $request_uri->path_segments;

  my $new_uri           = $request_uri->clone;
  $new_uri->path_segments(@request_segments[0..scalar(@request_segments) - 2], $relative_new_uri->path_segments);

  return $new_uri;
}

sub create_http_response {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $cgi      = $::request->{cgi};

  my $session_cookie;
  if (defined $main::auth) {
    my $uri      = $self->_get_request_uri;
    my @segments = $uri->path_segments;
    pop @segments;
    $uri->path_segments(@segments);

    my $session_cookie_value = $main::auth->get_session_id();

    if ($session_cookie_value) {
      $session_cookie = $cgi->cookie('-name'    => $main::auth->get_session_cookie_name(),
                                     '-value'   => $session_cookie_value,
                                     '-path'    => $uri->path,
                                     '-expires' => '+' . $::auth->{session_timeout} . 'm',
                                     '-secure'  => $::request->is_https);
      $session_cookie = "$session_cookie; SameSite=strict";
    }
  }

  my %cgi_params = ('-type' => $params{content_type});
  $cgi_params{'-charset'} = $params{charset} if ($params{charset});
  $cgi_params{'-cookie'}  = $session_cookie  if ($session_cookie);

  map { $cgi_params{'-' . $_} = $params{$_} if exists $params{$_} } qw(content_disposition content_length status);

  my $output = $cgi->header(%cgi_params);

  $main::lxdebug->leave_sub();

  return $output;
}

sub header {
  $::lxdebug->enter_sub;

  my ($self, %params) = @_;
  my @header;

  $::lxdebug->leave_sub and return if !$ENV{HTTP_USER_AGENT} || $self->{header}++;

  if ($params{no_layout}) {
    $::request->{layout} = SL::Layout::Dispatcher->new(style => 'none');
  }

  my $layout = $::request->{layout};

  # standard css for all
  # this should gradually move to the layouts that need it
  $layout->use_stylesheet("$_.css") for qw(
    common main menu list_accounts jquery.autocomplete
    jquery.multiselect2side
    ui-lightness/jquery-ui
    jquery-ui.custom
    tooltipster themes/tooltipster-light
  );

  $layout->use_javascript("$_.js") for (qw(
    jquery jquery-ui jquery.cookie jquery.checkall jquery.download
    jquery/jquery.form jquery/fixes namespace client_js
    jquery/jquery.tooltipster.min
    common part_selection
  ), "jquery/ui/i18n/jquery.ui.datepicker-$::myconfig{countrycode}");

  $layout->use_javascript("$_.js") for @{ $params{use_javascripts} // [] };

  $self->{favicon} ||= "favicon.ico";
  $self->{titlebar} = join ' - ', grep $_, $self->{title}, $self->{login}, $::myconfig{dbname}, $self->read_version if $self->{title} || !$self->{titlebar};

  # build includes
  if ($self->{refresh_url} || $self->{refresh_time}) {
    my $refresh_time = $self->{refresh_time} || 3;
    my $refresh_url  = $self->{refresh_url}  || $ENV{REFERER};
    push @header, "<meta http-equiv='refresh' content='$refresh_time;$refresh_url'>";
  }

  my $auto_reload_resources_param = $layout->auto_reload_resources_param;

  push @header, map { qq|<link rel="stylesheet" href="${_}${auto_reload_resources_param}" type="text/css" title="Stylesheet">| } $layout->stylesheets;
  push @header, "<style type='text/css'>\@page { size:landscape; }</style> "                     if $self->{landscape};
  push @header, "<link rel='shortcut icon' href='$self->{favicon}' type='image/x-icon'>"         if -f $self->{favicon};
  push @header, map { qq|<script type="text/javascript" src="${_}${auto_reload_resources_param}"></script>| }                    $layout->javascripts;
  push @header, '<meta name="viewport" content="width=device-width, initial-scale=1">';
  push @header, $self->{javascript} if $self->{javascript};
  push @header, map { $_->show_javascript } @{ $self->{AJAX} || [] };

  my  %doctypes = (
    strict       => qq|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">|,
    transitional => qq|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">|,
    frameset     => qq|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">|,
    html5        => qq|<!DOCTYPE html>|,
  );

  # output
  print $self->create_http_response(content_type => 'text/html', charset => 'UTF-8');
  print $doctypes{$params{doctype} || $::request->layout->html_dialect}, $/;
  print <<EOT;
<html>
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <title>$self->{titlebar}</title>
EOT
  print "  $_\n" for @header;
  print <<EOT;
  <meta name="robots" content="noindex,nofollow">
 </head>
 <body>

EOT
  print $::request->{layout}->pre_content;
  print $::request->{layout}->start_content;

  $layout->header_done;

  $::lxdebug->leave_sub;
}

sub footer {
  return unless $::request->{layout}->need_footer;

  print $::request->{layout}->end_content;
  print $::request->{layout}->post_content;

  if (my @inline_scripts = $::request->{layout}->javascripts_inline) {
    print "<script type='text/javascript'>" . join("; ", @inline_scripts) . "</script>\n";
  }

  print <<EOL
 </body>
</html>
EOL
}

sub ajax_response_header {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  my $output = $::request->{cgi}->header('-charset' => 'UTF-8');

  $main::lxdebug->leave_sub();

  return $output;
}

sub redirect_header {
  my $self     = shift;
  my $new_url  = shift;

  my $base_uri = $self->_get_request_uri;
  my $new_uri  = URI->new_abs($new_url, $base_uri);

  die "Headers already sent" if $self->{header};
  $self->{header} = 1;

  return $::request->{cgi}->redirect($new_uri);
}

sub set_standard_title {
  $::lxdebug->enter_sub;
  my $self = shift;

  $self->{titlebar}  = "kivitendo " . $::locale->text('Version') . " " . $self->read_version;
  $self->{titlebar} .= "- $::myconfig{name}"   if $::myconfig{name};
  $self->{titlebar} .= "- $::myconfig{dbname}" if $::myconfig{name};

  $::lxdebug->leave_sub;
}

sub _prepare_html_template {
  $main::lxdebug->enter_sub();

  my ($self, $file, $additional_params) = @_;
  my $language;

  if (!%::myconfig || !$::myconfig{"countrycode"}) {
    $language = $::lx_office_conf{system}->{language};
  } else {
    $language = $main::myconfig{"countrycode"};
  }
  $language = "de" unless ($language);

  my $webpages_path     = $::request->layout->webpages_path;
  my $webpages_fallback = $::request->layout->webpages_fallback_path;

  my @templates = first { -f } map { "${_}/${file}.html" } grep { defined } $webpages_path, $webpages_fallback;

  if (@templates) {
    $file = $templates[0];
  } elsif (ref $file eq 'SCALAR') {
    # file is a scalarref, use inline mode
  } else {
    my $info = "Web page template '${file}' not found.\n";
    $::form->header;
    print qq|<pre>$info</pre>|;
    $::dispatcher->end_request;
  }

  $additional_params->{AUTH}          = $::auth;
  $additional_params->{INSTANCE_CONF} = $::instance_conf;
  $additional_params->{LOCALE}        = $::locale;
  $additional_params->{LXCONFIG}      = \%::lx_office_conf;
  $additional_params->{LXDEBUG}       = $::lxdebug;
  $additional_params->{MYCONFIG}      = \%::myconfig;

  $main::lxdebug->leave_sub();

  return $file;
}

sub parse_html_template {
  $main::lxdebug->enter_sub();

  my ($self, $file, $additional_params) = @_;

  $additional_params ||= { };

  my $real_file = $self->_prepare_html_template($file, $additional_params);
  my $template  = $self->template;

  map { $additional_params->{$_} ||= $self->{$_} } keys %{ $self };

  my $output;
  $template->process($real_file, $additional_params, \$output) || die $template->error;

  $main::lxdebug->leave_sub();

  return $output;
}

sub template { $::request->presenter->get_template }

sub show_generic_error {
  $main::lxdebug->enter_sub();

  my ($self, $error, %params) = @_;

  if ($self->{__ERROR_HANDLER}) {
    $self->{__ERROR_HANDLER}->($error);
    $main::lxdebug->leave_sub();
    return;
  }

  if ($::request->is_ajax) {
    SL::ClientJS->new
      ->error($error)
      ->render(SL::Controller::Base->new);
    $::dispatcher->end_request;
  }

  my $add_params = {
    'title_error' => $params{title},
    'label_error' => $error,
  };

  $self->{title} = $params{title} if $params{title};

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Back'),
        call      => [ 'kivi.history_back' ],
        accesskey => 'enter',
      ],
    );
  }

  $self->header();
  print $self->parse_html_template("generic/error", $add_params);

  print STDERR "Error: $error\n";

  $main::lxdebug->leave_sub();

  $::dispatcher->end_request;
}

sub show_generic_information {
  $main::lxdebug->enter_sub();

  my ($self, $text, $title) = @_;

  my $add_params = {
    'title_information' => $title,
    'label_information' => $text,
  };

  $self->{title} = $title if ($title);

  $self->header();
  print $self->parse_html_template("generic/information", $add_params);

  $main::lxdebug->leave_sub();

  $::dispatcher->end_request;
}

sub _store_redirect_info_in_session {
  my ($self) = @_;

  return unless $self->{callback} =~ m:^ ( [^\?/]+ \.pl ) \? (.+) :x;

  my ($controller, $params) = ($1, $2);
  my $form                  = { map { map { $self->unescape($_) } split /=/, $_, 2 } split m/\&/, $params };
  $self->{callback}         = "${controller}?RESTORE_FORM_FROM_SESSION_ID=" . $::auth->save_form_in_session(form => $form);
}

sub redirect {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if (!$self->{callback}) {
    $self->info($msg);

  } else {
    SL::Helper::Flash::flash_later('info', $msg) if $msg;
    $self->_store_redirect_info_in_session;
    print $::form->redirect_header($self->{callback});
  }

  $::dispatcher->end_request;

  $main::lxdebug->leave_sub();
}

# sort of columns removed - empty sub
sub sort_columns {
  $main::lxdebug->enter_sub();

  my ($self, @columns) = @_;

  $main::lxdebug->leave_sub();

  return @columns;
}
#

sub format_amount {
  my ($self, $myconfig, $amount, $places, $dash) = @_;
  SL::Helper::Number::_format_number($amount, $places, %$myconfig, dash => $dash);
}

sub format_string {
  $main::lxdebug->enter_sub(2);

  my $self  = shift;
  my $input = shift;

  $input =~ s/(^|[^\#]) \#  (\d+)  /$1$_[$2 - 1]/gx;
  $input =~ s/(^|[^\#]) \#\{(\d+)\}/$1$_[$2 - 1]/gx;
  $input =~ s/\#\#/\#/g;

  $main::lxdebug->leave_sub(2);

  return $input;
}

#

sub parse_amount {
  my ($self, $myconfig, $amount) = @_;
  SL::Helper::Number::_parse_number($amount, %$myconfig);
}

sub round_amount { shift; goto &SL::Helper::Number::_round_number; }

sub parse_template {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;
  my ($out, $out_mode);

  local (*IN, *OUT);

  my $defaults        = SL::DB::Default->get;

  my $keep_temp_files = $::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files};
  $self->{cwd}        = getcwd();
  my $temp_dir        = File::Temp->newdir(
    "kivitendo-print-XXXXXX",
    DIR     => $self->{cwd} . "/" . $::lx_office_conf{paths}->{userspath},
    CLEANUP => !$keep_temp_files,
  );

  my $userspath   = File::Spec->abs2rel($temp_dir->dirname);
  $self->{tmpdir} = $temp_dir->dirname;

  my $ext_for_format;

  my $template_type;
  if ($self->{"format"} =~ /(opendocument|oasis)/i) {
    $template_type  = 'OpenDocument';
    $ext_for_format = $self->{"format"} =~ m/pdf/ ? 'pdf' : 'odt';

  } elsif ($self->{"format"} =~ /(postscript|pdf)/i) {
    $template_type    = 'LaTeX';
    $ext_for_format   = 'pdf';

  } elsif (($self->{"format"} =~ /html/i) || (!$self->{"format"} && ($self->{"IN"} =~ /html$/i))) {
    $template_type  = 'HTML';
    $ext_for_format = 'html';

  } elsif ( $self->{"format"} =~ /excel/i ) {
    $template_type  = 'Excel';
    $ext_for_format = 'xls';

  } elsif ( defined $self->{'format'}) {
    $self->error("Outputformat not defined. This may be a future feature: $self->{'format'}");

  } elsif ( $self->{'format'} eq '' ) {
    $self->error("No Outputformat given: $self->{'format'}");

  } else { #Catch the rest
    $self->error("Outputformat not defined: $self->{'format'}");
  }

  my $template = SL::Template::create(type      => $template_type,
                                      file_name => $self->{IN},
                                      form      => $self,
                                      myconfig  => $myconfig,
                                      userspath => $userspath,
                                      %{ $self->{TEMPLATE_DRIVER_OPTIONS} || {} });

  # Copy the notes from the invoice/sales order etc. back to the variable "notes" because that is where most templates expect it to be.
  $self->{"notes"} = $self->{ $self->{"formname"} . "notes" } if exists $self->{ $self->{"formname"} . "notes" };

  if (!$self->{employee_id}) {
    $self->{"employee_${_}"} = $myconfig->{$_} for qw(email tel fax name signature);
    $self->{"employee_${_}"} = $defaults->$_   for qw(address businessnumber co_ustid company duns sepa_creditor_id taxnumber);
  }

  $self->{"myconfig_${_}"} = $myconfig->{$_} for grep { $_ ne 'dbpasswd' } keys %{ $myconfig };
  $self->{$_}              = $defaults->$_   for qw(co_ustid);
  $self->{"myconfig_${_}"} = $defaults->$_   for qw(address businessnumber co_ustid company duns sepa_creditor_id taxnumber);
  $self->{AUTH}            = $::auth;
  $self->{INSTANCE_CONF}   = $::instance_conf;
  $self->{LOCALE}          = $::locale;
  $self->{LXCONFIG}        = $::lx_office_conf;
  $self->{LXDEBUG}         = $::lxdebug;
  $self->{MYCONFIG}        = \%::myconfig;

  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);

  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file

  my ($temp_fh, $suffix);
  $suffix =  $self->{IN};
  $suffix =~ s/.*\.//;
  ($temp_fh, $self->{tmpfile}) = File::Temp::tempfile(
    strftime('kivitendo-print-%Y%m%d%H%M%S-XXXXXX', localtime()),
    SUFFIX => '.' . ($suffix || 'tex'),
    DIR    => $userspath,
    UNLINK => $keep_temp_files ? 0 : 1,
  );
  close $temp_fh;
  chmod 0644, $self->{tmpfile} if $keep_temp_files;
  (undef, undef, $self->{template_meta}{tmpfile}) = File::Spec->splitpath( $self->{tmpfile} );

  $out              = $self->{OUT};
  $out_mode         = $self->{OUT_MODE} || '>';
  $self->{OUT}      = "$self->{tmpfile}";
  $self->{OUT_MODE} = '>';

  my $result;
  my $command_formatter = sub {
    my ($out_mode, $out) = @_;
    return $out_mode eq '|-' ? SL::Template::create(type => 'ShellCommand', form => $self)->parse($out) : $out;
  };

  if ($self->{OUT}) {
    $self->{OUT} = $command_formatter->($self->{OUT_MODE}, $self->{OUT});
    open(OUT, $self->{OUT_MODE}, $self->{OUT}) or $self->error("error on opening $self->{OUT} with mode $self->{OUT_MODE} : $!");
  } else {
    *OUT = ($::dispatcher->get_standard_filehandles)[1];
    $self->header;
  }

  if (!$template->parse(*OUT)) {
    $self->cleanup();
    $self->error("$self->{IN} : " . $template->get_error());
  }

  close OUT if $self->{OUT};
  # check only one flag (webdav_documents)
  # therefore copy to webdav, even if we do not have the webdav feature enabled (just archive)
  my $copy_to_webdav =  $::instance_conf->get_webdav_documents && !$self->{preview} && $self->{tmpdir} && $self->{tmpfile} && $self->{type}
                        && $self->{type} ne 'statement';

  $self->{attachment_filename} ||= $self->generate_attachment_filename;

  if ( $ext_for_format eq 'pdf' && $self->doc_storage_enabled ) {
    $self->append_general_pdf_attachments(filepath =>  $self->{tmpdir}."/".$self->{tmpfile},
                                          type     =>  $self->{type});
  }
  if ($self->{media} eq 'file') {
    copy(join('/', $self->{cwd}, $userspath, $self->{tmpfile}), $out =~ m|^/| ? $out : join('/', $self->{cwd}, $out)) if $template->uses_temp_file;

    if ($copy_to_webdav) {
      if (my $error = Common::copy_file_to_webdav_folder($self)) {
        chdir("$self->{cwd}");
        $self->error($error);
      }
    }

    if (!$self->{preview} && $self->{attachment_type} !~ m{^dunning} && $self->doc_storage_enabled)
    {
      $self->store_pdf($self);
    }
    $self->cleanup;
    chdir("$self->{cwd}");

    $::lxdebug->leave_sub();

    return;
  }

  if ($copy_to_webdav) {
    if (my $error = Common::copy_file_to_webdav_folder($self)) {
      chdir("$self->{cwd}");
      $self->error($error);
    }
  }

  if ( !$self->{preview} && $ext_for_format eq 'pdf' && $self->{attachment_type} !~ m{^dunning} && $self->doc_storage_enabled) {
    my $file_obj = $self->store_pdf($self);
    $self->{print_file_id} = $file_obj->id if $file_obj;
  }
  # dn has its own send email method, but sets media for print templates
  if ($self->{media} eq 'email' && !$self->{dunning_id}) {
    if ( getcwd() eq $self->{"tmpdir"} ) {
      # in the case of generating pdf we are in the tmpdir, but WHY ???
      $self->{tmpfile} = $userspath."/".$self->{tmpfile};
      chdir("$self->{cwd}");
    }
    $self->send_email(\%::myconfig,$ext_for_format);
  }
  else {
    $self->{OUT}      = $out;
    $self->{OUT_MODE} = $out_mode;
    $self->output_file($template->get_mime_type,$command_formatter);
  }
  delete $self->{print_file_id};

  $self->cleanup;

  chdir("$self->{cwd}");
  $main::lxdebug->leave_sub();
}

sub get_bcc_defaults {
  my ($self, $myconfig, $mybcc) = @_;
  if (SL::DB::Default->get->bcc_to_login) {
    $mybcc .= ", " if $mybcc;
    $mybcc .= $myconfig->{email};
  }
  my $otherbcc = SL::DB::Default->get->global_bcc;
  if ($otherbcc) {
    $mybcc .= ", " if $mybcc;
    $mybcc .= $otherbcc;
  }
  return $mybcc;
}

sub send_email {
  $main::lxdebug->enter_sub();
  my ($self, $myconfig, $ext_for_format) = @_;
  my $mail = Mailer->new;

  map { $mail->{$_} = $self->{$_} }
    qw(cc subject message format);

  if ($self->{cc_employee}) {
    my ($user, $my_emp_cc);
    $user        = SL::DB::Manager::AuthUser->find_by(login => $self->{cc_employee});
    $my_emp_cc   = $user->get_config_value('email') if ref $user eq 'SL::DB::AuthUser';
    $mail->{cc} .= ", "       if $mail->{cc};
    $mail->{cc} .= $my_emp_cc if $my_emp_cc;
  }

  $mail->{bcc}    = $self->get_bcc_defaults($myconfig, $self->{bcc});
  $mail->{to}     = $self->{EMAIL_RECIPIENT} ? $self->{EMAIL_RECIPIENT} : $self->{email};
  $mail->{from}   = qq|"$myconfig->{name}" <$myconfig->{email}>|;
  $mail->{fileid} = time() . '.' . $$ . '.';
  $mail->{content_type}  =  "text/html";
  my $full_signature     =  $self->create_email_signature();

  $mail->{attachments} =  [];
  my @attfiles;
  # if we send html or plain text inline
  if (($self->{format} eq 'html') && ($self->{sendmode} eq 'inline')) {
    $mail->{message}        =~ s/\r//g;
    $mail->{message}        =~ s{\n}{<br>\n}g;
    $mail->{message}       .=  $full_signature;

    open(IN, "<", $self->{tmpfile})
      or $self->error($self->cleanup . "$self->{tmpfile} : $!");
    $mail->{message} .= $_ while <IN>;
    close(IN);

  } elsif (($self->{attachment_policy} // '') ne 'no_file') {
    my $attachment_name  =  $self->{attachment_filename}  || $self->{tmpfile};
    $attachment_name     =~ s{\.(.+?)$}{.${ext_for_format}} if ($ext_for_format);

    if (($self->{attachment_policy} // '') eq 'old_file') {
      my ( $attfile ) = SL::File->get_all(object_id     => $self->{id},
                                          object_type   => $self->{type},
                                          file_type     => 'document',
                                          print_variant => $self->{formname},);

      if ($attfile) {
        $attfile->{override_file_name} = $attachment_name if $attachment_name;
        push @attfiles, $attfile;
        $self->{file_id} = $attfile->id;
      }

    } else {
      if ($self->{attachment_policy} eq 'merge_file') {
        my $id = $::form->{id} ? $::form->{id} : undef;
        my $latest_documents  = SL::DB::Manager::File->get_all(query =>
                                [
                                  object_id   => $id,
                                  file_type   => 'document',
                                  mime_type   => 'application/pdf',
                                  source      => 'uploaded',
                                  or          => [
                                                   object_type => 'gl_transaction',
                                                   object_type => 'purchase_invoice',
                                                   object_type => 'invoice',
                                                   object_type => 'credit_note',
                                                 ],
                                ],
                                  sort_by   => 'itime DESC');
        # if uploaded documents exists, add ALL pdf files for later merging
        if (scalar @{ $latest_documents }) {
          my $files;
          push @{ $files }, $self->{tmpfile};
          foreach my $latest_document (@{ $latest_documents }) {
            die "No file datatype:" . ref $latest_document unless (ref $latest_document eq 'SL::DB::File');
            push @{ $files }, $latest_document->file_versions_sorted->[-1]->get_system_location;
          }
          SL::Helper::CreatePDF->merge_pdfs(file_names => $files, out_path => $self->{tmpfile});
        }
      }
      push @{ $mail->{attachments} }, { path => $self->{tmpfile},
                                        id   => $self->{print_file_id},
                                        type => "application/pdf",
                                        name => $attachment_name };
    }
  }

  push @attfiles,
    grep { $_ }
    map  { SL::File->get(id => $_) }
    @{ $self->{attach_file_ids} // [] };

  foreach my $attfile ( @attfiles ) {
    push @{ $mail->{attachments} }, {
      path    => $attfile->get_file,
      id      => $attfile->id,
      type    => $attfile->mime_type,
      name    => $attfile->{override_file_name} // $attfile->file_name,
      content => $attfile->get_content ? ${ $attfile->get_content } : undef,
    };
  }

  $mail->{message}  =~ s/\r//g;
  $mail->{message} .= $full_signature;
  $self->{emailerr} = $mail->send();

  $self->{email_journal_id} = $mail->{journalentry};
  $self->{snumbers}  = "emailjournal" . "_" . $self->{email_journal_id};
  $self->{what_done} = $::form->{type};
  $self->{addition}  = "MAILED";
  $self->save_history;

  if ($self->{emailerr}) {
    $self->cleanup;
    $self->error($::locale->text('The email was not sent due to the following error: #1.', $self->{emailerr}));
  }

  #write back for message info and mail journal
  $self->{cc}  = $mail->{cc};
  $self->{bcc} = $mail->{bcc};
  $self->{email} = $mail->{to};

  $main::lxdebug->leave_sub();
}

sub output_file {
  $main::lxdebug->enter_sub();

  my ($self,$mimeType,$command_formatter) = @_;
  my $numbytes = (-s $self->{tmpfile});
  open(IN, "<", $self->{tmpfile})
    or $self->error($self->cleanup . "$self->{tmpfile} : $!");
  binmode IN;

  $self->{copies} = 1 unless $self->{media} eq 'printer';

  chdir("$self->{cwd}");
  for my $i (1 .. $self->{copies}) {
    if ($self->{OUT}) {
      $self->{OUT} = $command_formatter->($self->{OUT_MODE}, $self->{OUT});

      open  OUT, $self->{OUT_MODE}, $self->{OUT} or $self->error($self->cleanup . "$self->{OUT} : $!");
      print OUT $_ while <IN>;
      close OUT;
      seek  IN, 0, 0;

    } else {
      my %headers = ('-type'       => $mimeType,
                     '-connection' => 'close',
                     '-charset'    => 'UTF-8');

      $self->{attachment_filename} ||= $self->generate_attachment_filename;

      if ($self->{attachment_filename}) {
        %headers = (
          %headers,
          '-attachment'     => $self->{attachment_filename},
          '-content-length' => $numbytes,
          '-charset'        => '',
        );
      }

      print $::request->cgi->header(%headers);

      $::locale->with_raw_io(\*STDOUT, sub { print while <IN> });
    }
  }
  close(IN);
  $main::lxdebug->leave_sub();
}

sub get_formname_translation {
  $main::lxdebug->enter_sub();
  my ($self, $formname) = @_;

  $formname ||= $self->{formname};

  $self->{recipient_locale} ||=  Locale->lang_to_locale($self->{language});
  local $::locale = Locale->new($self->{recipient_locale});

  my %formname_translations = (
    bin_list                    => $main::locale->text('Bin List'),
    credit_note                 => $main::locale->text('Credit Note'),
    invoice                     => $main::locale->text('Invoice'),
    invoice_copy                => $main::locale->text('Invoice Copy'),
    invoice_for_advance_payment => $main::locale->text('Invoice for Advance Payment'),
    final_invoice               => $main::locale->text('Final Invoice'),
    pick_list                   => $main::locale->text('Pick List'),
    proforma                    => $main::locale->text('Proforma Invoice'),
    purchase_order              => $main::locale->text('Purchase Order'),
    purchase_order_confirmation => $main::locale->text('Purchase Order Confirmation'),
    request_quotation           => $main::locale->text('RFQ'),
    purchase_quotation_intake   => $main::locale->text('Purchase Quotation Intake'),
    sales_order_intake          => $main::locale->text('Sales Order Intake'),
    sales_order                 => $main::locale->text('Confirmation'),
    sales_quotation             => $main::locale->text('Quotation'),
    storno_invoice              => $main::locale->text('Storno Invoice'),
    sales_delivery_order        => $main::locale->text('Delivery Order'),
    purchase_delivery_order     => $main::locale->text('Delivery Order'),
    supplier_delivery_order     => $main::locale->text('Supplier Delivery Order'),
    rma_delivery_order          => $main::locale->text('RMA Delivery Order'),
    sales_reclamation           => $main::locale->text('Sales Reclamation'),
    purchase_reclamation        => $main::locale->text('Purchase Reclamation'),
    dunning                     => $main::locale->text('Dunning'),
    dunning1                    => $main::locale->text('Payment Reminder'),
    dunning2                    => $main::locale->text('Dunning'),
    dunning3                    => $main::locale->text('Last Dunning'),
    dunning_invoice             => $main::locale->text('Dunning Invoice'),
    letter                      => $main::locale->text('Letter'),
    ic_supply                   => $main::locale->text('Intra-Community supply'),
    statement                   => $main::locale->text('Statement'),
  );

  $main::lxdebug->leave_sub();
  return $formname_translations{$formname};
}

sub get_cusordnumber_translation {
  $main::lxdebug->enter_sub();
  my ($self, $formname) = @_;

  $formname ||= $self->{formname};

  $self->{recipient_locale} ||=  Locale->lang_to_locale($self->{language});
  local $::locale = Locale->new($self->{recipient_locale});


  $main::lxdebug->leave_sub();
  return $main::locale->text('Your Order');
}

sub get_number_prefix_for_type {
  $main::lxdebug->enter_sub();
  my ($self) = @_;

  my $prefix =
      (first { $self->{type} eq $_ } qw(invoice invoice_for_advance_payment final_invoice credit_note)) ? 'inv'
    : ($self->{type} =~ /_quotation/)                                                                   ? 'quo'
    : ($self->{type} =~ /_delivery_order$/)                                                             ? 'do'
    : ($self->{type} =~ /letter/)                                                                       ? 'letter'
    :                                                                                                     'ord';

  # better default like this?
  # : ($self->{type} =~ /(sales|purchase)_order/           :  'ord';
  # :                                                           'prefix_undefined';

  $main::lxdebug->leave_sub();
  return $prefix;
}

sub get_extension_for_format {
  $main::lxdebug->enter_sub();
  my ($self)    = @_;

  my $extension = $self->{format} =~ /pdf/i          ? ".pdf"
                : $self->{format} =~ /postscript/i   ? ".ps"
                : $self->{format} =~ /opendocument/i ? ".odt"
                : $self->{format} =~ /excel/i        ? ".xls"
                : $self->{format} =~ /html/i         ? ".html"
                :                                      "";

  $main::lxdebug->leave_sub();
  return $extension;
}

sub generate_attachment_filename {
  $main::lxdebug->enter_sub();
  my ($self) = @_;

  $self->{recipient_locale} ||=  Locale->lang_to_locale($self->{language});
  my $recipient_locale = Locale->new($self->{recipient_locale});

  my $attachment_filename = $main::locale->unquote_special_chars('HTML', $self->get_formname_translation());
  my $prefix              = $self->get_number_prefix_for_type();

  if ($self->{preview} && (first { $self->{type} eq $_ } qw(invoice invoice_for_advance_payment final_invoice credit_note))) {
    $attachment_filename .= ' (' . $recipient_locale->text('Preview') . ')' . $self->get_extension_for_format();

  } elsif ($attachment_filename && $self->{"${prefix}number"}) {
    $attachment_filename .=  "_" . $self->{"${prefix}number"} . $self->get_extension_for_format();

  } elsif ($attachment_filename) {
    $attachment_filename .=  $self->get_extension_for_format();

  } else {
    $attachment_filename = "";
  }

  $attachment_filename =  $main::locale->quote_special_chars('filenames', $attachment_filename);
  $attachment_filename =~ s|[\s/\\]+|_|g;

  $main::lxdebug->leave_sub();
  return $attachment_filename;
}

sub generate_email_subject {
  $main::lxdebug->enter_sub();
  my ($self) = @_;

  my $defaults = SL::DB::Default->get;

  my $sep = ' / ';
  my $subject = $main::locale->unquote_special_chars('HTML', $self->get_formname_translation());
  my $prefix  = $self->get_number_prefix_for_type();

  if ($subject && $self->{"${prefix}number"}) {
    $subject .= " " . $self->{"${prefix}number"}
  }

  if ($self->{cusordnumber}) {
    $subject = $self->get_cusordnumber_translation() . ' ' . $self->{cusordnumber} . $sep . $subject;
  }

  if ($defaults->email_subject_transaction_description) {
    $subject .=  $sep . $self->{transaction_description} if $self->{transaction_description};
  }

  $main::lxdebug->leave_sub();
  return $subject;
}

sub generate_email_body {
  $main::lxdebug->enter_sub();
  my ($self, %params) = @_;
  # simple german and english will work grammatically (most european languages as well)
  # Dear Mr Alan Greenspan:
  # Sehr geehrte Frau Meyer,
  # A l’attention de Mme Villeroy,
  # Gentile Signora Ferrari,
  my $body = '';

  if ($self->{cp_id} && !$params{record_email}) {
    my $givenname = SL::DB::Contact->load_cached($self->{cp_id})->cp_givenname; # for qw(gender givename name);
    my $name      = SL::DB::Contact->load_cached($self->{cp_id})->cp_name; # for qw(gender givename name);
    my $gender    = SL::DB::Contact->load_cached($self->{cp_id})->cp_gender; # for qw(gender givename name);
    my $mf = $gender eq 'f' ? 'female' : 'male';
    $body  = GenericTranslations->get(translation_type => "salutation_$mf", language_id => $self->{language_id});
    $body .= ' ' . $givenname . ' ' . $name if $body;
  } else {
    $body  = GenericTranslations->get(translation_type => "salutation_general", language_id => $self->{language_id});
  }

  $body .= GenericTranslations->get(translation_type => "salutation_punctuation_mark", language_id => $self->{language_id});
  $body  = '<p>' . $::locale->quote_special_chars('HTML', $body) . '</p>';

  my $translation_type = $params{translation_type} // "preset_text_$self->{formname}";
  my $main_body        = GenericTranslations->get(translation_type => $translation_type,                  language_id => $self->{language_id});
  $main_body           = GenericTranslations->get(translation_type => $params{fallback_translation_type}, language_id => $self->{language_id}) if !$main_body && $params{fallback_translation_type};
  $body               .= $main_body;

  $body = $main::locale->unquote_special_chars('HTML', $body);

  $main::lxdebug->leave_sub();
  return $body;
}

sub cleanup {
  $main::lxdebug->enter_sub();

  my ($self, $application) = @_;

  my $error_code = $?;

  chdir("$self->{tmpdir}");

  my @err = ();
  if ((-1 == $error_code) || (127 == (($error_code) >> 8))) {
    push @err, $::locale->text('The application "#1" was not found on the system.', $application || 'pdflatex') . ' ' . $::locale->text('Please contact your administrator.');

  } elsif (-f "$self->{tmpfile}.err") {
    open(FH, "<:encoding(UTF-8)", "$self->{tmpfile}.err");
    @err = <FH>;
    close(FH);
  }

  if ($self->{tmpfile} && !($::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files})) {
    $self->{tmpfile} =~ s|.*/||g;
    # strip extension
    $self->{tmpfile} =~ s/\.\w+$//g;
    my $tmpfile = $self->{tmpfile};
    unlink(<$tmpfile.*>);
  }

  chdir("$self->{cwd}");

  $main::lxdebug->leave_sub();

  return "@err";
}

sub datetonum {
  $main::lxdebug->enter_sub();

  my ($self, $date, $myconfig) = @_;
  my ($yy, $mm, $dd);

  if ($date && $date =~ /\D/) {

    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /\D/, $date;
    }

    $dd *= 1;
    $mm *= 1;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    $dd = "0$dd" if ($dd < 10);
    $mm = "0$mm" if ($mm < 10);

    $date = "$yy$mm$dd";
  }

  $main::lxdebug->leave_sub();

  return $date;
}

# Database routines used throughout
# DB Handling got moved to SL::DB, these are only shims for compatibility

sub dbconnect {
  SL::DB->client->dbh;
}

sub get_standard_dbh {
  my $dbh = SL::DB->client->dbh;

  if ($dbh && !$dbh->{Active}) {
    $main::lxdebug->message(LXDebug->INFO(), "get_standard_dbh: \$dbh is defined but not Active anymore");
    SL::DB->client->dbh(undef);
  }

  SL::DB->client->dbh;
}

sub disconnect_standard_dbh {
  SL::DB->client->dbh->rollback;
}

# /database

sub date_closed {
  $main::lxdebug->enter_sub();

  my ($self, $date, $myconfig) = @_;
  my $dbh = $self->get_standard_dbh;

  my $query = "SELECT 1 FROM defaults WHERE ? < closedto";
  my $sth = prepare_execute_query($self, $dbh, $query, conv_date($date));

  # Falls $date = '' - Fehlermeldung aus der Datenbank. Ich denke,
  # es ist sicher ein conv_date vorher IMMER auszuführen.
  # Testfälle ohne definiertes closedto:
  #   Leere Datumseingabe i.O.
  #     SELECT 1 FROM defaults WHERE '' < closedto
  #   normale Zahlungsbuchung über Rechnungsmaske i.O.
  #     SELECT 1 FROM defaults WHERE '10.05.2011' < closedto
  # Testfälle mit definiertem closedto (30.04.2011):
  #  Leere Datumseingabe i.O.
  #   SELECT 1 FROM defaults WHERE '' < closedto
  # normale Buchung im geschloßenem Zeitraum i.O.
  #   SELECT 1 FROM defaults WHERE '21.04.2011' < closedto
  #     Fehlermeldung: Es können keine Zahlungen für abgeschlossene Bücher gebucht werden!
  # normale Buchung in aktiver Buchungsperiode i.O.
  #   SELECT 1 FROM defaults WHERE '01.05.2011' < closedto

  my ($closed) = $sth->fetchrow_array;

  $main::lxdebug->leave_sub();

  return $closed;
}

# prevents bookings to the to far away future
sub date_max_future {
  $main::lxdebug->enter_sub();

  my ($self, $date, $myconfig) = @_;
  my $dbh = $self->get_standard_dbh;

  my $query = "SELECT 1 FROM defaults WHERE ? - current_date > max_future_booking_interval";
  my $sth = prepare_execute_query($self, $dbh, $query, conv_date($date));

  my ($max_future_booking_interval) = $sth->fetchrow_array;

  $main::lxdebug->leave_sub();

  return $max_future_booking_interval;
}


sub update_balance {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $table, $field, $where, $value, @values) = @_;

  # if we have a value, go do it
  if ($value != 0) {

    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where FOR UPDATE";
    my $sth = prepare_execute_query($self, $dbh, $query, @values);
    my ($balance) = $sth->fetchrow_array;
    $sth->finish;

    $balance += $value;

    # update balance
    $query = "UPDATE $table SET $field = $balance WHERE $where";
    do_query($self, $dbh, $query, @values);
  }
  $main::lxdebug->leave_sub();
}

sub update_exchangerate {
  $main::lxdebug->enter_sub();

  validate_pos(@_,
                 { isa  => 'Form'},
                 { isa  => 'DBI::db'},
                 { type => SCALAR, callbacks  => { is_fx_currency     => sub { shift ne $_[1]->[0]->{defaultcurrency} } } }, # should be ISO three letter codes for currency identification (ISO 4217)
                 { type => SCALAR, callbacks  => { is_valid_kivi_date => sub { shift =~ m/\d+\d+\d+/ } } }, # we have three numers
                 { type => SCALAR, callbacks  => { is_null_or_ar_int  => sub {    $_[0] == 0
                                                                               || $_[0] >  0
                                                                               && $_[1]->[0]->{script} =~ m/cp\.pl|ar\.pl|is\.pl/ } } }, # value buy fxrate
                 { type => SCALAR, callbacks  => { is_null_or_ap_int  => sub {    $_[0] == 0
                                                                               || $_[0] >  0
                                                                               && $_[1]->[0]->{script} =~ m/cp\.pl|ap\.pl|ir\.pl/  } } }, # value sell fxrate
                 { type => SCALAR, callbacks  => { is_current_form_id => sub { $_[0] == $_[1]->[0]->{id} } },              optional => 1 },
                 { type => SCALAR, callbacks  => { is_valid_fx_table  => sub { shift =~ m/(ar|ap|bank_transactions)/  } }, optional => 1 }
              );

  my ($self, $dbh, $curr, $transdate, $buy, $sell, $id, $record_table) = @_;

  # record has a exchange rate and should be updated
  if ($record_table && $id) {
    do_query($self, $dbh, qq|UPDATE $record_table SET exchangerate = ? WHERE id = ?|, $buy || $sell, $id);
    $main::lxdebug->leave_sub();
    return;
  }

  my ($query);
  $query = qq|SELECT e.currency_id FROM exchangerate e
                 WHERE e.currency_id = (SELECT cu.id FROM currencies cu WHERE cu.name=?) AND e.transdate = ?
                 FOR UPDATE|;
  my $sth = prepare_execute_query($self, $dbh, $query, $curr, $transdate);

  if ($buy == 0) {
    $buy = "";
  }
  if ($sell == 0) {
    $sell = "";
  }

  $buy = conv_i($buy, "NULL");
  $sell = conv_i($sell, "NULL");

  my $set;
  if ($buy != 0 && $sell != 0) {
    $set = "buy = $buy, sell = $sell";
  } elsif ($buy != 0) {
    $set = "buy = $buy";
  } elsif ($sell != 0) {
    $set = "sell = $sell";
  }

  if ($sth->fetchrow_array) {
    # die "this never happens never"; # except for credit or debit bookings
    $query = qq|UPDATE exchangerate
                SET $set
                WHERE currency_id = (SELECT id FROM currencies WHERE name = ?)
                AND transdate = ?|;

  } else {
    $query = qq|INSERT INTO exchangerate (currency_id, buy, sell, transdate)
                VALUES ((SELECT id FROM currencies WHERE name = ?), $buy, $sell, ?)|;
  }
  $sth->finish;
  do_query($self, $dbh, $query, $curr, $transdate);

  $main::lxdebug->leave_sub();
}

sub check_exchangerate {
  $main::lxdebug->enter_sub();

  validate_pos(@_,
                 { isa  => 'Form'},
                 { type => HASHREF, callbacks => { has_yy_in_dateformat => sub { $_[0]->{dateformat} =~ m/yy/ } } },
                 { type => SCALAR, callbacks  => { is_fx_currency       => sub { shift ne $_[1]->[0]->{defaultcurrency} } } }, # should be ISO three letter codes for currency identification (ISO 4217)
                 { type => SCALAR | HASHREF, callbacks  => { is_valid_kivi_date   => sub { shift =~ m/\d+.\d+.\d+/ } } }, # we have three numbers. Either DateTime or form scalar
                 { type => SCALAR, callbacks  => { is_buy_or_sell_rate  => sub { shift =~ m/^(buy|sell)$/ } } },
                 { type => SCALAR | UNDEF,   callbacks  => { is_current_form_id   => sub { $_[0] == $_[1]->[0]->{id} } },              optional => 1 },
                 { type => SCALAR, callbacks  => { is_valid_fx_table    => sub { shift =~ m/^(ar|ap)$/  } }, optional => 1 }
              );
  my ($self, $myconfig, $currency, $transdate, $fld, $id, $record_table) = @_;

  my $dbh   = $self->get_standard_dbh($myconfig);

  # callers wants a check if record has a exchange rate and should be fetched instead
  if ($record_table && $id) {
    my ($record_exchange_rate) = selectrow_query($self, $dbh, qq|SELECT exchangerate FROM $record_table WHERE id = ?|, $id);
    if ($record_exchange_rate && $record_exchange_rate > 0) {

      $main::lxdebug->leave_sub();
      # second param indicates record exchange rate
      return ($record_exchange_rate, 1);
    }
  }

  # fetch default from exchangerate table
  my $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.currency_id = (SELECT id FROM currencies WHERE name = ?) AND e.transdate = ?|;

  my ($exchangerate) = selectrow_query($self, $dbh, $query, $currency, $transdate);

  $main::lxdebug->leave_sub();

  return $exchangerate;
}

sub get_all_currencies {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my $myconfig = shift || \%::myconfig;
  my $dbh      = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT name FROM currencies|;
  my @currencies = map { $_->{name} } selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();

  return @currencies;
}

sub get_default_currency {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;
  my $dbh      = $self->get_standard_dbh($myconfig);
  my $query = qq|SELECT name AS curr FROM currencies WHERE id = (SELECT currency_id FROM defaults)|;

  my ($defaultcurrency) = selectrow_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $defaultcurrency;
}

sub set_payment_options {
  my ($self, $myconfig, $transdate, $type) = @_;

  my $terms = $self->{payment_id} ? SL::DB::PaymentTerm->new(id => $self->{payment_id})->load : undef;
  return if !$terms;

  my $is_invoice                = $type =~ m{invoice}i;

  $transdate                  ||= $self->{invdate} || $self->{transdate};
  my $due_date                  = $self->{duedate} || $self->{reqdate};

  $self->{$_}                   = $terms->$_ for qw(terms_netto terms_skonto percent_skonto);
  $self->{payment_description}  = $terms->description;
  $self->{netto_date}           = $terms->calc_date(reference_date => $transdate, due_date => $due_date, terms => 'net')->to_kivitendo;
  $self->{skonto_date}          = $terms->calc_date(reference_date => $transdate, due_date => $due_date, terms => 'discount')->to_kivitendo;

  my ($invtotal, $total);
  my (%amounts, %formatted_amounts);

  if ($self->{type} =~ /_order$/) {
    $amounts{invtotal} = $self->{ordtotal};
    $amounts{total}    = $self->{ordtotal};

  } elsif ($self->{type} =~ /_quotation$/) {
    $amounts{invtotal} = $self->{quototal};
    $amounts{total}    = $self->{quototal};

  } else {
    $amounts{invtotal} = $self->{invtotal};
    $amounts{total}    = $self->{total};
  }
  map { $amounts{$_} = $self->parse_amount($myconfig, $amounts{$_}) } keys %amounts;

  $amounts{skonto_in_percent}  = 100.0 * $self->{percent_skonto};
  $amounts{skonto_amount}      = $amounts{invtotal} * $self->{percent_skonto};
  $amounts{invtotal_wo_skonto} = $amounts{invtotal} * (1 - $self->{percent_skonto});
  $amounts{total_wo_skonto}    = $amounts{total}    * (1 - $self->{percent_skonto});

  foreach (keys %amounts) {
    $amounts{$_}           = $self->round_amount($amounts{$_}, 2);
    $formatted_amounts{$_} = $self->format_amount($myconfig, $amounts{$_}, 2);
  }

  if ($self->{"language_id"}) {
    my $language             = SL::DB::Language->new(id => $self->{language_id})->load;

    $self->{payment_terms}   = $type =~ m{invoice}i ? $terms->translated_attribute('description_long_invoice', $language->id) : undef;
    $self->{payment_terms} ||= $terms->translated_attribute('description_long', $language->id);

    if ($language->output_dateformat) {
      foreach my $key (qw(netto_date skonto_date)) {
        $self->{$key} = $::locale->reformat_date($myconfig, $self->{$key}, $language->output_dateformat, $language->output_longdates);
      }
    }

    if ($language->output_numberformat && ($language->output_numberformat ne $myconfig->{numberformat})) {
      local $myconfig->{numberformat};
      $myconfig->{"numberformat"} = $language->output_numberformat;
      $formatted_amounts{$_} = $self->format_amount($myconfig, $amounts{$_}) for keys %amounts;
    }
  }

  $self->{payment_terms} =  $self->{payment_terms} || ($is_invoice ? $terms->description_long_invoice : undef) || $terms->description_long;

  $self->{payment_terms} =~ s/<%netto_date%>/$self->{netto_date}/g;
  $self->{payment_terms} =~ s/<%skonto_date%>/$self->{skonto_date}/g;
  $self->{payment_terms} =~ s/<%currency%>/$self->{currency}/g;
  $self->{payment_terms} =~ s/<%terms_netto%>/$self->{terms_netto}/g;
  $self->{payment_terms} =~ s/<%account_number%>/$self->{account_number}/g;
  $self->{payment_terms} =~ s/<%bank%>/$self->{bank}/g;
  $self->{payment_terms} =~ s/<%bank_code%>/$self->{bank_code}/g;
  $self->{payment_terms} =~ s/<\%bic\%>/$self->{bic}/g;
  $self->{payment_terms} =~ s/<\%iban\%>/$self->{iban}/g;
  $self->{payment_terms} =~ s/<\%mandate_date_of_signature\%>/$self->{mandate_date_of_signature}/g;
  $self->{payment_terms} =~ s/<\%mandator_id\%>/$self->{mandator_id}/g;

  map { $self->{payment_terms} =~ s/<%${_}%>/$formatted_amounts{$_}/g; } keys %formatted_amounts;
  # put amounts in form for print template
  foreach (keys %formatted_amounts) {
    next if $_  =~ m/(^total$|^invtotal$)/;
    $self->{$_} = $formatted_amounts{$_};
  }
}

sub get_template_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{language_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT template_code FROM language WHERE id = ?|;
    ($template_code) = selectrow_query($self, $dbh, $query, $self->{language_id});
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_printer_code {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{printer_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT template_code, printer_command FROM printers WHERE id = ?|;
    ($template_code, $self->{printer_command}) = selectrow_query($self, $dbh, $query, $self->{printer_id});
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{shipto_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT * FROM shipto WHERE shipto_id = ?|;
    my $ref = selectfirst_hashref_query($self, $dbh, $query, $self->{shipto_id});
    map({ $self->{$_} = $ref->{$_} } keys(%$ref));

    my $cvars = CVar->get_custom_variables(
      dbh      => $dbh,
      module   => 'ShipTo',
      trans_id => $self->{shipto_id},
    );
    $self->{"shiptocvar_$_->{name}"} = $_->{value} for @{ $cvars };
  }

  $main::lxdebug->leave_sub();
}

sub add_shipto {
  my ($self, $dbh, $id, $module) = @_;

  my $shipto;
  my @values;

  foreach my $item (qw(name department_1 department_2 street zipcode city country gln
                       contact phone fax email)) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
    push(@values, $self->{"shipto${item}"});
  }

  return if !$shipto;

  # shiptocp_gender only makes sense, if any other shipto attribute is set.
  # Because shiptocp_gender is set to 'm' by default in forms
  # it must not be considered above to decide if shiptos has to be added or
  # updated, but must be inserted or updated as well in case.
  push(@values, $self->{shiptocp_gender});

  my $shipto_id = $self->{shipto_id};

  if ($self->{shipto_id}) {
    my $query = qq|UPDATE shipto set
                     shiptoname = ?,
                     shiptodepartment_1 = ?,
                     shiptodepartment_2 = ?,
                     shiptostreet = ?,
                     shiptozipcode = ?,
                     shiptocity = ?,
                     shiptocountry = ?,
                     shiptogln = ?,
                     shiptocontact = ?,
                     shiptophone = ?,
                     shiptofax = ?,
                     shiptoemail = ?,
                     shiptocp_gender = ?
                   WHERE shipto_id = ?|;
    do_query($self, $dbh, $query, @values, $self->{shipto_id});
  } else {
    my $query = qq|SELECT * FROM shipto
                   WHERE shiptoname = ? AND
                     shiptodepartment_1 = ? AND
                     shiptodepartment_2 = ? AND
                     shiptostreet = ? AND
                     shiptozipcode = ? AND
                     shiptocity = ? AND
                     shiptocountry = ? AND
                     shiptogln = ? AND
                     shiptocontact = ? AND
                     shiptophone = ? AND
                     shiptofax = ? AND
                     shiptoemail = ? AND
                     shiptocp_gender = ? AND
                     module = ? AND
                     trans_id = ?|;
    my $insert_check = selectfirst_hashref_query($self, $dbh, $query, @values, $module, $id);
    if(!$insert_check){
      my $insert_query =
        qq|INSERT INTO shipto (trans_id, shiptoname, shiptodepartment_1, shiptodepartment_2,
                               shiptostreet, shiptozipcode, shiptocity, shiptocountry, shiptogln,
                               shiptocontact, shiptophone, shiptofax, shiptoemail, shiptocp_gender, module)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
      do_query($self, $dbh, $insert_query, $id, @values, $module);

      $insert_check = selectfirst_hashref_query($self, $dbh, $query, @values, $module, $id);
    }

    $shipto_id = $insert_check->{shipto_id};
  }

  return unless $shipto_id;

  CVar->save_custom_variables(
    dbh         => $dbh,
    module      => 'ShipTo',
    trans_id    => $shipto_id,
    variables   => $self,
    name_prefix => 'shipto',
  );
}

sub get_employee {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  $dbh ||= $self->get_standard_dbh(\%main::myconfig);

  my $query = qq|SELECT id, name FROM employee WHERE login = ?|;
  ($self->{"employee_id"}, $self->{"employee"}) = selectrow_query($self, $dbh, $query, $self->{login});
  $self->{"employee_id"} *= 1;

  $main::lxdebug->leave_sub();
}

sub get_employee_data {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;
  my $defaults = SL::DB::Default->get;

  Common::check_params(\%params, qw(prefix));
  Common::check_params_x(\%params, qw(id));

  if (!$params{id}) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $dbh      = $params{dbh} || $self->get_standard_dbh($myconfig);

  my ($login, $deleted)  = selectrow_query($self, $dbh, qq|SELECT login,deleted FROM employee WHERE id = ?|, conv_i($params{id}));

  if ($login) {
    # login already fetched and still the same client (mandant) | same for both cases (delete|!delete)
    $self->{$params{prefix} . '_login'}   = $login;
    $self->{$params{prefix} . "_${_}"}    = $defaults->$_ for qw(address businessnumber co_ustid company duns taxnumber);

    if (!$deleted) {
      # get employee data from auth.user_config
      my $user = User->new(login => $login);
      $self->{$params{prefix} . "_${_}"} = $user->{$_} for qw(email fax name signature tel);
    } else {
      # get saved employee data from employee
      my $employee = SL::DB::Manager::Employee->find_by(id => conv_i($params{id}));
      $self->{$params{prefix} . "_${_}"} = $employee->{"deleted_$_"} for qw(email fax signature tel);
      $self->{$params{prefix} . "_name"} = $employee->name;
    }
 }
  $main::lxdebug->leave_sub();
}

sub _get_contacts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id, $key) = @_;

  $key = "all_contacts" unless ($key);

  if (!$id) {
    $self->{$key} = [];
    $main::lxdebug->leave_sub();
    return;
  }

  my $query =
    qq|SELECT cp_id, cp_cv_id, cp_name, cp_givenname, cp_abteilung | .
    qq|FROM contacts | .
    qq|WHERE cp_cv_id = ? | .
    qq|ORDER BY lower(cp_name)|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query, $id);

  $main::lxdebug->leave_sub();
}

sub _get_projects {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  my ($all, $old_id, $where, @values);

  if (ref($key) eq "HASH") {
    my $params = $key;

    $key = "ALL_PROJECTS";

    foreach my $p (keys(%{$params})) {
      if ($p eq "all") {
        $all = $params->{$p};
      } elsif ($p eq "old_id") {
        $old_id = $params->{$p};
      } elsif ($p eq "key") {
        $key = $params->{$p};
      }
    }
  }

  if (!$all) {
    $where = "WHERE active ";
    if ($old_id) {
      if (ref($old_id) eq "ARRAY") {
        my @ids = grep({ $_ } @{$old_id});
        if (@ids) {
          $where .= " OR id IN (" . join(",", map({ "?" } @ids)) . ") ";
          push(@values, @ids);
        }
      } else {
        $where .= " OR (id = ?) ";
        push(@values, $old_id);
      }
    }
  }

  my $query =
    qq|SELECT id, projectnumber, description, active | .
    qq|FROM project | .
    $where .
    qq|ORDER BY lower(projectnumber)|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub _get_printers {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_printers" unless ($key);

  my $query = qq|SELECT id, printer_description, printer_command, template_code FROM printers|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_charts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $params) = @_;
  my ($key);

  $key = $params->{key};
  $key = "all_charts" unless ($key);

  my $transdate = quote_db_date($params->{transdate});

  my $query =
    qq|SELECT c.id, c.accno, c.description, c.link, c.charttype, tk.taxkey_id, tk.tax_id | .
    qq|FROM chart c | .
    qq|LEFT JOIN taxkeys tk ON | .
    qq|(tk.id = (SELECT id FROM taxkeys | .
    qq|          WHERE taxkeys.chart_id = c.id AND startdate <= $transdate | .
    qq|          ORDER BY startdate DESC LIMIT 1)) | .
    qq|ORDER BY c.accno|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_taxzones {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_taxzones" unless ($key);
  my $tzfilter = "";
  $tzfilter = "WHERE obsolete is FALSE" if $key eq 'ALL_ACTIVE_TAXZONES';

  my $query = qq|SELECT * FROM tax_zones $tzfilter ORDER BY sortkey|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_employees {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $params) = @_;

  my $deleted = 0;

  my $key;
  if (ref $params eq 'HASH') {
    $key     = $params->{key};
    $deleted = $params->{deleted};

  } else {
    $key = $params;
  }

  $key     ||= "all_employees";
  my $filter = $deleted ? '' : 'WHERE NOT COALESCE(deleted, FALSE)';
  $self->{$key} = selectall_hashref_query($self, $dbh, qq|SELECT * FROM employee $filter ORDER BY lower(name)|);

  $main::lxdebug->leave_sub();
}

sub _get_business_types {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  my $options       = ref $key eq 'HASH' ? $key : { key => $key };
  $options->{key} ||= "all_business_types";
  my $where         = '';

  if (exists $options->{salesman}) {
    $where = 'WHERE ' . ($options->{salesman} ? '' : 'NOT ') . 'COALESCE(salesman)';
  }

  $self->{ $options->{key} } = selectall_hashref_query($self, $dbh, qq|SELECT * FROM business $where ORDER BY lower(description)|);

  $main::lxdebug->leave_sub();
}

sub _get_languages {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_languages" unless ($key);

  my $query = qq|SELECT * FROM language ORDER BY id|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_dunning_configs {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_dunning_configs" unless ($key);

  my $query = qq|SELECT * FROM dunning_config ORDER BY dunning_level|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_currencies {
$main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_currencies" unless ($key);

  $self->{$key} = [$self->get_all_currencies()];

  $main::lxdebug->leave_sub();
}

sub _get_payments {
$main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_payments" unless ($key);

  my $query = qq|SELECT * FROM payment_terms ORDER BY sortkey|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_customers {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  my $options        = ref $key eq 'HASH' ? $key : { key => $key };
  $options->{key}  ||= "all_customers";
  my $limit_clause   = $options->{limit} ? "LIMIT $options->{limit}" : '';

  my @where;
  push @where, qq|business_id IN (SELECT id FROM business WHERE salesman)| if  $options->{business_is_salesman};
  push @where, qq|NOT obsolete|                                            if !$options->{with_obsolete};
  my $where_str = @where ? "WHERE " . join(" AND ", map { "($_)" } @where) : '';

  my $query = qq|SELECT * FROM customer $where_str ORDER BY name $limit_clause|;
  $self->{ $options->{key} } = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_vendors {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_vendors" unless ($key);

  my $query = qq|SELECT * FROM vendor WHERE NOT obsolete ORDER BY name|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_departments {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_departments" unless ($key);

  my $query = qq|SELECT * FROM department ORDER BY description|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_warehouses {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $param) = @_;

  my ($key, $bins_key);

  if ('' eq ref $param) {
    $key = $param;

  } else {
    $key      = $param->{key};
    $bins_key = $param->{bins};
  }

  my $query = qq|SELECT w.* FROM warehouse w
                 WHERE (NOT w.invalid) AND
                   ((SELECT COUNT(b.*) FROM bin b WHERE b.warehouse_id = w.id) > 0)
                 ORDER BY w.sortkey|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  if ($bins_key) {
    $query = qq|SELECT id, description FROM bin WHERE warehouse_id = ?
                ORDER BY description|;
    my $sth = prepare_query($self, $dbh, $query);

    foreach my $warehouse (@{ $self->{$key} }) {
      do_statement($self, $sth, $query, $warehouse->{id});
      $warehouse->{$bins_key} = [];

      while (my $ref = $sth->fetchrow_hashref()) {
        push @{ $warehouse->{$bins_key} }, $ref;
      }
    }
    $sth->finish();
  }

  $main::lxdebug->leave_sub();
}

sub _get_simple {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $table, $key, $sortkey) = @_;

  my $query  = qq|SELECT * FROM $table|;
  $query    .= qq| ORDER BY $sortkey| if ($sortkey);

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub get_lists {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my %params = @_;

  croak "get_lists: shipto is no longer supported" if $params{shipto};

  my $dbh = $self->get_standard_dbh(\%main::myconfig);
  my ($sth, $query, $ref);

  my ($vc, $vc_id);
  if ($params{contacts}) {
    $vc = 'customer' if $self->{"vc"} eq "customer";
    $vc = 'vendor'   if $self->{"vc"} eq "vendor";
    die "invalid use of get_lists, need 'vc'" unless $vc;
    $vc_id = $self->{"${vc}_id"};
  }

  if ($params{"contacts"}) {
    $self->_get_contacts($dbh, $vc_id, $params{"contacts"});
  }

  if ($params{"projects"} || $params{"all_projects"}) {
    $self->_get_projects($dbh, $params{"all_projects"} ?
                         $params{"all_projects"} : $params{"projects"},
                         $params{"all_projects"} ? 1 : 0);
  }

  if ($params{"printers"}) {
    $self->_get_printers($dbh, $params{"printers"});
  }

  if ($params{"languages"}) {
    $self->_get_languages($dbh, $params{"languages"});
  }

  if ($params{"charts"}) {
    $self->_get_charts($dbh, $params{"charts"});
  }

  if ($params{"taxzones"}) {
    $self->_get_taxzones($dbh, $params{"taxzones"});
  }

  if ($params{"employees"}) {
    $self->_get_employees($dbh, $params{"employees"});
  }

  if ($params{"salesmen"}) {
    $self->_get_employees($dbh, $params{"salesmen"});
  }

  if ($params{"business_types"}) {
    $self->_get_business_types($dbh, $params{"business_types"});
  }

  if ($params{"dunning_configs"}) {
    $self->_get_dunning_configs($dbh, $params{"dunning_configs"});
  }

  if($params{"currencies"}) {
    $self->_get_currencies($dbh, $params{"currencies"});
  }

  if($params{"customers"}) {
    $self->_get_customers($dbh, $params{"customers"});
  }

  if($params{"vendors"}) {
    if (ref $params{"vendors"} eq 'HASH') {
      $self->_get_vendors($dbh, $params{"vendors"}{key}, $params{"vendors"}{limit});
    } else {
      $self->_get_vendors($dbh, $params{"vendors"});
    }
  }

  if($params{"payments"}) {
    $self->_get_payments($dbh, $params{"payments"});
  }

  if($params{"departments"}) {
    $self->_get_departments($dbh, $params{"departments"});
  }

  if ($params{price_factors}) {
    $self->_get_simple($dbh, 'price_factors', $params{price_factors}, 'sortkey');
  }

  if ($params{warehouses}) {
    $self->_get_warehouses($dbh, $params{warehouses});
  }

  if ($params{partsgroup}) {
    $self->get_partsgroup(\%main::myconfig, { all => 1, target => $params{partsgroup} });
  }

  $main::lxdebug->leave_sub();
}

# this sub gets the id and name from $table
sub get_name {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  # connect to database
  my $dbh = $self->get_standard_dbh($myconfig);

  $table = $table eq "customer" ? "customer" : "vendor";
  my $arap = $self->{arap} eq "ar" ? "ar" : "ap";

  my ($query, @values);

  if (!$self->{openinvoices}) {
    my $where;
    if ($self->{customernumber} ne "") {
      $where = qq|(vc.customernumber ILIKE ?)|;
      push(@values, like($self->{customernumber}));
    } else {
      $where = qq|(vc.name ILIKE ?)|;
      push(@values, like($self->{$table}));
    }

    $query =
      qq~SELECT vc.id, vc.name,
           vc.street || ' ' || vc.zipcode || ' ' || vc.city || ' ' || vc.country AS address
         FROM $table vc
         WHERE $where AND (NOT vc.obsolete)
         ORDER BY vc.name~;
  } else {
    $query =
      qq~SELECT DISTINCT vc.id, vc.name,
           vc.street || ' ' || vc.zipcode || ' ' || vc.city || ' ' || vc.country AS address
         FROM $arap a
         JOIN $table vc ON (a.${table}_id = vc.id)
         WHERE NOT (a.amount = a.paid) AND (vc.name ILIKE ?)
         ORDER BY vc.name~;
    push(@values, like($self->{$table}));
  }

  $self->{name_list} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return scalar(@{ $self->{name_list} });
}

sub new_lastmtime {

  my ($self, $table, $provided_dbh) = @_;

  my $dbh = $provided_dbh ? $provided_dbh : $self->get_standard_dbh;
  return                                       unless $self->{id};
  croak ("wrong call, no valid table defined") unless $table =~ /^(oe|ar|ap|delivery_orders|parts)$/;

  my $query       = "SELECT mtime, itime FROM " . $table . " WHERE id = ?";
  my $ref         = selectfirst_hashref_query($self, $dbh, $query, $self->{id});
  $ref->{mtime} ||= $ref->{itime};
  $self->{lastmtime} = $ref->{mtime};

}

sub mtime_ischanged {
  my ($self, $table, $option) = @_;

  return                                       unless $self->{id};
  croak ("wrong call, no valid table defined") unless $table =~ /^(oe|ar|ap|delivery_orders|parts)$/;

  my $query       = "SELECT mtime, itime FROM " . $table . " WHERE id = ?";
  my $ref         = selectfirst_hashref_query($self, $self->get_standard_dbh, $query, $self->{id});
  $ref->{mtime} ||= $ref->{itime};

  if ($self->{lastmtime} && $self->{lastmtime} ne $ref->{mtime} ) {
      $self->error(($option eq 'mail') ?
        t8("The document has been changed by another user. No mail was sent. Please reopen it in another window and copy the changes to the new window") :
        t8("The document has been changed by another user. Please reopen it in another window and copy the changes to the new window")
      );
    $::dispatcher->end_request;
  }
}

# language_payment duplicates some of the functionality of all_vc (language,
# printer, payment_terms), and at least in the case of sales invoices both
# all_vc and language_payment are called when adding new invoices
sub language_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  # get languages
  my $query = qq|SELECT id, description
                 FROM language
                 ORDER BY id|;

  $self->{languages} = selectall_hashref_query($self, $dbh, $query);

  # get printer
  $query = qq|SELECT printer_description, id
              FROM printers
              ORDER BY printer_description|;

  $self->{printers} = selectall_hashref_query($self, $dbh, $query);

  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              WHERE ( obsolete IS FALSE OR id = ? )
              ORDER BY sortkey |;
  $self->{payment_terms} = selectall_hashref_query($self, $dbh, $query, $self->{payment_id} || undef);

  # get buchungsgruppen
  $query = qq|SELECT id, description
              FROM buchungsgruppen|;

  $self->{BUCHUNGSGRUPPEN} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

# this is only used for reports
sub all_departments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT id, description
                 FROM department
                 ORDER BY description|;
  $self->{all_departments} = selectall_hashref_query($self, $dbh, $query);

  delete($self->{all_departments}) unless (@{ $self->{all_departments} || [] });

  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  my ($self, $module, $myconfig, $table, $provided_dbh) = @_;

  my ($fld, $arap);
  if ($table eq "customer") {
    $fld = "buy";
    $arap = "ar";
  } else {
    $table = "vendor";
    $fld = "sell";
    $arap = "ap";
  }

  # get last customers or vendors
  my ($query, $sth, $ref);

  my $dbh = $provided_dbh ? $provided_dbh : $self->get_standard_dbh($myconfig);
  my %xkeyref = ();

  if (!$self->{id}) {

    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = $dbh->quote($self->{transdate});
    }

    # now get the account numbers
    $query = qq|
      SELECT c.accno, c.description, c.link, c.taxkey_id, c.id AS chart_id, tk2.tax_id
        FROM chart c
        -- find newest entries in taxkeys
        INNER JOIN (
          SELECT chart_id, MAX(startdate) AS startdate
          FROM taxkeys
          WHERE (startdate <= $transdate)
          GROUP BY chart_id
        ) tk ON (c.id = tk.chart_id)
        -- and load all of those entries
        INNER JOIN taxkeys tk2
           ON (tk.chart_id = tk2.chart_id AND tk.startdate = tk2.startdate)
       WHERE (c.link LIKE ?)
      ORDER BY c.accno|;

    $sth = $dbh->prepare($query);

    do_statement($self, $sth, $query, like($module));

    $self->{accounts} = "";
    while ($ref = $sth->fetchrow_hashref("NAME_lc")) {

      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /\Q$module\E/) {

          # cross reference for keys
          $xkeyref{ $ref->{accno} } = $key;

          push @{ $self->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              chart_id    => $ref->{chart_id},
              description => $ref->{description},
              taxkey      => $ref->{taxkey_id},
              tax_id      => $ref->{tax_id} };

          $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
        }
      }
    }
  }

  # get taxkeys and description
  $query = qq|SELECT id, taxkey, taxdescription FROM tax|;
  $self->{TAXKEY} = selectall_hashref_query($self, $dbh, $query);

  if (($module eq "AP") || ($module eq "AR")) {
    # get tax rates and description
    $query = qq|SELECT * FROM tax|;
    $self->{TAX} = selectall_hashref_query($self, $dbh, $query);
  }

  my $extra_columns = '';
  $extra_columns   .= 'a.direct_debit, ' if ($module eq 'AR') || ($module eq 'AP');

  if ($self->{id}) {
    $query =
      qq|SELECT
           a.cp_id, a.invnumber, a.transdate, a.${table}_id, a.datepaid, a.deliverydate,
           a.duedate, a.tax_point, a.ordnumber, a.taxincluded, (SELECT cu.name FROM currencies cu WHERE cu.id=a.currency_id) AS currency, a.notes,
           a.mtime, a.itime,
           a.intnotes, a.department_id, a.amount AS oldinvtotal,
           a.paid AS oldtotalpaid, a.employee_id, a.gldate, a.type,
           a.globalproject_id, a.transaction_description, ${extra_columns}
           c.name AS $table,
           d.description AS department,
           e.name AS employee
         FROM $arap a
         JOIN $table c ON (a.${table}_id = c.id)
         LEFT JOIN employee e ON (e.id = a.employee_id)
         LEFT JOIN department d ON (d.id = a.department_id)
         WHERE a.id = ?|;
    $ref = selectfirst_hashref_query($self, $dbh, $query, $self->{id});

    foreach my $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }
    $self->{mtime}   ||= $self->{itime};
    $self->{lastmtime} = $self->{mtime};
    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = $dbh->quote($self->{transdate});
    }

    # now get the account numbers
    $query = qq|SELECT c.accno, c.description, c.link, c.taxkey_id, c.id AS chart_id, tk.tax_id
                FROM chart c
                LEFT JOIN taxkeys tk ON (tk.chart_id = c.id)
                WHERE c.link LIKE ?
                  AND (tk.id = (SELECT id FROM taxkeys WHERE taxkeys.chart_id = c.id AND startdate <= $transdate ORDER BY startdate DESC LIMIT 1)
                    OR c.link LIKE '%_tax%' OR c.taxkey_id IS NULL)
                ORDER BY c.accno|;

    $sth = $dbh->prepare($query);
    do_statement($self, $sth, $query, like($module));

    $self->{accounts} = "";
    while ($ref = $sth->fetchrow_hashref("NAME_lc")) {

      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /\Q$module\E/) {

          # cross reference for keys
          $xkeyref{ $ref->{accno} } = $key;

          push @{ $self->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              chart_id    => $ref->{chart_id},
              description => $ref->{description},
              taxkey      => $ref->{taxkey_id},
              tax_id      => $ref->{tax_id} };

          $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
        }
      }
    }


    # get amounts from individual entries
    $query =
      qq|SELECT
           c.accno, c.description,
           a.acc_trans_id, a.source, a.amount, a.memo, a.transdate, a.gldate, a.cleared, a.project_id, a.taxkey, a.chart_id,
           p.projectnumber,
           t.rate, t.id,
           a.fx_transaction
         FROM acc_trans a
         LEFT JOIN chart c ON (c.id = a.chart_id)
         LEFT JOIN project p ON (p.id = a.project_id)
         LEFT JOIN tax t ON (t.id= a.tax_id)
         WHERE a.trans_id = ?
         ORDER BY a.acc_trans_id, a.transdate|;
    $sth = $dbh->prepare($query);
    do_statement($self, $sth, $query, $self->{id});

    # get exchangerate for currency
    ($self->{exchangerate}, $self->{record_forex}) = $self->check_exchangerate($myconfig, $self->{currency}, $self->{transdate}, $fld,
                                                                               $self->{id}, $arap);

    my $index = 0;
    my @fx_transaction_entries;

    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      # skip fx_transaction entries and add them for post processing
      if ($ref->{fx_transaction}) {
        die "first entry in a record transaction should not be fx_transaction" unless @fx_transaction_entries;
        push @{ $fx_transaction_entries[-1] }, $ref;
        next;
      } else {
        push @fx_transaction_entries, [ $ref ];
      }


      # credit and debit bookings calc fx rate for positions
      # also used as exchangerate_$i for payments - exchangerate here can come from frontend or from bank transactions
      $ref->{exchangerate} =
        $self->check_exchangerate($myconfig, $self->{currency}, $ref->{transdate}, $fld);
      if (!($xkeyref{ $ref->{accno} } =~ /tax/)) {
        $index++;
      }
      if (($xkeyref{ $ref->{accno} } =~ /paid/) && ($self->{type} eq "credit_note")) {
        $ref->{amount} *= -1;
      }
      $ref->{index} = $index;

      push @{ $self->{acc_trans}{ $xkeyref{ $ref->{accno} } } }, $ref;
    }

    # post process fx_transactions.
    # old bin/mozilla code first posts the intended foreign currency amount and then the correction for exchange flagged as fx_transaction
    # for example: when posting 20 USD on a system in EUR with an exchangerate of 1.1, the resulting acc_trans will say:
    #   +20 no fx (intended: 20 USD)
    #    +2    fx (but it's actually 22 EUR)
    #
    # for payments this is followed by the fxgain/loss. when paying the above invoice with 20 USD at 1.3 exchange:
    #   -20 no fx (intended: 20 USD)
    #    -6    fx (but it's actually 26 EUR)
    #    +4    fx (but 4 of them go to fxgain)
    #
    # bin/mozilla/ controllers will display the intended amount as is, but would have to guess at the actual book value
    # without the extra fields
    #
    # bank transactions however will convert directly into internal currency, so a foreign currency invoice might end up
    # having non-fxtransactions. to make sure that these are roundtrip safe, flag the fx-transaction payments as fx and give the
    # intendended internal amount
    #
    # this still operates on the cached entries of form->{acc_trans}
    for my $fx_block (@fx_transaction_entries) {
      my ($ref, @fx_entries) = @$fx_block;
      for my $fx_ref (@fx_entries) {
        if ($fx_ref->{chart_id} == $ref->{chart_id}) {
          $ref->{defaultcurrency_paid} //= $ref->{amount};
          $ref->{defaultcurrency_paid} += $fx_ref->{amount};
          $ref->{fx_transaction} = 1;
        }
      }
    }

    $sth->finish;
    #check das:
    $query =
      qq|SELECT
           d.closedto, d.revtrans,
           (SELECT cu.name FROM currencies cu WHERE cu.id=d.currency_id) AS defaultcurrency,
           (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
           (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
           (SELECT c.accno FROM chart c WHERE d.rndgain_accno_id = c.id) AS rndgain_accno,
           (SELECT c.accno FROM chart c WHERE d.rndloss_accno_id = c.id) AS rndloss_accno
         FROM defaults d|;
    $ref = selectfirst_hashref_query($self, $dbh, $query);
    map { $self->{$_} = $ref->{$_} } keys %$ref;

  } else {

    # get date
    $query =
       qq|SELECT
            current_date AS transdate, d.closedto, d.revtrans,
            (SELECT cu.name FROM currencies cu WHERE cu.id=d.currency_id) AS defaultcurrency,
            (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
            (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
            (SELECT c.accno FROM chart c WHERE d.rndgain_accno_id = c.id) AS rndgain_accno,
            (SELECT c.accno FROM chart c WHERE d.rndloss_accno_id = c.id) AS rndloss_accno
          FROM defaults d|;
    $ref = selectfirst_hashref_query($self, $dbh, $query);
    map { $self->{$_} = $ref->{$_} } keys %$ref;

    # failsafe, set currency if caller has not yet assigned one
    $self->lastname_used($dbh, $myconfig, $table, $module) unless ($self->{"$self->{vc}_id"});
    $self->{currency} = $self->{defaultcurrency}           unless $self->{currency};
    $self->{exchangerate} =
      $self->check_exchangerate($myconfig, $self->{currency}, $self->{transdate}, $fld);
  }

  $main::lxdebug->leave_sub();
}

sub lastname_used {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $myconfig, $table, $module) = @_;

  my ($arap, $where);

  $table         = $table eq "customer" ? "customer" : "vendor";
  my %column_map = ("a.${table}_id"           => "${table}_id",
                    "a.department_id"         => "department_id",
                    "d.description"           => "department",
                    "ct.name"                 => $table,
                    "cu.name"                 => "currency",
    );

  if ($self->{type} =~ /delivery_order/) {
    $arap  = 'delivery_orders';
    delete $column_map{"cu.currency"};

  } elsif ($self->{type} =~ /_order/) {
    $arap  = 'oe';
    $where = "quotation = '0'";

  } elsif ($self->{type} =~ /_quotation/) {
    $arap  = 'oe';
    $where = "quotation = '1'";

  } elsif ($table eq 'customer') {
    $arap  = 'ar';

  } else {
    $arap  = 'ap';

  }

  $where           = "($where) AND" if ($where);
  my $query        = qq|SELECT MAX(id) FROM $arap
                        WHERE $where ${table}_id > 0|;
  my ($trans_id)   = selectrow_query($self, $dbh, $query);
  $trans_id       *= 1;

  my $column_spec  = join(', ', map { "${_} AS $column_map{$_}" } keys %column_map);
  $query           = qq|SELECT $column_spec
                        FROM $arap a
                        LEFT JOIN $table     ct ON (a.${table}_id = ct.id)
                        LEFT JOIN department d  ON (a.department_id = d.id)
                        LEFT JOIN currencies cu ON (cu.id=ct.currency_id)
                        WHERE a.id = ?|;
  my $ref          = selectfirst_hashref_query($self, $dbh, $query, $trans_id);

  map { $self->{$_} = $ref->{$_} } values %column_map;

  $main::lxdebug->leave_sub();
}

sub get_variable_content_types {
  my ($self) = @_;

  my %html_variables = (
    longdescription  => 'html',
    partnotes        => 'html',
    notes            => 'html',
    orignotes        => 'html',
    notes1           => 'html',
    notes2           => 'html',
    notes3           => 'html',
    notes4           => 'html',
    header_text      => 'html',
    footer_text      => 'html',
  );

  return {
    %html_variables,
    $self->get_variable_content_types_for_cvars,
  };
}

sub get_variable_content_types_for_cvars {
  my ($self)       = @_;
  my $html_configs = SL::DB::Manager::CustomVariableConfig->get_all(where => [ type => 'htmlfield' ]);
  my %types;

  if (@{ $html_configs }) {
    my %prefix_by_module = (
      Contacts => 'cp_cvar_',
      CT       => 'vc_cvar_',
      IC       => 'ic_cvar_',
      Projects => 'project_cvar_',
      ShipTo   => 'shiptocvar_',
    );

    foreach my $cfg (@{ $html_configs }) {
      my $prefix = $prefix_by_module{$cfg->module};
      $types{$prefix . $cfg->name} = 'html' if $prefix;
    }
  }

  return %types;
}

sub current_date {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my $myconfig = shift || \%::myconfig;
  my ($thisdate, $days) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  my $query;

  $days *= 1;
  if ($thisdate) {
    my $dateformat = $myconfig->{dateformat};
    $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;
    $thisdate = $dbh->quote($thisdate);
    $query = qq|SELECT to_date($thisdate, '$dateformat') + $days AS thisdate|;
  } else {
    $query = qq|SELECT current_date AS thisdate|;
  }

  ($thisdate) = selectrow_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $thisdate;
}

sub redo_rows {
  $main::lxdebug->enter_sub();

  my ($self, $flds, $new, $count, $numrows) = @_;

  my @ndx = ();

  map { push @ndx, { num => $new->[$_ - 1]->{runningnumber}, ndx => $_ } } 1 .. $count;

  my $i = 0;

  # fill rows
  foreach my $item (sort { $a->{num} <=> $b->{num} } @ndx) {
    $i++;
    my $j = $item->{ndx} - 1;
    map { $self->{"${_}_$i"} = $new->[$j]->{$_} } @{$flds};
  }

  # delete empty rows
  for $i ($count + 1 .. $numrows) {
    map { delete $self->{"${_}_$i"} } @{$flds};
  }

  $main::lxdebug->leave_sub();
}

sub update_status {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my ($i, $id);

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my $query = qq|DELETE FROM status
                   WHERE (formname = ?) AND (trans_id = ?)|;
    my $sth = prepare_query($self, $dbh, $query);

    if ($self->{formname} =~ /(check|receipt)/) {
      for $i (1 .. $self->{rowcount}) {
        do_statement($self, $sth, $query, $self->{formname}, $self->{"id_$i"} * 1);
      }
    } else {
      do_statement($self, $sth, $query, $self->{formname}, $self->{id});
    }
    $sth->finish();

    my $printed = ($self->{printed} =~ /\Q$self->{formname}\E/) ? "1" : "0";
    my $emailed = ($self->{emailed} =~ /\Q$self->{formname}\E/) ? "1" : "0";

    my %queued = split / /, $self->{queued};
    my @values;

    if ($self->{formname} =~ /(check|receipt)/) {

      # this is a check or receipt, add one entry for each lineitem
      my ($accno) = split /--/, $self->{account};
      $query = qq|INSERT INTO status (trans_id, printed, spoolfile, formname, chart_id)
                  VALUES (?, ?, ?, ?, (SELECT c.id FROM chart c WHERE c.accno = ?))|;
      @values = ($printed, $queued{$self->{formname}}, $self->{prinform}, $accno);
      $sth = prepare_query($self, $dbh, $query);

      for $i (1 .. $self->{rowcount}) {
        if ($self->{"checked_$i"}) {
          do_statement($self, $sth, $query, $self->{"id_$i"}, @values);
        }
      }
      $sth->finish();

    } else {
      $query = qq|INSERT INTO status (trans_id, printed, emailed, spoolfile, formname)
                  VALUES (?, ?, ?, ?, ?)|;
      do_query($self, $dbh, $query, $self->{id}, $printed, $emailed,
               $queued{$self->{formname}}, $self->{formname});
    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub save_status {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my ($query, $printed, $emailed);

  my $formnames  = $self->{printed};
  my $emailforms = $self->{emailed};

  $query = qq|DELETE FROM status
                 WHERE (formname = ?) AND (trans_id = ?)|;
  do_query($self, $dbh, $query, $self->{formname}, $self->{id});

  # this only applies to the forms
  # checks and receipts are posted when printed or queued

  if ($self->{queued}) {
    my %queued = split / /, $self->{queued};

    foreach my $formname (keys %queued) {
      $printed = ($self->{printed} =~ /\Q$self->{formname}\E/) ? "1" : "0";
      $emailed = ($self->{emailed} =~ /\Q$self->{formname}\E/) ? "1" : "0";

      $query = qq|INSERT INTO status (trans_id, printed, emailed, spoolfile, formname)
                  VALUES (?, ?, ?, ?, ?)|;
      do_query($self, $dbh, $query, $self->{id}, $printed, $emailed, $queued{$formname}, $formname);

      $formnames  =~ s/\Q$self->{formname}\E//;
      $emailforms =~ s/\Q$self->{formname}\E//;

    }
  }

  # save printed, emailed info
  $formnames  =~ s/^ +//g;
  $emailforms =~ s/^ +//g;

  my %status = ();
  map { $status{$_}{printed} = 1 } split / +/, $formnames;
  map { $status{$_}{emailed} = 1 } split / +/, $emailforms;

  foreach my $formname (keys %status) {
    $printed = ($formnames  =~ /\Q$self->{formname}\E/) ? "1" : "0";
    $emailed = ($emailforms =~ /\Q$self->{formname}\E/) ? "1" : "0";

    $query = qq|INSERT INTO status (trans_id, printed, emailed, formname)
                VALUES (?, ?, ?, ?)|;
    do_query($self, $dbh, $query, $self->{id}, $printed, $emailed, $formname);
  }

  $main::lxdebug->leave_sub();
}

#--- 4 locale ---#
# $main::locale->text('SAVED')
# $main::locale->text('SCREENED')
# $main::locale->text('DELETED')
# $main::locale->text('ADDED')
# $main::locale->text('PAYMENT POSTED')
# $main::locale->text('POSTED')
# $main::locale->text('POSTED AS NEW')
# $main::locale->text('ELSE')
# $main::locale->text('SAVED FOR DUNNING')
# $main::locale->text('DUNNING STARTED')
# $main::locale->text('PREVIEWED')
# $main::locale->text('PRINTED')
# $main::locale->text('MAILED')
# $main::locale->text('SCREENED')
# $main::locale->text('CANCELED')
# $main::locale->text('IMPORT')
# $main::locale->text('UNDO TRANSFER')
# $main::locale->text('UNIMPORT')
# $main::locale->text('invoice')
# $main::locale->text('invoice_for_advance_payment')
# $main::locale->text('final_invoice')
# $main::locale->text('proforma')
# $main::locale->text('storno_invoice')
# $main::locale->text('sales_order_intake')
# $main::locale->text('sales_order')
# $main::locale->text('pick_list')
# $main::locale->text('purchase_order')
# $main::locale->text('purchase_order_confirmation')
# $main::locale->text('bin_list')
# $main::locale->text('sales_quotation')
# $main::locale->text('request_quotation')
# $main::locale->text('purchase_quotation_intake')

sub save_history {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $dbh  = shift || SL::DB->client->dbh;
  SL::DB->client->with_transaction(sub {

    if(!exists $self->{employee_id}) {
      &get_employee($self, $dbh);
    }

    my $query =
     qq|INSERT INTO history_erp (trans_id, employee_id, addition, what_done, snumbers) | .
     qq|VALUES (?, (SELECT id FROM employee WHERE login = ?), ?, ?, ?)|;
    my @values = (conv_i($self->{id}), $self->{login},
                  $self->{addition}, $self->{what_done}, "$self->{snumbers}");
    do_query($self, $dbh, $query, @values);
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub get_history {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $trans_id, $restriction, $order) = @_;
  my ($orderBy, $desc) = split(/\-\-/, $order);
  $order = " ORDER BY " . ($order eq "" ? " h.itime " : ($desc == 1 ? $orderBy . " DESC " : $orderBy . " "));
  my @tempArray;
  my $i = 0;
  if ($trans_id ne "") {
    my $query =
      qq|SELECT h.employee_id, h.itime::timestamp(0) AS itime, h.addition, h.what_done, emp.name, h.snumbers, h.trans_id AS id | .
      qq|FROM history_erp h | .
      qq|LEFT JOIN employee emp ON (emp.id = h.employee_id) | .
      qq|WHERE (trans_id = | . $dbh->quote($trans_id) . qq|) $restriction | .
      $order;

    my $sth = $dbh->prepare($query) || $self->dberror($query);

    $sth->execute() || $self->dberror("$query");

    while(my $hash_ref = $sth->fetchrow_hashref()) {
      $hash_ref->{addition} = $main::locale->text($hash_ref->{addition});
      $hash_ref->{what_done} = $main::locale->text($hash_ref->{what_done});
      my ( $what, $number ) = split /_/, $hash_ref->{snumbers};
      $hash_ref->{snumbers} = $number;
      $hash_ref->{haslink}  = 'controller.pl?action=EmailJournal/show&id='.$number if $what eq 'emailjournal';
      $hash_ref->{snumbers} = $main::locale->text("E-Mail").' '.$number if $what eq 'emailjournal';
      $tempArray[$i++] = $hash_ref;
    }
    $main::lxdebug->leave_sub() and return \@tempArray
      if ($i > 0 && $tempArray[0] ne "");
  }
  $main::lxdebug->leave_sub();
  return 0;
}

sub get_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;
  my $target = $p->{target} || 'all_partsgroup';

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
                 FROM partsgroup pg
                 JOIN parts p ON (p.partsgroup_id = pg.id) |;
  my @values;

  $query .= qq|ORDER BY partsgroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, partsgroup FROM partsgroup
                ORDER BY partsgroup|;
  }

  $self->{$target} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub get_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT p.id, p.pricegroup
                 FROM pricegroup p|;

  $query .= qq| ORDER BY pricegroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, pricegroup FROM pricegroup
                ORDER BY pricegroup|;
  }

  $self->{all_pricegroup} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub all_years {
# usage $form->all_years($myconfig, [$dbh])
# return list of all years where bookings found
# (@all_years)

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $dbh) = @_;

  $dbh ||= $self->get_standard_dbh($myconfig);

  # get years
  my $query = qq|SELECT (SELECT MIN(transdate) FROM acc_trans),
                   (SELECT MAX(transdate) FROM acc_trans)|;
  my ($startdate, $enddate) = selectrow_query($self, $dbh, $query);

  if ($myconfig->{dateformat} =~ /^yy/) {
    ($startdate) = split /\W/, $startdate;
    ($enddate) = split /\W/, $enddate;
  } else {
    (@_) = split /\W/, $startdate;
    $startdate = $_[2];
    (@_) = split /\W/, $enddate;
    $enddate = $_[2];
  }

  my @all_years;
  $startdate = substr($startdate,0,4);
  $enddate = substr($enddate,0,4);

  while ($enddate >= $startdate) {
    push @all_years, $enddate--;
  }

  return @all_years;

  $main::lxdebug->leave_sub();
}

sub backup_vars {
  $main::lxdebug->enter_sub();
  my $self = shift;
  my @vars = @_;

  map { $self->{_VAR_BACKUP}->{$_} = $self->{$_} if exists $self->{$_} } @vars;

  $main::lxdebug->leave_sub();
}

sub restore_vars {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my @vars = @_;

  map { $self->{$_} = $self->{_VAR_BACKUP}->{$_} if exists $self->{_VAR_BACKUP}->{$_} } @vars;

  $main::lxdebug->leave_sub();
}

sub prepare_for_printing {
  my ($self) = @_;

  my $defaults         = SL::DB::Default->get;

  $self->{templates} ||= $defaults->templates;
  $self->{formname}  ||= $self->{type};
  $self->{media}     ||= 'email';

  die "'media' other than 'email', 'file', 'printer' is not supported yet" unless $self->{media} =~ m/^(?:email|file|printer)$/;

  # Several fields that used to reside in %::myconfig (stored in
  # auth.user_config) are now stored in defaults. Copy them over for
  # compatibility.
  $self->{$_} = $defaults->$_ for qw(company address taxnumber co_ustid duns sepa_creditor_id);

  $self->{"myconfig_${_}"} = $::myconfig{$_} for grep { $_ ne 'dbpasswd' } keys %::myconfig;

  if (!$self->{employee_id}) {
    $self->{"employee_${_}"} = $::myconfig{$_} for qw(email tel fax name signature);
    $self->{"employee_${_}"} = $defaults->$_   for qw(address businessnumber co_ustid company duns sepa_creditor_id taxnumber);
  }

  my $language = $self->{language} ? '_' . $self->{language} : '';

  my ($language_tc, $output_numberformat, $output_dateformat, $output_longdates);
  if ($self->{language_id}) {
    ($language_tc, $output_numberformat, $output_dateformat, $output_longdates) = AM->get_language_details(\%::myconfig, $self, $self->{language_id});
  }

  $output_dateformat   ||= $::myconfig{dateformat};
  $output_numberformat ||= $::myconfig{numberformat};
  $output_longdates    //= 1;

  $self->{myconfig_output_dateformat}   = $output_dateformat   // $::myconfig{dateformat};
  $self->{myconfig_output_longdates}    = $output_longdates    // 1;
  $self->{myconfig_output_numberformat} = $output_numberformat // $::myconfig{numberformat};

  # Retrieve accounts for tax calculation.
  IC->retrieve_accounts(\%::myconfig, $self, map { $_ => $self->{"id_$_"} } 1 .. $self->{rowcount});

  if ($self->{type} =~ /_delivery_order$/) {
    DO->order_details(\%::myconfig, $self);
  } elsif ($self->{type} =~ /sales_order|sales_quotation|request_quotation|purchase_order|purchase_quotation_intake/) {
    OE->order_details(\%::myconfig, $self);
  } elsif ($self->{type} =~ /reclamation/) {
    # skip reclamation here, legacy template arrays are added in the reclamation controller
  } else {
    IS->invoice_details(\%::myconfig, $self, $::locale);
  }

  $self->set_addition_billing_address_print_variables;

  # Chose extension & set source file name
  my $extension = 'html';
  if ($self->{format} eq 'postscript') {
    $self->{postscript}   = 1;
    $extension            = 'tex';
  } elsif ($self->{"format"} =~ /pdf/) {
    $self->{pdf}          = 1;
    $extension            = $self->{'format'} =~ m/opendocument/i ? 'odt' : 'tex';
  } elsif ($self->{"format"} =~ /opendocument/) {
    $self->{opendocument} = 1;
    $extension            = 'odt';
  } elsif ($self->{"format"} =~ /excel/) {
    $self->{excel}        = 1;
    $extension            = 'xls';
  }

  my $printer_code    = $self->{printer_code} ? '_' . $self->{printer_code} : '';
  my $email_extension = $self->{media} eq 'email' && -f ($defaults->templates . "/$self->{formname}_email${language}.${extension}") ? '_email' : '';
  $self->{IN}         = "$self->{formname}${email_extension}${language}${printer_code}.${extension}";

  # Format dates.
  $self->format_dates($output_dateformat, $output_longdates,
                      qw(invdate orddate quodate pldate duedate reqdate transdate tax_point shippingdate deliverydate validitydate paymentdate datepaid
                         transdate_oe deliverydate_oe employee_startdate employee_enddate),
                      grep({ /^(?:datepaid|transdate_oe|reqdate|deliverydate|deliverydate_oe|transdate)_\d+$/ } keys(%{$self})));

  $self->reformat_numbers($output_numberformat, 2,
                          qw(invtotal ordtotal quototal subtotal linetotal listprice sellprice netprice discount tax taxbase total paid),
                          grep({ /^(?:linetotal|listprice|sellprice|netprice|taxbase|discount|paid|subtotal|total|tax)_\d+$/ } keys(%{$self})));

  $self->reformat_numbers($output_numberformat, undef, qw(qty price_factor), grep({ /^qty_\d+$/} keys(%{$self})));

  my ($cvar_date_fields, $cvar_number_fields) = CVar->get_field_format_list('module' => 'CT', 'prefix' => 'vc_');

  if (scalar @{ $cvar_date_fields }) {
    $self->format_dates($output_dateformat, $output_longdates, @{ $cvar_date_fields });
  }

  while (my ($precision, $field_list) = each %{ $cvar_number_fields }) {
    $self->reformat_numbers($output_numberformat, $precision, @{ $field_list });
  }

  # Translate units
  if (($self->{language} // '') ne '') {
    my $template_arrays = $self->{TEMPLATE_ARRAYS} || $self;
    for my $idx (0..scalar(@{ $template_arrays->{unit} }) - 1) {
      $template_arrays->{unit}->[$idx] = AM->translate_units($self, $self->{language}, $template_arrays->{unit}->[$idx], $template_arrays->{qty}->[$idx])
    }
  }

  $self->{template_meta} = {
    formname  => $self->{formname},
    language  => SL::DB::Manager::Language->find_by_or_create(id => $self->{language_id} || undef),
    format    => $self->{format},
    media     => $self->{media},
    extension => $extension,
    printer   => SL::DB::Manager::Printer->find_by_or_create(id => $self->{printer_id} || undef),
    today     => DateTime->today,
  };

  if ($defaults->print_interpolate_variables_in_positions) {
    $self->substitute_placeholders_in_template_arrays({ field => 'description', type => 'text' }, { field => 'longdescription', type => 'html' });
  }

  return $self;
}

sub set_addition_billing_address_print_variables {
  my ($self) = @_;

  return if !$self->{billing_address_id};

  my $address = SL::DB::Manager::AdditionalBillingAddress->find_by(id => $self->{billing_address_id});
  return if !$address;

  $self->{"billing_address_${_}"} = $address->$_ for map { $_->name } @{ $address->meta->columns };
}

sub substitute_placeholders_in_template_arrays {
  my ($self, @fields) = @_;

  foreach my $spec (@fields) {
    $spec     = { field => $spec, type => 'text' } if !ref($spec);
    my $field = $spec->{field};

    next unless exists $self->{TEMPLATE_ARRAYS} && exists $self->{TEMPLATE_ARRAYS}->{$field};

    my $tag_start = $spec->{type} eq 'html' ? '&lt;%' : '<%';
    my $tag_end   = $spec->{type} eq 'html' ? '%&gt;' : '%>';
    my $formatter = $spec->{type} eq 'html' ? sub { $::locale->quote_special_chars('html', $_[0] // '') } : sub { $_[0] };

    $self->{TEMPLATE_ARRAYS}->{$field} = [
      apply { s{${tag_start}(.+?)${tag_end}}{ $formatter->($self->{$1}) }eg }
        @{ $self->{TEMPLATE_ARRAYS}->{$field} }
    ];
  }

  return $self;
}

sub calculate_arap {
  my ($self,$buysell,$taxincluded,$exchangerate,$roundplaces) = @_;

  # this function is used to calculate netamount, total_tax and amount for AP and
  # AR transactions (Kreditoren-/Debitorenbuchungen) by going over all lines
  # (1..$rowcount)
  # Thus it needs a fully prepared $form to work on.
  # calculate_arap assumes $form->{amount_$i} entries still need to be parsed

  # The calculated total values are all rounded (default is to 2 places) and
  # returned as parameters rather than directly modifying form.  The aim is to
  # make the calculation of AP and AR behave identically.  There is a test-case
  # for this function in t/form/arap.t

  # While calculating the totals $form->{amount_$i} and $form->{tax_$i} are
  # modified and formatted and receive the correct sign for writing straight to
  # acc_trans, depending on whether they are ar or ap.

  # check parameters
  die "taxincluded needed in Form->calculate_arap" unless defined $taxincluded;
  die "exchangerate needed in Form->calculate_arap" unless defined $exchangerate;
  die 'illegal buysell parameter, has to be \"buy\" or \"sell\" in Form->calculate_arap\n' unless $buysell =~ /^(buy|sell)$/;
  $roundplaces = 2 unless $roundplaces;

  my $sign = 1;  # adjust final results for writing amount to acc_trans
  $sign = -1 if $buysell eq 'buy';

  my ($netamount,$total_tax,$amount);

  my $tax;

  # parse and round amounts, setting correct sign for writing to acc_trans
  for my $i (1 .. $self->{rowcount}) {
    $self->{"amount_$i"} = $self->round_amount($self->parse_amount(\%::myconfig, $self->{"amount_$i"}) * $exchangerate * $sign, $roundplaces);

    $amount += $self->{"amount_$i"} * $sign;
  }

  for my $i (1 .. $self->{rowcount}) {
    next unless $self->{"amount_$i"};
    ($self->{"tax_id_$i"}) = split /--/, $self->{"taxchart_$i"};
    my $tax_id = $self->{"tax_id_$i"};

    my $selected_tax = SL::DB::Manager::Tax->find_by(id => "$tax_id");
    if ( $selected_tax && !$selected_tax->reverse_charge_chart_id) {
      if ( $buysell eq 'sell' ) {
        $self->{AR_amounts}{"tax_$i"} = $selected_tax->chart->accno if defined $selected_tax->chart;
      } else {
        $self->{AP_amounts}{"tax_$i"} = $selected_tax->chart->accno if defined $selected_tax->chart;
      };

      $self->{"taxkey_$i"} = $selected_tax->taxkey;
      $self->{"taxrate_$i"} = $selected_tax->rate;
    };

    $self->{"taxkey_$i"} = $selected_tax->taxkey if ($selected_tax && $selected_tax->reverse_charge_chart_id);

    ($self->{"amount_$i"}, $self->{"tax_$i"}) = $self->calculate_tax($self->{"amount_$i"},$self->{"taxrate_$i"},$taxincluded,$roundplaces);

    $netamount  += $self->{"amount_$i"};
    $total_tax  += $self->{"tax_$i"};

  }
  $amount = $netamount + $total_tax;

  # due to $sign amount_$i und tax_$i already have the right sign for acc_trans
  # but reverse sign of totals for writing amounts to ar
  if ( $buysell eq 'buy' ) {
    $netamount *= -1;
    $amount    *= -1;
    $total_tax *= -1;
  };

  return($netamount,$total_tax,$amount);
}

sub format_dates {
  my ($self, $dateformat, $longformat, @indices) = @_;

  $dateformat ||= $::myconfig{dateformat};

  foreach my $idx (@indices) {
    if ($self->{TEMPLATE_ARRAYS} && (ref($self->{TEMPLATE_ARRAYS}->{$idx}) eq "ARRAY")) {
      for (my $i = 0; $i < scalar(@{ $self->{TEMPLATE_ARRAYS}->{$idx} }); $i++) {
        $self->{TEMPLATE_ARRAYS}->{$idx}->[$i] = $::locale->reformat_date(\%::myconfig, $self->{TEMPLATE_ARRAYS}->{$idx}->[$i], $dateformat, $longformat);
      }
    }

    next unless defined $self->{$idx};

    if (!ref($self->{$idx})) {
      $self->{$idx} = $::locale->reformat_date(\%::myconfig, $self->{$idx}, $dateformat, $longformat);

    } elsif (ref($self->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{ $self->{$idx} }); $i++) {
        $self->{$idx}->[$i] = $::locale->reformat_date(\%::myconfig, $self->{$idx}->[$i], $dateformat, $longformat);
      }
    }
  }
}

sub reformat_numbers {
  my ($self, $numberformat, $places, @indices) = @_;

  return if !$numberformat || ($numberformat eq $::myconfig{numberformat});

  foreach my $idx (@indices) {
    if ($self->{TEMPLATE_ARRAYS} && (ref($self->{TEMPLATE_ARRAYS}->{$idx}) eq "ARRAY")) {
      for (my $i = 0; $i < scalar(@{ $self->{TEMPLATE_ARRAYS}->{$idx} }); $i++) {
        $self->{TEMPLATE_ARRAYS}->{$idx}->[$i] = $self->parse_amount(\%::myconfig, $self->{TEMPLATE_ARRAYS}->{$idx}->[$i]);
      }
    }

    next unless defined $self->{$idx};

    if (!ref($self->{$idx})) {
      $self->{$idx} = $self->parse_amount(\%::myconfig, $self->{$idx});

    } elsif (ref($self->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{ $self->{$idx} }); $i++) {
        $self->{$idx}->[$i] = $self->parse_amount(\%::myconfig, $self->{$idx}->[$i]);
      }
    }
  }

  my $saved_numberformat    = $::myconfig{numberformat};
  $::myconfig{numberformat} = $numberformat;

  foreach my $idx (@indices) {
    if ($self->{TEMPLATE_ARRAYS} && (ref($self->{TEMPLATE_ARRAYS}->{$idx}) eq "ARRAY")) {
      for (my $i = 0; $i < scalar(@{ $self->{TEMPLATE_ARRAYS}->{$idx} }); $i++) {
        $self->{TEMPLATE_ARRAYS}->{$idx}->[$i] = $self->format_amount(\%::myconfig, $self->{TEMPLATE_ARRAYS}->{$idx}->[$i], $places);
      }
    }

    next unless defined $self->{$idx};

    if (!ref($self->{$idx})) {
      $self->{$idx} = $self->format_amount(\%::myconfig, $self->{$idx}, $places);

    } elsif (ref($self->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{ $self->{$idx} }); $i++) {
        $self->{$idx}->[$i] = $self->format_amount(\%::myconfig, $self->{$idx}->[$i], $places);
      }
    }
  }

  $::myconfig{numberformat} = $saved_numberformat;
}

sub create_email_signature {
  my $client_signature = $::instance_conf->get_signature;
  my $user_signature   = $::myconfig{signature};

  return join '', grep { $_ } ($user_signature, $client_signature);
}

sub calculate_tax {
  # this function calculates the net amount and tax for the lines in ar, ap and
  # gl and is used for update as well as post. When used with update the return
  # value of amount isn't needed

  # calculate_tax should always work with positive values, or rather as the user inputs them
  # calculate_tax uses db/perl numberformat, i.e. parsed numbers
  # convert to negative numbers (when necessary) only when writing to acc_trans
  # the amount from $form for ap/ar/gl is currently always rounded to 2 decimals before it reaches here
  # for post_transaction amount already contains exchangerate and correct sign and is rounded
  # calculate_tax doesn't (need to) know anything about exchangerate

  my ($self,$amount,$taxrate,$taxincluded,$roundplaces) = @_;

  $roundplaces //= 2;
  $taxincluded //= 0;

  my $tax;

  if ($taxincluded) {
    # calculate tax (unrounded), subtract from amount, round amount and round tax
    $tax       = $amount - ($amount / ($taxrate + 1)); # equivalent to: taxrate * amount / (taxrate + 1)
    $amount    = $self->round_amount($amount - $tax, $roundplaces);
    $tax       = $self->round_amount($tax, $roundplaces);
  } else {
    $tax       = $amount * $taxrate;
    $tax       = $self->round_amount($tax, $roundplaces);
  }

  $tax = 0 unless $tax;

  return ($amount,$tax);
};

1;

__END__

=head1 NAME

SL::Form.pm - main data object.

=head1 SYNOPSIS

This is the main data object of kivitendo.
Unfortunately it also acts as a god object for certain data retrieval procedures used in the entry points.
Points of interest for a beginner are:

 - $form->error            - renders a generic error in html. accepts an error message
 - $form->get_standard_dbh - returns a database connection for the

=head1 SPECIAL FUNCTIONS

=head2 C<redirect_header> $url

Generates a HTTP redirection header for the new C<$url>. Constructs an
absolute URL including scheme, host name and port. If C<$url> is a
relative URL then it is considered relative to kivitendo base URL.

This function C<die>s if headers have already been created with
C<$::form-E<gt>header>.

Examples:

  print $::form->redirect_header('oe.pl?action=edit&id=1234');
  print $::form->redirect_header('http://www.lx-office.org/');

=head2 C<header>

Generates a general purpose http/html header and includes most of the scripts
and stylesheets needed. Stylesheets can be added with L<use_stylesheet>.

Only one header will be generated. If the method was already called in this
request it will not output anything and return undef. Also if no
HTTP_USER_AGENT is found, no header is generated.

Although header does not accept parameters itself, it will honor special
hashkeys of its Form instance:

=over 4

=item refresh_time

=item refresh_url

If one of these is set, a http-equiv refresh is generated. Missing parameters
default to 3 seconds and the refering url.

=item stylesheet

Either a scalar or an array ref. Will be inlined into the header. Add
stylesheets with the L<use_stylesheet> function.

=item landscape

If true, a css snippet will be generated that sets the page in landscape mode.

=item favicon

Used to override the default favicon.

=item title

A html page title will be generated from this

=item mtime_ischanged

Tries to avoid concurrent write operations to records by checking the database mtime with a fetched one.

Can be used / called with any table, that has itime and mtime attributes.
Valid C<table> names are: oe, ar, ap, delivery_orders, parts.
Can be called wit C<option> mail to generate a different error message.

Returns undef if no save operation has been done yet ($self->{id} not present).
Returns undef if no concurrent write process is detected otherwise a error message.

=back

=over 4

=item C<check_exchangerate>  $myconfig, $currency, $transdate, $fld, $id, $record_table

Needs a local myconfig, a currency string, a date of the transaction, a field (fld) which
has to be either the buy or sell exchangerate and checks if there is already a buy or
sell exchangerate for this date.
Returns 0 or (NULL) if no entry is found or the already stored exchangerate.
If the optional parameter id and record_table is passed, the method tries to look up
a custom exchangerate for a record with id. record_table can either be ar, ap or bank_transactions.
If none is found the default (daily) entry will be checked.
The method is very strict about the parameters and tries to fail if anything does
not look like the expected type.

=item C<update_exchangerate> $dbh, $curr, $transdate, $buy, $sell, $id, $record_table

Needs a dbh connection, a currency string, a date of the transaction, buy (0|1), sell (0|1) which
determines if either the buy or sell or both exchangerates should be updated and updates
the exchangerate for this currency for this date.
If the optional parameter id and record_table is passed, the method saves
a custom exchangerate for a record with id. record_table can either be ar, ap or bank_transactions.

The method is very strict about the parameters and tries to fail if anything does not look
like the expected type.




=back

=cut
