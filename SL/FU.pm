# Follow-Ups

package FU;

use List::Util qw(first);

use SL::Common;
use SL::DBUtils;
use SL::DB;
use SL::DB::FollowUpCreatedForEmployee;
use SL::Mailer;
use SL::Notes;
use SL::Template;
use SL::Template::PlainText;

use strict;

sub save {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $is_new   = !$params{id};

  my $rc = SL::DB->client->with_transaction(\&_save, $self, %params);

  FU->send_email_notification(%params) if ($is_new);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save {
  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;
  my ($query, @values);

  if (!$params{id}) {
    ($params{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('follow_up_id')|);

    $query = qq|INSERT INTO follow_ups (created_by, note_id, follow_up_date, id)
                VALUES ((SELECT id FROM employee WHERE login = ?), ?, ?, ?)|;

    push @values, $::myconfig{login};

  } else {
    $query = qq|UPDATE follow_ups SET note_id = ?, follow_up_date = ? WHERE id = ?|;
  }

  $params{note_id} = Notes->save('id'           => $params{note_id},
                                 'trans_id'     => $params{id},
                                 'trans_module' => 'fu',
                                 'subject'      => $params{subject},
                                 'body'         => $params{body},
                                 'dbh'          => $dbh,);

  do_query($form, $dbh, $query, @values, conv_i($params{note_id}), $params{follow_up_date}, conv_i($params{id}));

  $params{done} = 1 if (!defined $params{done});
  if ($params{done}) {
    do_query($form, $dbh, qq|INSERT INTO follow_up_done (follow_up_id, employee_id) VALUES (?, (SELECT id FROM employee WHERE login = ?))|,
             conv_i($params{id}), $::myconfig{login});
  } else {
    do_query($form, $dbh, qq|DELETE FROM follow_up_done WHERE follow_up_id = ?|, conv_i($params{id}));
  }

  do_query($form, $dbh, qq|DELETE FROM follow_up_links WHERE follow_up_id = ?|, conv_i($params{id}));

  $query = qq|INSERT INTO follow_up_links (follow_up_id, trans_id, trans_type, trans_info) VALUES (?, ?, ?, ?)|;
  my $sth   = prepare_query($form, $dbh, $query);

  foreach my $link (@{ $params{LINKS} }) {
    do_statement($form, $sth, $query, conv_i($params{id}), conv_i($link->{trans_id}), $link->{trans_type}, $link->{trans_info});
  }

  $sth->finish();

  do_query($form, $dbh, qq|DELETE FROM follow_up_created_for_employees WHERE follow_up_id = ?|, conv_i($params{id}));

  $query = qq|INSERT INTO follow_up_created_for_employees (follow_up_id, employee_id) VALUES (?, ?)|;
  $sth   = prepare_query($form, $dbh, $query);

  foreach my $employee_id (@{ $params{created_for_employees} }) {
    do_statement($form, $sth, $query, conv_i($params{id}), $employee_id);
  }

  return 1;
}

sub finish {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, 'id');

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my ($done)   = selectrow_query($::form, SL::DB->client->dbh, qq|SELECT id FROM follow_up_done WHERE follow_up_id = ?|, conv_i($params{id}));
  if (!$done) {
    SL::DB->client->with_transaction(sub {
      do_query($form, SL::DB->client->dbh, qq|INSERT INTO follow_up_done (follow_up_id, employee_id) VALUES (?, (SELECT id FROM employee WHERE login = ?))|,
               conv_i($params{id}), $myconfig->{login});
      1;
    }) or do { die SL::DB->client->error };
  }

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, 'id');

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = SL::DB->client->dbh;

    my $id       = conv_i($params{id});

    do_query($form, $dbh, qq|DELETE FROM follow_up_links WHERE follow_up_id = ?|,                         $id);
    do_query($form, $dbh, qq|DELETE FROM follow_ups      WHERE id = ?|,                                   $id);
    do_query($form, $dbh, qq|DELETE FROM notes           WHERE (trans_id = ?) AND (trans_module = 'fu')|, $id);
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub retrieve {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, 'id');

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);
  my ($query, @values);

  my ($employee_id) = selectrow_query($form, $dbh, qq|SELECT id FROM employee WHERE login = ?|, $::myconfig{login});
  $query            = qq|SELECT fu.*, n.subject, n.body, n.created_by,
                         follow_up_done.follow_up_id AS done,
                         date_trunc('second', follow_up_done.done_at) AS done_at,
                         COALESCE(done_by.name, done_by.login) AS done_by_employee_name
                         FROM follow_ups fu
                         LEFT JOIN notes n ON (fu.note_id = n.id)
                         LEFT JOIN follow_up_created_for_employees ON (follow_up_created_for_employees.follow_up_id = fu.id)
                         LEFT JOIN follow_up_done ON (follow_up_done.follow_up_id = fu.id)
                         LEFT JOIN employee done_by ON (follow_up_done.employee_id = done_by.id)
                         WHERE (fu.id = ?)
                           AND (   (fu.created_by = ?) OR (follow_up_created_for_employees.employee_id = ?)
                                OR (fu.created_by IN (SELECT DISTINCT what FROM follow_up_access WHERE who = ?)))|;
  my $ref           = selectfirst_hashref_query($form, $dbh, $query, conv_i($params{id}), $employee_id, $employee_id, $employee_id);

  if (!$ref) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  $ref->{LINKS} = $self->retrieve_links(%{ $ref });

  $main::lxdebug->leave_sub();

  return $ref;
}

