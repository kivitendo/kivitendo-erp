#!/usr/bin/perl
# @tag: emmvee_background_jobs_2
# @description: Hintergrundjobs einrichten
# @depends: emmvee_background_jobs
# @charset: utf-8

use strict;

use SL::BackgroundJob::CleanBackgroundJobHistory;

SL::BackgroundJob::CleanBackgroundJobHistory->create_job;

1;
