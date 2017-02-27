# 71_XiaomiSmartHome.pm 2017-08-02 13:07:33Z torte $

package main;

use strict;
use warnings;
use strict;
use JSON qw( decode_json );
use Data::Dumper;
use IO::Socket;
use IO::Socket::Multicast;

my %XiaomiSmartHome_gets = (
	"getDevices"	=> ["get_id_list", '^.+get_id_list_ack' ],

);


#####################################

sub XiaomiSmartHome_Initialize($) {
    my ($hash) = @_;
	
	$hash->{Clients}    = "XiaomiSmartHome_Device";
    $hash->{DefFn}      = 'XiaomiSmartHome_Define';
    $hash->{UndefFn}    = 'XiaomiSmartHome_Undef';
	$hash->{NotifyFn}   = 'XiaomiSmartHome_Notify';
    $hash->{SetFn}      = 'XiaomiSmartHome_Set';
    $hash->{GetFn}      = 'XiaomiSmartHome_Get';
    $hash->{AttrFn}     = 'XiaomiSmartHome_Attr';
    $hash->{ReadFn}     = 'XiaomiSmartHome_Read';
    $hash->{AttrList}	= "disable:1,0 "
						  .	$readingFnAttributes;
	$hash->{MatchList} = { "1:XiaomiSmartHome_Device"      => "^.+magnet",
						"2:XiaomiSmartHome_Device"      => "^.+motion",
						"3:XiaomiSmartHome_Device"      => "^.+sensor_ht"};
}					
#####################################

sub XiaomiSmartHome_Read($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $buf = "";
    my $ret = sysread($hash->{CD}, $buf, 1024);
    if (!defined($ret) || $ret <= 0)
    {
        XiaomiSmartHome_disconnect($hash);

        InternalTimer(gettimeofday() + 2, "XiaomiSmartHome_connect", $hash, 0);
        return;
    }

    my $json = $hash->{helper}{JSON}->incr_parse($buf);
	my $decoded = decode_json($buf);
    if ($json)
    {
        Log3 $name, 5, "$name: Read:" .  $buf;
		if ($decoded->{'cmd'} eq 'heartbeat'){
			readingsSingleUpdate($hash, $decoded->{'sid'}, 'heartbeat', 1 );
			}
		elsif ($decoded->{'cmd'} eq 'report'){			
			if ($decoded->{'model'} eq 'gateway'){
				my @status = split('\"', $decoded->{'data'});
					if ($status[1] eq 'rgb'){
						my $t = ($status[2] =~ /([\d]+)/);
						Log3 $name, 3, "$name: Gateway: " . $decoded->{'sid'} . " RGB: " . ($status[2] =~ /([\d]+)/)[0] ;
						readingsSingleUpdate($hash, "RGB", ($status[2] =~ /([\d]+)/)[0] , 1 );
						}
					#elsif($status[1] eq 'battery'){
					#	Log3 $name, 3, "$name: MagnetSensor: " . $decoded->{'sid'} . " Battery: " . $status[3];
					#	readingsSingleUpdate($hash, "Battery_" . "$decoded->{'sid'}", "$status[3]", 1 );
					#}	
				}
			else{
				Dispatch($hash, $buf, undef);
			}
			#	my @status = split('\"', $decoded->{'data'});
			#	
		}
    }
}
#####################################


sub XiaomiSmartHome_getLocalIP(){
  my $socket = IO::Socket::INET->new( 	Proto       => 'udp',
										PeerAddr    => '8.8.8.8:53',    # google dns
									);
  return '<unknown>' if( !$socket );
  my $ip = $socket->sockhost;
  close( $socket );
  return $ip if( $ip );

  return '<unknown>';
}
#####################################

sub XiaomiSmartHome_Define($$) {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    
    if(int(@param) < 3) {
        return "too few parameters: define <name> XiaomiSmartHome <GatewayIP>";
    }
	my $definition = $param[2];

	$hash->{DEF} = $definition;
	$hash->{NOTIFYDEV} = "global";
	$hash->{NAME}  = $param[0];
    $hash->{GATEYWAY} = $param[2];
	$hash->{FHEMIP} = XiaomiSmartHome_getLocalIP();
	$hash->{STATE} = "initialized";
    $hash->{helper}{host} = $definition;
    $hash->{helper}{JSON} = JSON->new->utf8();
	Log3 $hash->{NAME}, 3, "$hash->{NAME}: $definition";

	XiaomiSmartHome_connect($hash) if( $init_done);
	
    return undef;
}
#####################################

