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


###############################################################################
# ATTRIBUTES
# Authentification
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

# General setting to set registered hubs as public or hidden
has is_public => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

###############################################################################
# ATTRIBUTES BUILDERS

# Purpose   : Initialize a user agent when needed
# Parameters: none
sub _build_agent {
  my $self = shift;
  return LWP::UserAgent->new;
}

# Purpose   : Authenticate and get a token from the Registry
# Parameters: none
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

###############################################################################
# AUTOMATIC INSTANCE CLEANUP

# Purpose: cleanly log out when the script is finished
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

###############################################################################
# INSTANCE METHODS

# PRIVATE METHOD
# Purpose   : generic http request handler
# Parameters: 1) a url 2) action (GET, DELETE, POST) 3) correct response code
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
  
  return 1;
}

###############################################################################
# REGISTRATION METHODS

# INSTANCE METHOD
# Purpose   : register a single track hub with specified parameters
# Parameters: 1) hub id 2) hub url 2) hub assembly map
sub register_track_hub_data {
  my $self = shift;
  my %pars = @_;
  
  my $track_hub_id     = $pars{id};
  my $hub_url          = $pars{url};
  my $assembly_mapping = $pars{assembly_map};

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

  $logger->info("Send registration request for $track_hub_id");
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

# INSTANCE METHOD
# Purpose   : register a list of track hubs
# Parameters: an array of Hub objects
sub register_track_hubs {
  my $self = shift;
  my @hubs = @_;

  for my $hub (@hubs) {
    $logger->info(sprintf("Registering track hub %s with url %s (%s)\n", $hub->id, $hub->url, $self->is_public ? 'public' : 'hidden'));
    $self->register_track_hub_data(
      id           => $hub->id,
      url          => $hub->url,
      assembly_map => $hub->assembly_map
    );
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : update a list of track hubs to be public
# Parameters: an array of Hub objects
sub show_track_hubs {
  my $self = shift;
  my @hubs = @_;
  
  $self->is_public(1);
  $self->register_track_hubs(@hubs);
}

# INSTANCE METHOD
# Purpose   : update a list of track hubs to be hidden
# Parameters: an array of Hub objects
sub hide_track_hubs {
  my $self = shift;
  my @hubs = @_;
  
  $self->is_public(0);
  $self->register_track_hubs(@hubs);
}

###############################################################################
# DELETION METHODS

# INSTANCE METHOD
# Purpose   : unregister a list of track hubs based on their id
# Parameters: an array of id as string
sub delete_track_hub_ids {
  my $self = shift;
  my @hub_ids = @_;
  
  for my $hub_id (@hub_ids) {
    $logger->info( "Deleting trackhub " . $hub_id );
    my $url     = "$TRACKHUB_API/$hub_id";
    $self->_request( $url, 'DELETE', 200 );
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : unregister a list track hub
# Parameters: an array of Hub objects
sub delete_track_hubs {
  my $self = shift;
  my @track_hubs = @_;

  for my $track_hub (@track_hubs) {
    $logger->debug(Dumper $track_hub);
    croak("No track hub to delete") if (not $track_hub);
    my $id = $track_hub->{name};
    croak("No track hub id for deletion") if (not defined $id);

    $self->delete_track_hub_ids($id);
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : unregister all the currently registered hubs for this user
# Parameters: none
sub delete_all_track_hubs {
  my $self = shift;
  
  $logger->info("Delete all track hubs in the registry for the user");
  my @track_hubs = $self->get_registered;
  $self->delete_track_hubs(@track_hubs);
}

###############################################################################
# INFORMATION METHODS

# INSTANCE METHOD
# Purpose   : retrieve information about one or all track hubs
# Parameters: a track hub name (id), or none (then all hubs are returned)
sub get_registered {
  my $self = shift;
  my ($name) = @_;
  
  my $url = $TRACKHUB_API;
  $url .= '/' . $name if $name;
  my $trackhubs = $self->_request( $url, 'GET', 200 );
  
  return @$trackhubs;
}

# INSTANCE METHOD
# Purpose   : retrieve the name/id of all registered track hubs
# Parameters: none
sub get_registered_ids {
  my $self = shift;
  
  my $trackhubs = $self->get_registered();
  
  my @ids = map { $_->{name} } @$trackhubs;
  return @ids;
}

# INSTANCE METHOD
# Purpose   : get the latest update time of one/all registered track hubs
# Parameters: a track hub name/id, or none
sub get_registered_last_update {
  my $self = shift;
  my ($name) = @_;
  
  my @trackhubs = $self->get_registered($name);
  
  my $last_update = -1;

  foreach my $hub (@trackhubs) {
    foreach my $trackdb (@{ $hub->{trackdbs} }) {
      my $doc = $self->_request( $trackdb->{uri}, 'GET', 200 );

      if ( $doc->{updated} and $last_update < $doc->{updated} ) {
        $last_update = $doc->{updated};
      }
      elsif ( $doc->{created} and $last_update < $doc->{created} ) {
        $last_update = $doc->{created};
      }
      else {
        croak "Trackdb does not have creation date in the Registry when trying to get the last update date of study $name\n";
      }
    }
  }

  croak "Couldn't get date as expected: $last_update\n"
    unless $last_update =~ /^[1-9]\d+?$/;

  return $last_update;
}

1;

__END__

=head1 DESCRIPTION

Object used to interact with a Track Hub Registry API.

It can be used to register, update, delete, and get info about a track hub.

=head1 ATTRIBUTES

=over

=item I<user>

User name used to login to Track Hub Registry.

=item I<password>

Corresponding password for login.

=item I<is_public>

Whether the newly registered track hubs will be searchable (public = 1)
or not (hidden = 0, default).

=back

=head1 METHODS

=head2 new

The object will login and retrieve an authentification the first time it is used.

Usage:

  $registry = Bio::EnsEMBL::TrackHub::Registry->new(
    user     => $reg_user,
    password => $reg_pass,
  );
  
  # Make the newly registered track hubs searchable (hidden by default)
  $registry->is_public(1);

=head2 is_public

Set/Get the value of the attribute is_public.

Usage:

  # Make the registered hubs searchable
  $self->is_public(1);
  # Make the registered hubs not searchable
  $self->is_public(0);
  # Get the value
  my $is_public = $self->is_public();

=head2 REGISTRATION

=head3 B<register_track_hub_data>

This is the method that actually registers a track hub. Use register_track_hubs
instead if you already have Track Hub objects (recommended).

Parameters:

=over

=item I<id>

A unique identifier for the track hub.

=item I<url>

A URL pointing to the hub.txt file. Note that the Registry will only register a
hub.txt once (all users included).

=item I<assembly_map>

A mapping hash ref with the key as the genome name (used in genomes.txt) and
the value as the INSDC accession.

=back

Usage:

  $self->register_track_hub_data(
    id           => $id,
    url          => $url,
    assembly_map => $assembly_map
  );

=head3 B<register_track_hubs>

The best and simplest way to register a Hub.

Parameters: an array of Hub objects.

Usage:

  # One track hub
  $self->register_track_hubs($hub);
  # Several track hubs
  $self->register_track_hubs(@hubs);

=head3 B<show_track_hubs>

Update a list of track hubs and make them public (searchable).

Parameters: an array of Hub objects.

Usage:

  $self->show_track_hubs(@hubs);

=head3 B<hide_track_hubs>

Update all currently registered track hubs and make them hidden (unsearchable).

Parameters: an array of Hub objects.

Usage:

  $self->hide_track_hubs(@hubs);


=head2 DELETION

=head3 B<delete_track_hub_ids>

Unregister a list of track hubs based on their name/id.

Parameters: an array of string = ids.

Usage:

  $self->delete_track_hub_ids($name);

=head3 B<delete_track_hubs>

Unregister one or several track hubs (the id is extracted from the Hub objects).

Parameters: an array of Hub objects.

Usage:

  $self->delete_track_hubs(@hubs);

=head3 B<delete_all_track_hubs>

Unregister all registered track hubs for the current user. Use carefully.

Parameters: none

Usage:

  $self->delete_all_track_hubs();

=head2 INFORMATION

=head3 B<get_registered>

Get information about one or all registered track hubs for the current user.

Parameters: none or the name/id of a registered track_hub

Returns   : array of track hub hash informations

Usage:

  my @metadata       = $self->get_registered();
  my ($hub_metadata) = $self->get_registered($id);

=head3 B<get_registered_ids>

Get the list of ids of all registered track hubs for the current user.

Parameters: none

Returns   : array of ids (strings)

Usage:

  my @ids = $self->get_registered_ids();

=head3 B<get_registered_last_update>

Get the time of the latest change to all track hubs of the user.

Parameters: none

Returns   : Unix time (integer)

Usage:

  my $last_time = $self->get_registered_last_time();

=cut

