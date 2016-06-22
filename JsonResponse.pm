package JsonResponse;

use strict ;
use warnings;

use HTTP::Tiny;
use JSON;
use Carp;
$Carp::Verbose = 1; # Stack trace when carp/croak

# On success: return the json content in an array ref of hash ref
# On failure: die
# example url: "http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getRunsByStudy/SRP033494";
sub get_Json_response {
  my ($url, $num_attempts) = @_;
  $num_attempts //= 3;
  
  my $http = HTTP::Tiny->new();

  # Try several ($num_attempt) times
  my $response;
  ATTEMPT: for my $attempt (1..$num_attempts) {
    $response = $http->get($url);

    unless ($response->{success} and $response->{success} == 1) {
      sleep 5;
      next ATTEMPT;
    }
    
    # Success: decode json and return it
    my $json = $response->{content};
    my $json_aref = decode_json($json);
    return ($json_aref);      
  }

  # All attempts failed: die
  my ($status, $reason) = ($response->{status}, $response->{reason});
  croak sprintf(
    "Failed to load url '%s'! Status code: '%s'. Reason: '%s'",
    $url,
    $response->{status},
    $response->{reason}
  );
  # Note: if the response is successful I get status "200", reason "OK"
  
  return;
}

1;

