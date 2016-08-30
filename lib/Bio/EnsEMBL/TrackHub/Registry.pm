package Bio::EnsEMBL::TrackHub::Registry;

use strict;
use warnings;
use Carp;
use List::MoreUtils qw(uniq);
use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);
my $logger = get_logger();

use JSON;
use HTTP::Request::Common qw/GET DELETE POST/;
use LWP::UserAgent;

my $SERVER       = 'https://beta.trackhubregistry.org';
my $LOGIN_API    = $SERVER . '/api/login';
my $LOGOUT_API   = $SERVER . '/api/logout';
my $TRACKHUB_API = $SERVER . '/api/trackhub';

$| = 1;

# Attributes
has [
  qw(
    user
    password
    )
  ] => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  );

has auth_token => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '_get_token',
);

has agent => (
  is      => 'ro',
  isa     => 'LWP::UserAgent',
  lazy    => 1,
  builder => '_build_agent',
);

has is_public => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

sub _build_agent {
  my $self = shift;
  return LWP::UserAgent->new;
}

# Subs
sub _get_token {
  my $self = shift;
  my $user = $self->user;
  my $pass = $self->password;

  if (  not defined $SERVER
    and not defined $user
    and not defined $pass )
  {
    croak
      "Some required parameters are missing when trying to login in the TrackHub Registry";
  }

  # Request a token
  my $request = GET($LOGIN_API);
  $request->headers->authorization_basic( $user, $pass );
  my $response = $self->agent->request($request);

  # Check answer
  if ( not $response->is_success ) {
    croak "Unable to login to Registry: " . $response->status_line;
  }
  my $auth_token = from_json( $response->content )->{auth_token};

  # Check token
  if ( not defined $auth_token ) {
    croak
      "Undefined authentication token when trying to login in the Track Hub Registry";
  }

  return $auth_token;
}

sub DEMOLISH {
  my $self = shift;

  if (  defined $self->user
    and defined $self->password
    and defined $self->auth_token )
  {
    my $request = GET($LOGOUT_API);
    $request->headers->header(
      user       => $self->user,
      auth_token => $self->auth_token
    );
    my $response = $self->agent->request($request);
    if ( not $response->is_success ) {
      croak "Unable to logout correctly: " . $response->status_line;
    }
  }
}

sub _request {
  my $self = shift;
  my ( $url, $action, $ok_code ) = @_;

  my $num_repeats = 1;
  my $wait_time   = 5;

  my $request;
  if ( $action eq 'GET' ) {
    $request = GET($url);
  }
  elsif ( $action eq 'DELETE' ) {
    $request = DELETE($url);
  }
  elsif ( $action eq 'POST' ) {
    $request = POST($url);
  }

  $request->headers->header(
    user       => $self->user,
    auth_token => $self->auth_token,
  );

  # Repeat the request
  my $response;
  for my $rep ( 1 .. $num_repeats ) {
    $response         = $self->agent->request($request);
    my $response_code = $response->code;
    if ( $response->is_success ) {
      if ( $ok_code and $response_code == $ok_code ) {
        return from_json( $response->content );
      }
    }
    sleep $wait_time;
  }
  croak "Couldn't get a successful response after $num_repeats retries. Latest response: " . $response->status_line;
}

sub register_track_hubs {
  my $self = shift;
  my ($hubs) = @_;

  for my $hub (@$hubs) {
    print STDERR sprintf("Registering track hub %s with url %s (%s)\n", $hub->id, $hub->url, $self->is_public ? 'public' : 'hidden');
    $self->new_register_track_hub(
      id           => $hub->id,
      url          => $hub->url,
      assembly_map => $hub->assembly_map
    );
  }
}

sub new_register_track_hub {
  my $self = shift;
  my %pars = @_;

  $self->register_track_hub( $pars{id}, $pars{url}, $pars{assembly_map} );
}

