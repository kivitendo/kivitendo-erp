package SL::Controller::Helper::ReportGenerator::ControlRow::ALL;

use strict;

use SL::Controller::Helper::ReportGenerator::ControlRow::Data;
use SL::Controller::Helper::ReportGenerator::ControlRow::Separator;
use SL::Controller::Helper::ReportGenerator::ControlRow::SimpleData;

our %type_to_class = (
  data        => 'SL::Controller::Helper::ReportGenerator::ControlRow::Data',
  separator   => 'SL::Controller::Helper::ReportGenerator::ControlRow::Separator',
  simple_data => 'SL::Controller::Helper::ReportGenerator::ControlRow::SimpleData',
);

1;
