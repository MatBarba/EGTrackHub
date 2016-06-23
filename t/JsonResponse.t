#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::JSON;
use Test::Exception;
use HTTP::Tiny;
use Test::HTTP::Response;
use Try::Tiny;

# -----
# checks if the module can load
# -----

#test1
use_ok('EGTrackHubs::JsonResponse');    # it checks if it can use the module correctly

# -----
# test get_Json_response method
# -----

#test2
my $http = HTTP::Tiny->new();
my $url  = "http://plantain:3000/json/70/getRunsByStudy/SRP068911";
my $response = $http->get($url);
my $json = $response->{content};
is_valid_json( $json, 'Json from the e!genomes plant call is well formed' );

#test3
my $json_response_aref = EGTrackHubs::JsonResponse::get_Json_response($url);
isa_ok( $json_response_aref, "ARRAY", "JSON response" );

#test4
foreach my $stanza_href (@$json_response_aref) {
    for my $key (qw{ORGANISM STATUS CRAM_LOCATION}) {
      ok( defined $stanza_href->{$key}, "JSON stanza has key $key");
    }
    last;
}

#test5
my $wrong_url = "http://plantain:3000/json/70/getLibrariesByStudyId/SRP033494";
dies_ok {
  # 1 attempt for wrong url
  $json = EGTrackHubs::JsonResponse::get_Json_response($wrong_url, 1);
} "Wrong url: die";

done_testing();