sub register_track_hub {
  my $self = shift;

  my ( $track_hub_id, $hub_url, $assembly_mapping, ) = @_;

  croak "No track hub id provided" if not defined $track_hub_id;
  croak "No hub.txt url provided"  if not defined $hub_url;
  croak "No assembly mapping (name,accession) provided"
    if not defined $assembly_mapping;

  my %assemblies = %$assembly_mapping;

  my $trackhub_content = {
    url  => $hub_url,
    type => 'transcriptomics',
  };
  $trackhub_content->{assemblies} = \%assemblies if %assemblies;
  $trackhub_content->{public}     = 0            if not $self->is_public;

  my $request = POST(
    $TRACKHUB_API,
    'Content-type' => 'application/json',
    'Content'      => to_json($trackhub_content)
  );
  $request->headers->header(
    user       => $self->user,
    auth_token => $self->auth_token
  );

  my $num_repeat = 1;
  my $response;
  for my $repeat ( 1 .. $num_repeat ) {
    $response = $self->agent->request($request);
    if ( $response->is_success and $response->code == 201 ) {
      return $track_hub_id;
    }
    else {
      sleep 5;
    }
  }
  croak "Couldn't register the track hub $track_hub_id: "
    . $response->status_line . "\n"
    . $response->as_string;
}

sub delete_all_track_hubs {
  my $self = shift;
  
  my $track_hub_ids = $self->get_all_registered;
  $self->delete_track_hubs(@$track_hub_ids);
}

sub delete_track_hubs {
  my $self = shift;
  my @track_hub_ids = @_;

  if (not @track_hub_ids) {
    $logger->info("List of track hubs to delete is empty");
    return;
  }

  my $auth_token = $self->auth_token;

  my $del_count = 0;

  foreach my $track_hub_id ( sort uniq @track_hub_ids ) {
    $logger->info( "$del_count\tDeleting trackhub " . $track_hub_id );
    my $url     = "$TRACKHUB_API/$track_hub_id";
    my $request = DELETE($url);
    $request->headers->header(
      user       => $self->user,
      auth_token => $auth_token
    );
    my $response      = $self->agent->request($request);
    my $response_code = $response->code;

    if ( $response->is_success and $response->code == 200 ) {
      $del_count++;
    }
    else {
      croak "Couldn't delete the track hub $track_hub_id: "
        . $response->status_line . "\n"
        . $response->as_string;
    }
  }
  return $del_count;
}

sub get_all_registered {
  my $self = shift;
  
  my $trackhubs = $self->_request(
    $TRACKHUB_API,
    'GET',
    200
  );
  
  my @ids = map { $_->{name} } @$trackhubs;
  return \@ids;
}

sub get_Registry_hub_last_update { # gives the last update date(unix time) of the registration of the track hub

  my $self = shift;

  my $name = shift;                # track hub name, ie study_id

  defined $name
    or print
    "Track hub name parameter required to get the track hub's last update date in the Track Hub Registry\n"
    and return 0;

  my $registry_user_name = $self->user;

  my $auth_token = $self->auth_token;

  my $request = GET("$SERVER/api/trackhub/$name");
  $request->headers->header( user       => $registry_user_name );
  $request->headers->header( auth_token => $auth_token );
  my $response = $self->agent->request($request);
  my $hub;

  if ( $response->is_success ) {
    $hub = from_json( $response->content );
  }
  else {

    print
      "\tCouldn't get Registered track hub $name with the first attempt when calling method get_Registry_hub_last_update in script "
      . __FILE__ . "\n";
    my $flag_success = 0;

    for ( my $i = 1 ; $i <= 10 ; $i++ ) {

      print "\t" . $i . ") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $self->agent->request($request);
      if ( $response->is_success ) {
        $hub          = from_json( $response->content );
        $flag_success = 1;
        last;
      }
    }

    die
      "Couldn't get track hub $name in the Registry when calling method get_Registry_hub_last_update in script: "
      . __FILE__
      . " line "
      . __LINE__
      . " I am getting code "
      . $response->code . "\n"
      unless $flag_success == 1;
  }

  die
    "Couldn't find hub $name in the Registry to get the last update date when calling method get_Registry_hub_last_update in script: "
    . __FILE__
    . " line "
    . __LINE__ . "\n"
    unless $hub;

  my $last_update = -1;

  foreach my $trackdb ( @{ $hub->{trackdbs} } ) {

    $request = GET( $trackdb->{uri} );
    $request->headers->header( user       => $registry_user_name );
    $request->headers->header( auth_token => $auth_token );
    $response = $self->agent->request($request);
    my $doc;
    if ( $response->is_success ) {
      $doc = from_json( $response->content );
    }
    else {
      die "\tCouldn't get trackdb at", $trackdb->{uri}
        . " from study $name in the Registry when trying to get the last update date \n";
    }

    if ( exists $doc->{updated} ) {
      $last_update = $doc->{updated}
        if $last_update < $doc->{updated};
    }
    else {
      exists $doc->{created}
        or die
        "Trackdb does not have creation date in the Registry when trying to get the last update date of study $name\n";
      $last_update = $doc->{created}
        if $last_update < $doc->{created};
    }
  }

  die "Couldn't get date as expected: $last_update\n"
    unless $last_update =~ /^[1-9]\d+?$/;

  return $last_update;
}

