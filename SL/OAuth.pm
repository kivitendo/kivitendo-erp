package SL::OAuth;

use strict;


my %providers = (
  microsoft      => 'SL::Controller::OAuth::Microsoft',
  atlassian_jira => 'SL::Controller::OAuth::Atlassian',
  google_cal     => 'SL::Controller::OAuth::GoogleCal',
);


sub providers {

  \%providers;
}
