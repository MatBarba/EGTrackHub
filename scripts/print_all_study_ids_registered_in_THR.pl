#!/usr/bin/env perl
use strict ;
use warnings;

use EGTrackHubs::Registry;

my $registry_user_name = $ENV{'THR_USER'}; 
my $registry_pwd = $ENV{'THR_PWD'};

if (not $registry_user_name or not $registry_pwd) {
  die("You need to export both THR_USER and THR_PWD (TrackHub registry username and password)\n");
}

my $registry_obj = Registry->new($registry_user_name, $registry_pwd,"public"); # dosn't matter the visibility setting in this case

my %track_hub_names = %{$registry_obj->give_all_Registered_track_hub_names()};

foreach my $study_name (keys %track_hub_names){
  print $study_name."\n";
}
