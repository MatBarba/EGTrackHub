
use Test::More;
use Test::JSON
  ; # had to install also from cpan the module JSON::Any which is used in Test::Json
use HTTP::Tiny;
use Test::HTTP::Response;
use Capture::Tiny ':all';

# -----
# checks if the module can load
# -----

#test1
use_ok(JsonResponse);    # it checks if it can use the module correctly

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
my $json_response_aref = JsonResponse::get_Json_response($url);
isa_ok( $json_response_aref, "ARRAY", "JSON response" );

use Data::Dumper;
print STDERR Dumper $json_response_aref;

#test4
foreach my $stanza_href (@$json_response_aref) {
    for my $key (qw{ORGANISM STATUS CRAM_LOCATION}) {
      ok( defined $stanza_href->{$key}, "JSON stanza has key $key");
    }
    last;
}

#test5
my $wrong_url = "http://plantain:3000/json/70/getLibrariesByStudyId/SRP033494";
my ( $stdout, $stderr, $wrong_url_response ) = capture {
    JsonResponse::get_Json_response($wrong_url);
};

ok(
    $stderr =~ /ERROR in/,
    'HTTP response with a wrong URL returns an expected error'
);

# test6
is( $wrong_url_response, 0, "REST call with wrong URL returns 0" );

done_testing();