sub give_all_bioreps_of_study_from_Registry {

  my $self = shift;

  my $name = shift;    # track hub name, ie study_id

  defined $name
    or print
    "Track hub name parameter required to get the track hub's bioreps from the Track Hub Registry\n"
    and return 0;

  my $registry_user_name = $self->user;

  my $auth_token = $self->auth_token;

  my $request = GET("$SERVER/api/trackhub/$name");
  $request->headers->header( user       => $registry_user_name );
  $request->headers->header( auth_token => $auth_token );
  my $response = $self->agent->request($request);
  my $hub;

  if ( $response->is_success ) {

    $hub = from_json( $response->content );

  }
  else {

    print
      "\tCouldn't get Registered track hub $name with the first attempt when calling method give_all_runs_of_study_from_Registry in script "
      . __FILE__
      . " reason "
      . $response->code . " , "
      . $response->content . "\n";
    my $flag_success = 0;

    for ( my $i = 1 ; $i <= 10 ; $i++ ) {

      print "\t" . $i . ") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $self->agent->request($request);
      if ( $response->is_success ) {
        $hub          = from_json( $response->content );
        $flag_success = 1;
        last;
      }
    }

    die
      "Couldn't get the track hub $name in the Registry when calling method give_all_runs_of_study_from_Registry in script: "
      . __FILE__
      . " line "
      . __LINE__ . "\n"
      unless $flag_success == 1;
  }

  die
    "Couldn't find hub $name in the Registry to get its runs when calling method give_all_runs_of_study_from_Registry in script: "
    . __FILE__
    . " line "
    . __LINE__ . "\n"
    unless $hub;

  my %runs;

  foreach my $trackdb ( @{ $hub->{trackdbs} } ) {

    $request = GET( $trackdb->{uri} );
    $request->headers->header( user       => $registry_user_name );
    $request->headers->header( auth_token => $auth_token );
    $response = $self->agent->request($request);
    my $doc;

    if ( $response->is_success ) {

      $doc = from_json( $response->content );

      foreach my $sample ( keys %{ $doc->{configuration} } ) {
        map { $runs{$_}++ }
          keys %{ $doc->{configuration}{$sample}{members} };
      }
    }
    else {
      die "Couldn't get trackdb at ", $trackdb->{uri},
        " from study $name in the Registry when trying to get all its runs, reason: "
        . $response->code . " , "
        . $response->content . "\n";
    }
  }

  return \%runs;

}

sub hide_track_hubs {
  my $self = shift;
  my ($hubs) = @_;
  
  $self->is_public(0);
  $self->register_track_hubs($hubs);
}


sub show_track_hubs {
  my $self = shift;
  my ($hubs) = @_;
  
  $self->is_public(1);
  $self->register_track_hubs($hubs);
}

1;