sub retrieve_links {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT ful.trans_id, ful.trans_type, ful.trans_info, fu.note_id
                    FROM follow_up_links ful
                    LEFT JOIN follow_ups fu ON (ful.follow_up_id = fu.id)
                    WHERE ful.follow_up_id = ?
                    ORDER BY ful.itime|;

  my $links    = selectall_hashref_query($form, $dbh, $query, conv_i($params{id}));

  foreach my $link_ref (@{ $links }) {
    my $link_details = FU->link_details(%{ $link_ref });
    map { $link_ref->{$_} = $link_details->{$_} } keys %{ $link_details} if ($link_details);
  }

  $main::lxdebug->leave_sub();

  return $links;
}

sub follow_ups {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);
  my ($query, $where, $where_user);

  my ($employee_id) = selectrow_query($form, $dbh, qq|SELECT id FROM employee WHERE login = ?|, $::myconfig{login});
  my @values        = ();
  my @values_user   = ();

  if ($params{trans_id}) {
    $where .= qq| AND fu.id IN (select follow_up_id from follow_up_links where trans_id = ?)|;
   # $where .= qq| AND (ful.follow_up_id = fu.id) AND (ful.trans_id = ?))|;
   # $where .= qq| AND EXISTS (SELECT * FROM follow_up_links ful
   #                           WHERE (ful.follow_up_id = fu.id) AND (ful.trans_id = ?))|;
    push @values, conv_i($params{trans_id});
  }

  if ($params{due_only}) {
    $where .= qq| AND (fu.follow_up_date <= current_date)|;
  }

  if ($params{done} ne $params{not_done}) {
    my $not  = $params{not_done} ? 'NOT' : '';
    $where  .= qq| AND $not EXISTS (SELECT id FROM follow_up_done WHERE follow_up_id = fu.id)|;
  }

  if ($params{not_id}) {
    $where .= qq| AND (fu.id <> ?)|;
    push @values, conv_i($params{not_id});
  }

  foreach my $item (qw(subject body)) {
    next unless ($params{$item});
    $where .= qq| AND (n.${item} ILIKE ?)|;
    push @values, like($params{$item});
  }

  if ($params{reference}) {
    $where .= qq| AND EXISTS (SELECT ful.follow_up_id
                              FROM follow_up_links ful
                              WHERE (ful.follow_up_id = fu.id)
                                AND (ful.trans_info ILIKE ?)
                              LIMIT 1)|;
    push @values, like($params{reference});
  }

  if ($params{follow_up_date_from}) {
    $where .= qq| AND (fu.follow_up_date >= ?)|;
    push @values, conv_date($params{follow_up_date_from});
  }
  if ($params{follow_up_date_to}) {
    $where .= qq| AND (fu.follow_up_date <= ?)|;
    push @values, conv_date($params{follow_up_date_to});
  }

  if ($params{itime_from}) {
    $where .= qq| AND (date_trunc('DAY', fu.itime) >= ?)|;
    push @values, conv_date($params{itime_from});
  }
  if ($params{itime_to}) {
    $where .= qq| AND (date_trunc('DAY', fu.itime) <= ?)|;
    push @values, conv_date($params{itime_to});
  }
  if ($params{created_for}) {
    $where .= qq| AND follow_up_created_for_employees.employee_id = ?|;
    push @values, conv_i($params{created_for});
  }

  if ($params{all_users} || $params{trans_id}) {  # trans_id only for documents?
    $where_user = qq|OR (fu.created_by IN (SELECT DISTINCT what FROM follow_up_access WHERE who = ?))|;
    push @values_user, $employee_id;
  }

  my $order_by = '';

  if ($form->{sort} ne 'title') {
    my %sort_columns = (
      'follow_up_date' => [ qw(fu.follow_up_date fu.id) ],
      'created_on'     => [ qw(created_on fu.id) ],
      'subject'        => [ qw(n.subject) ],
      );

    my $sortdir = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
    my $sortkey = $sort_columns{$form->{sort}} ? $form->{sort} : 'follow_up_date';
    $order_by   = 'ORDER BY ' . join(', ', map { "$_ $sortdir" } @{ $sort_columns{$sortkey} });
  }

  $query  = qq|SELECT DISTINCT fu.*, n.subject, n.body, n.created_by,
                 fu.follow_up_date <= current_date AS due,
                 fu.itime::DATE                    AS created_on,
                 COALESCE(eby.name,  eby.login)    AS created_by_name,
                 follow_up_done.follow_up_id       AS done
               FROM follow_ups fu
               LEFT JOIN notes    n    ON (fu.note_id          = n.id)
               LEFT JOIN employee eby  ON (n.created_by        = eby.id)
               LEFT JOIN follow_up_created_for_employees ON (follow_up_created_for_employees.follow_up_id = fu.id)
               LEFT JOIN follow_up_done ON (follow_up_done.follow_up_id = fu.id)
               WHERE ((fu.created_by = ?) OR (follow_up_created_for_employees.employee_id = ?)
                      $where_user)
                 $where
               $order_by|;

  my $follow_ups = selectall_hashref_query($form, $dbh, $query, $employee_id, $employee_id, @values_user, @values);

  if (!scalar @{ $follow_ups }) {
    $main::lxdebug->leave_sub();
    return $follow_ups;
  }

  foreach my $fu (@{ $follow_ups }) {
    $fu->{LINKS} = $self->retrieve_links(%{ $fu });

    my $fu_created_for_employees = SL::DB::Manager::FollowUpCreatedForEmployee->get_all(
      where       => [follow_up_id => $fu->{id}],
      with_obects => ['employee']);
    $fu->{created_for_user_name} = join "\n", map { $_->employee->safe_name } @{$fu_created_for_employees};
  }

  if ($form->{sort} eq 'title') {
    my $dir_factor = !defined $form->{sortdir} ? 1 : $form->{sortdir} ? 1 : -1;
    $follow_ups    = [ map  { $_->[1] }
                       sort { ($a->[0] cmp $b->[0]) * $dir_factor }
                       map  { my $fu = $follow_ups->[$_]; [ @{ $fu->{LINKS} } ? lc($fu->{LINKS}->[0]->{title}) : '', $fu ] }
                       (0 .. scalar(@{ $follow_ups }) - 1) ];
  }

  $main::lxdebug->leave_sub();

  return $follow_ups;
}

