#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

#use Test::More skip_all => "TODO";
use Test::More qw(no_plan);
use Test::Exception;

use Capture::Tiny ':all';
use Time::Piece;
use EGTH::AEStudy;

# -----
# checks if the module can load
# -----
use_ok('EGTH::Registry');

# -----
# test constructor
# -----
my $user = $ENV{'THR_USER'};
my $pass = $ENV{'THR_PASS'};

SKIP: {
  skip
    "credentials needed to test the registry API (define THR_USER and THR_PASS in the environment)"
    unless $user and $pass;

  # First, test the login
  dies_ok {
    my $registry = EGTH::Registry->new;
  }
  "Login without credentials fails";

  # Wrong credentials
  dies_ok {
    my $registry = EGTH::Registry->new(
      user => "00000000000000000",
      pass => "password"
    );
  }
  "Login with wrong credentials fails";

  # Actual credentials
  ok(
    my $registry = EGTH::Registry->new(
      user     => $user,
      password => $pass
    ),
    "Login with right credentials"
  );

  isa_ok(
    $registry,
    'EGTH::Registry',
    'The object constructed is of my class type'
  );

  dies_ok {
    EGTH::Registry->new("blabla");
  }
  'Wrong object construction dies';

  ok( $registry->is_public == 0,    "The registry is not public by default" );
  ok( $registry->is_public(1) == 1, "Set the registry to public mode" );
  ok( $registry->is_public(0) == 0, "Set the registry back to private mode" );

  # Register 1 trackhub
  dies_ok {
    $registry->register_track_hub(
      "trackhub_id",
      "https://wrong.address/hub.txt"
    );
  }
  "Can't register a trackhub with wrong hub.txt url";

  my $th_id = 'RNAseq_group_211';
  my $hub_url =
    'http://www.ebi.ac.uk/~mbarba/rnaseq/hubs/anopheles_minimus/RNAseq_group_211/hub.txt';
  my %assemblies = (

    #'Oryza_brachyantha.v1.4b' => 'GCA_000231095.2'
    'AminM1' => 'GCA_000349025.1',
  );
  my $assemblies_list =
    join( ',', ( map { "$_,$assemblies{$_}" } keys %assemblies ) );

  ok(
    $registry->register_track_hub(
      $th_id,
      $hub_url,
      $assemblies_list
    ),
    "Can register a trackhub with correct data"
  );

  ok(
    $registry->delete_track_hub($th_id),
    "Can delete a trackhub"
  );

}

__END__
# -----
# test register_track_hub method
# -----

#test4
my $return_of_method = $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

ok($return_of_method=~/Registered/,"TH registered successfully");

#test5
my ($stdout1, $stderr1,$return_of_method_wrong_assembly_id) =capture { 
  $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_0002310");
};

ok($return_of_method_wrong_assembly_id=~/Didn't manage to register the track hub/,"TH not registered successfully as expected, given wrong assembly id");

#test6
# the first parameter, the hub id, is not used by the THR, so if it's wrong it will not affect anything, just the log file.
my ($stdout2, $stderr2, $return_of_method_wrong_url )= capture { 
  $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.tx","Oryza_brachyantha.v1.4b,GCA_000231095.2");
};

ok($return_of_method_wrong_url=~/Didn't manage to register the track hub/,"TH not registered successfully as expected, given wrong hub.txt URL");

#test7
my ($stdout3, $stderr3, $return_of_method_wrong_params )=  capture {
   $registry_obj->register_track_hub("ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_0002310");
};

ok($return_of_method_wrong_params==0,"TH not registered successfully as expected, given wrong number of parameters");


# -----
# test delete_track_hub method
# -----

#test8
my ($stdout4, $stderr4 ,$return_of_method_delete_no_param) = capture {
  $registry_obj->delete_track_hub();
};
 
ok($return_of_method_delete_no_param==0,"TH not deleted successfully as expected, given no parameter");

#test9
$registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

 my ($stdout5, $stderr5, $exit) = capture {
   $registry_obj->delete_track_hub("SRP045759");
 };

ok($stdout5=~/Done/,"Successful deletion of track hub");

# -----
# test give_all_Registered_track_hub_names method
# -----

# I am regstering 1 track hub first
$registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

 my ($stdout6, $stderr6, $hash_ref) = capture {
   $registry_obj->give_all_Registered_track_hub_names();
 };


#test12
ok($hash_ref->{"SRP045759"},"Successfully returns the name of the 1 track hub");

# -----
# test get_Registry_hub_last_update method
# -----

#test13
my ($stdout7, $stderr7, $exit7) = capture {
   $registry_obj->get_Registry_hub_last_update();
};

ok($exit7==0,"Successfully exited the method since no parameter was given (track hub name)");


#test14

my ($stdout8, $stderr8, $method_date) = capture {
   $registry_obj->get_Registry_hub_last_update("SRP045759");
};

my $method_full_date_readable = localtime($method_date)->strftime('%F %T');  # this form: 2016-04-19 14:09:22

my @words = split (/\s/ , $method_full_date_readable);
my $method_date_readable = $words[0];

my $current_time_unix = time();
my $current_full_date_readable = localtime($current_time_unix)->strftime('%F %T');  # this form: 2016-04-19 14:09:22

my @words2 = split (/\s/ ,$current_full_date_readable);
my $current_date_readable = $words2[0];

ok($method_date_readable eq $current_date_readable,"Successfully given the most current last update date of all track hubs in the THR, which is $method_date_readable");

# -----
# test give_all_bioreps_of_study_from_Registry method
# -----

#test15

my ($stdout9, $stderr9, $exit9) = capture {
   $registry_obj->give_all_bioreps_of_study_from_Registry();
};

ok($exit9==0,"Successfully exited the method since no parameter was given (track hub name)");


#test16
my ($stdout10, $stderr10, $bioreps_hash_ref) = capture {
   $registry_obj->give_all_bioreps_of_study_from_Registry("SRP045759");
};

is(ref($bioreps_hash_ref), 'HASH', 'The method returns a hash ref');

#test17
my $plant_names_AE_response_href = EGTH::ArrayExpress::get_plant_names_AE_API();
my $study_obj = EGTH::AEStudy->new("SRP045759",$plant_names_AE_response_href);

my $biorep_ids_from_AE_href= $study_obj->get_biorep_ids();

is_deeply($bioreps_hash_ref, $biorep_ids_from_AE_href, 'got the expected bioreps ids from the specific study id');

# -----
# test registry_get_request method
# -----

#test18
my ($stdout10, $stderr10, $exit10) = capture {
   $registry_obj->registry_get_request();
};

ok($exit10==0,"Successfully exited the method since no parameter was given");

#test19
my ($stdout11, $stderr11, $exit11) = capture {
   $registry_obj->registry_get_request("testing");
};

ok($exit11==0,"Successfully exited the method since there were some missing parameters");