sub XiaomiSmartHome_Undef($$) {
    my ($hash, $arg) = @_; 
	
    XiaomiSmartHome_disconnect($hash);
    # nothing to do
    return undef;
}
#####################################

sub XiaomiSmartHome_Get($@)
{

}

#####################################

sub XiaomiSmartHome_Notify($$)
{
 	my ($own_hash, $dev_hash) = @_;
	my $ownName = $own_hash->{NAME}; # own name / hash
	Log3 $ownName, 3, "$ownName: NotifyStart - $dev_hash->{NAME}";
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
		
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	Log3 $ownName, 3, "$ownName: $devName";
	print join("; ", @{$events});
	Log3 $ownName, 3, "$ownName: " . grep(m/^INITIALIZED|REREADCFG$/, @{$events});
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		 Log3 $ownName, 3, "$ownName: 2";
		 XiaomiSmartHome_connect($own_hash);
	}
}
#####################################

sub XiaomiSmartHome_Set($@) {

}
#####################################

sub XiaomiSmartHome_Attr(@) {

}
#####################################

sub XiaomiSmartHome_connect($)
{
    my $hash = shift;
    my $name = $hash->{NAME};
	Log3 $name, 3, "$name: ConnectStart";
    #return if (AttrVal($hash->{NAME}, "disable", 0));

    XiaomiSmartHome_disconnect($hash);

    Log3 $name, 4, "$name: connecting";

	my $sock = IO::Socket::Multicast->new( Proto     => 'udp', LocalPort =>'9898', ReuseAddr => 1) or die "Creating socket: $!\n";
	$sock->mcast_add('224.0.0.50', $hash->{fhemIP} ) || die "Couldn't set group: $!\n"; #$hash->{fhemIP}
	$sock->mcast_ttl(32);
	$sock->mcast_loopback(1);	  

    if ($sock)
    {
        Log3 $name, 3, "$name: connected";

        $hash->{helper}{ConnectionState} = "Connected";

        if ($hash->{helper}{ConnectionState} ne ReadingsVal($name, "state", "" ))
        {
            readingsSingleUpdate($hash, "state", $hash->{helper}{ConnectionState}, 1);
        }

        $hash->{FD} = $sock->fileno();
		$hash->{CD} = $sock;

        $selectlist{$name} = $hash;

        #XiaomiSmartHome_updateAllReadings($hash);
    }
    else
    {
        Log3 $name, 1, "$name: connect to $hash->{helper}{host} failed";
    }

    return undef;
}
#####################################

sub XiaomiSmartHome_disconnect($)
{
    my $hash = shift;
    my $name = $hash->{NAME};

    RemoveInternalTimer($hash);
    $hash->{helper}{ConnectionState} = "Disconnected";
    if ($hash->{helper}{ConnectionState} ne ReadingsVal($name, "state", "" ))
    {
        readingsSingleUpdate($hash, "state", $hash->{helper}{ConnectionState}, 1);
    }

    return if (!$hash->{CD});
    Log3 $name, 3, "$name: disconnecting";

    close($hash->{CD});
    delete($hash->{CD});


    return undef;
}

1;

=pod
=item [helper|device|command]
=item summary Module fpr XiaomiSmartHome Gateway to use with FHEM
=item summary_DE Modul um ein XiaomiSmartHome Gateyway in FHEM bekannt zu machen

=begin html
<a name="xiaomismarthome"></a>
<h3>xiaomismarthome</h3>
<ul>
    <i>XiaomiSmartHome</i> implements the XiaomiSmartHome Gateway and Sensors. 
    <a name="XiaomiSmartHome"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; XiaomiSmartHome &lt;IP or Hostname&gt;</code>
        <br><br>
        Example: <code>define XiaomiSmartHome XiaomiSmartHome 192.168.1.xxx</code>
        <br><br>

    </ul>
    <br>
</ul>
=end html

=begin html_DE
<a name="xiaomismarthome"></a>
<h3>xiaomismarthome</h3>
<ul>
    <i>XiaomiSmartHome</i> implements the XiaomiSmartHome Gateway and Sensors. 
    <a name="XiaomiSmartHome"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; XiaomiSmartHome &lt;IP or Hostname&gt;</code>
        <br><br>
        Example: <code>define XiaomiSmartHome XiaomiSmartHome 192.168.1.xxx</code>
        <br><br>

    </ul>
    <br>
</ul>
=end html


=cut



