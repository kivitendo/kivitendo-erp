package SL::Layout::ActionBar::Submit;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use JSON;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(text submit) ],
);

sub render {
  $_[0]->p->html_tag('div', $_[0]->text,
    id    => $_[0]->id,
    class => 'layout-actionbar-action layout-actionbar-submit',
  );
}

sub script {
  # store submit and form and stuff in data attribute
  sprintf q|$('#%s').data('action', %s);|, $_[0]->id, JSON::to_json({
    submit => $_[0]->submit,
  });
}

1;
