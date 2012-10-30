#!/usr/bin/perl
# @tag: background_jobs_3
# @description: Backgroundjob Cleanup einrichten
# @depends: emmvee_background_jobs_2
# @charset: utf-8

use strict;

use SL::BackgroundJob::BackgroundJobCleanup;

SL::BackgroundJob::BackgroundJobCleanup->create_job;

1;