sub link_details {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(trans_id trans_type));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $locale   = $main::locale;

  my $q_id     = $form->quote($params{trans_id});
  my $link;

  if ($params{trans_type} eq 'customer') {
    $link = {
      'url'   => 'controller.pl?action=CustomerVendor/edit&db=customer&id=' . $form->quote($params{trans_id}) . '&note_id=' . $form->quote($params{note_id}),
      'title' => $locale->text('Customer') . " '$params{trans_info}'",
    };

  } elsif ($params{trans_type} eq 'vendor') {
    $link = {
      'url'   => 'controller.pl?action=CustomerVendor/edit&db=vendor&id=' . $params{trans_id} . '&note_id=' . $form->quote($params{note_id}),
      'title' => $locale->text('Vendor') . " '$params{trans_info}'",
    };

  } elsif ($params{trans_type} eq 'sales_quotation') {
    my $script = 'oe.pl';
    my $action = 'edit';
    if ($::instance_conf->get_feature_experimental_order) {
      $script = 'controller.pl';
      $action = 'Order/edit';
    }
    $link = {
      'url'   => $script . '?action=' . $action . '&type=sales_quotation&id=' . $params{trans_id},
      'title' => $locale->text('Sales quotation') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'sales_delivery_order') {

    $link = {
      'url'   => 'controller.pl?action=DeliveryOrder/edit&id=' . $params{trans_id} . '&edit_note_id=' . $form->quote($params{note_id}),
      'title' => $locale->text('Sales delivery order') .' '. $params{trans_info},
    };

  } elsif ($params{trans_type} eq 'purchase_delivery_order') {

    $link = {
      'url'   => 'controller.pl?action=DeliveryOrder/edit&id=' . $params{trans_id} . '&edit_note_id=' . $form->quote($params{note_id}),
      'title' => $locale->text('Purchase delivery order') .' '. $params{trans_info},
    };

  } elsif ($params{trans_type} eq 'sales_order') {
    my $script = 'oe.pl';
    my $action = 'edit';
    if ($::instance_conf->get_feature_experimental_order) {
      $script = 'controller.pl';
      $action = 'Order/edit';
    }
    $link = {
      'url'   => $script . '?action=' . $action . '&type=sales_order&id=' . $params{trans_id},
      'title' => $locale->text('Sales Order') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'sales_invoice') {
    $link = {
      'url'   => 'is.pl?action=edit&type=invoice&id=' . $params{trans_id},
      'title' => $locale->text('Sales Invoice') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'purchase_invoice') {
    $link = {
      'url'   => 'ir.pl?action=edit&type=purchase_invoice&id=' . $params{trans_id},
      'title' => $locale->text('Purchase Invoice') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'credit_note') {
    $link = {
      'url'   => 'is.pl?action=edit&type=credit_note&id=' . $params{trans_id},
      'title' => $locale->text('Credit Note') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'dunning') {
    $link = {
      'url'   => 'dn.pl?action=print_dunning&format=pdf&media=screen&dunning_id=' . $params{trans_id},
      'title' => $locale->text('Dunning') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'request_quotation') {
    my $script = 'oe.pl';
    my $action = 'edit';
    if ($::instance_conf->get_feature_experimental_order) {
      $script = 'controller.pl';
      $action = 'Order/edit';
    }
    $link = {
      'url'   => $script . '?action=' . $action . '&type=request_quotation&id=' . $params{trans_id},
      'title' => $locale->text('Request quotation') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'purchase_order') {
    my $script = 'oe.pl';
    my $action = 'edit';
    if ($::instance_conf->get_feature_experimental_order) {
      $script = 'controller.pl';
      $action = 'Order/edit';
    }
    $link = {
      'url'   => $script . '?action=' . $action . '&type=purchase_order&id=' . $params{trans_id},
      'title' => $locale->text('Purchase Order') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'vendor_invoice') {
    $link = {
      'url'   => 'ir.pl?action=edit&type=invoice&id=' . $params{trans_id},
      'title' => $locale->text('Vendor Invoice') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'ar_transaction') {
    $link = {
      'url'   => 'ar.pl?action=edit&id=' . $params{trans_id},
      'title' => $locale->text('AR Transaction') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'ap_transaction') {
    $link = {
      'url'   => 'ap.pl?action=edit&id=' . $params{trans_id},
      'title' => $locale->text('AP Transaction') . " $params{trans_info}",
    };

  } elsif ($params{trans_type} eq 'gl_transaction') {
    $link = {
      'url'   => 'gl.pl?action=edit&id=' . $params{trans_id},
      'title' => $locale->text('GL Transaction') . " $params{trans_info}",
    };

  }

  $main::lxdebug->leave_sub();

  return $link || { };
}

sub save_access_rights {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, 'access');

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = SL::DB->client->dbh;

    my ($id)     = selectrow_query($form, $dbh, qq|SELECT id FROM employee WHERE login = ?|, $::myconfig{login});

    do_query($form, $dbh, qq|DELETE FROM follow_up_access WHERE what = ?|, $id);

    my $query    = qq|INSERT INTO follow_up_access (who, what) VALUES (?, ?)|;
    my $sth      = prepare_query($form, $dbh, $query);

    while (my ($who, $access_allowed) = each %{ $params{access} }) {
      next unless ($access_allowed);

      do_statement($form, $sth, $query, conv_i($who), $id);
    }

    $sth->finish();
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub retrieve_access_rights {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $sth      = prepare_execute_query($form, $dbh, qq|SELECT who FROM follow_up_access WHERE what = (SELECT id FROM employee WHERE login = ?)|, $::myconfig{login});
  my $access   = {};

  while (my $ref = $sth->fetchrow_hashref()) {
    $access->{$ref->{who}} = 1;
  }

  $sth->finish();

  $main::lxdebug->leave_sub();

  return $access;
}

sub send_email_notification {
  $main::lxdebug->enter_sub();
  my ($self, %params) = @_;

  my $notify_cfg = $main::lx_office_conf{follow_up_notify};
  if (!$notify_cfg
   || !$notify_cfg->{email_subject}
   || !$notify_cfg->{email_from}
   || !$notify_cfg->{email_template}) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $employee = SL::DB::Manager::Employee->current;

  my @for_employees_ids = @{$params{created_for_employees}};

  my $placeholders = join ', ', map {'?'} @for_employees_ids;
  my $query = <<SQL;
  SELECT login
  FROM employee
  WHERE id in ($placeholders)
SQL

  my $dbh = $employee->dbh;
  my $hash_key = 'login';
  my $hashref = $dbh->selectall_hashref(
    $query, $hash_key, undef, @for_employees_ids
  );
  my @logins = keys %$hashref;

  foreach my $login (@logins) {
    my %recipient  = $main::auth->read_user(
      login => $login,
    );

    if (!$recipient{follow_up_notify_by_email} || !$recipient{email}) {
      next;
    }

    my %template_params = (
      follow_up_subject => $params{subject},
      follow_up_body    => $params{body},
      follow_up_date    => $params{follow_up_date},
      creator_name      => $employee->name  || $::form->{login},
      recipient_name    => $recipient{name} || $recipient{login},
    );

    my $template = Template->new({ENCODING    => 'utf8'});

    my $body_file = $notify_cfg->{email_template};
    my $content_type   = $body_file =~ m/.html$/ ? 'text/html' : 'text/plain';

    my $message;
    $template->process($body_file, \%template_params, \$message)
    || die $template->error;

    my $param_form = Form->new();
    $param_form->{$_} = $template_params{$_} for keys %template_params;

    my $mail              = Mailer->new();
    $mail->{from}         = $notify_cfg->{email_from};
    $mail->{to}           = $recipient{email};
    $mail->{subject}      = SL::Template::PlainText->new(form => $param_form)
                              ->substitute_vars($notify_cfg->{email_subject});
    $mail->{content_type} = $content_type;
    $mail->{message}      = $message;
    $mail->{charset}      = 'UTF-8';

    $mail->send();
  }

  $main::lxdebug->leave_sub();
}

1;
