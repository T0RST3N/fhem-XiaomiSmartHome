###############################################################################
#
#  03.2017 torte
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
###############################################################################

package main;

use strict;
use warnings;
use strict;
use JSON qw( decode_json );
use Data::Dumper;
use IO::Socket;
use IO::Socket::Multicast;

sub XiaomiSmartHome_Notify($$);
sub XiaomiSmartHome_updateSingleReading($$);

my $version = "0.02";
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
    $hash->{WriteFn}    = "XiaomiSmartHome_Write";
	$hash->{AttrList}	= "disable:1,0 " .
						  "Room "  .	
						  $readingFnAttributes;
	$hash->{MatchList} = { "1:XiaomiSmartHome_Device"      => "^.+magnet",
						"2:XiaomiSmartHome_Device"      => "^.+motion",
						"3:XiaomiSmartHome_Device"      => "^.+sensor_ht",
						"4:XiaomiSmartHome_Device"      => "^.+switch"};
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
        Log3 $name, 5, "$name> Read:" .  $buf;
		if ($decoded->{'model'} eq 'gateway'){
			if ($decoded->{'cmd'} eq 'report'){
				my @status = split('\"', $decoded->{'data'});
				if ($status[1] eq 'rgb'){
					Log3 $name, 4, "$name>" . " SID: " . $decoded->{'sid'}  . " Type: Gateway" . " RGB: " . ($status[2] =~ /([\d]+)/)[0] ;
					readingsSingleUpdate($hash, "RGB", ($status[2] =~ /([\d]+)/)[0] , 1 );
					}
			}
			elsif ($decoded->{'cmd'} eq 'heartbeat'){
				readingsSingleUpdate($hash, $decoded->{'sid'}, 'heartbeat', 1 );
				readingsSingleUpdate($hash, 'token', $decoded->{'token'}, 1 );
			}
		}
		else {
			Log3 $name, 4, "$name> Dispatch! " . $buf;
			Dispatch($hash, $buf, undef);
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
	$hash->{VERSION}  = $version;
    $hash->{GATEYWAY} = $param[2];
	$hash->{FHEMIP} = XiaomiSmartHome_getLocalIP();
	$hash->{STATE} = "initialized";
    $hash->{helper}{host} = $definition;
    $hash->{helper}{JSON} = JSON->new->utf8();
	Log3 $hash->{NAME}, 5, "$hash->{NAME}> $definition";

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

sub XiaomiSmartHome_Write($$)
{
	my ($hash,$cmd,$sid)  = @_;
    my $name                    = $hash->{NAME};
    my $msg  = '{"cmd":"' .$cmd . '","sid":"' . $sid . '"}';

    return Log3 $name, 4, "Master ($name) - socket not connected"
    unless($hash->{CD});
    
    Log3 $name, 4, "$name> $msg " . $hash->{GATEYWAY};
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	$sock->mcast_send($msg,$hash->{GATEYWAY} .':9898') or die "send: $!";
    
    return undef;
}

#####################################


sub XiaomiSmartHome_Get($@)
{
	my ($hash , $name, $opt, $args ) = @_;
	my $name = $hash->{NAME};
	if ($opt eq "UpdateAll")
		{
		XiaomiSmartHome_updateAllReadings($hash);
		Log3 $name, 5, "$name> UpdateALLReadings Started";
		}
	elsif($opt eq "UpdateSingle")
		{
		XiaomiSmartHome_updateSingleReading($hash,$args);
		Log3 $name, 5, "$name> UpdateSingel Started";
		}
	else
	{
		return "unknown argument $opt choose one of UpdateAll:noArg UpdateSingle";
	}
}
#####################################

sub XiaomiSmartHome_Notify($$)
{
 	my ($own_hash, $dev_hash) = @_;
	my $ownName = $own_hash->{NAME}; # own name / hash
	Log3 $ownName, 3, "$ownName> NotifyStart";
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
		
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		 Log3 $ownName, 3, "$ownName> Starting Connect";
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
	Log3 $name, 3, "$name> ConnectStart";

    XiaomiSmartHome_disconnect($hash);

    Log3 $name, 4, "$name> connecting";

	my $sock = IO::Socket::Multicast->new( Proto     => 'udp', LocalPort =>'9898', ReuseAddr => 1) or die "Creating socket: $!\n";
	$sock->mcast_add('224.0.0.50', $hash->{fhemIP} ) || die "Couldn't set group: $!\n"; #$hash->{fhemIP}
	$sock->mcast_ttl(32);
	$sock->mcast_loopback(1);	  

    if ($sock)
    {
        Log3 $name, 3, "$name> connected";

        $hash->{helper}{ConnectionState} = "Connected";

        if ($hash->{helper}{ConnectionState} ne ReadingsVal($name, "state", "" ))
        {
            readingsSingleUpdate($hash, "state", $hash->{helper}{ConnectionState}, 1);
        }

        $hash->{FD} = $sock->fileno();
		$hash->{CD} = $sock;

        $selectlist{$name} = $hash;

        XiaomiSmartHome_updateAllReadings($hash);
    }
    else
    {
        Log3 $name, 1, "$name> connect to $hash->{helper}{host} failed";
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
    Log3 $name, 3, "$name> disconnecting";

    close($hash->{CD});
    delete($hash->{CD});


    return undef;
}
#####################################

sub XiaomiSmartHome_updateSingleReading($$)
{
	my ($hash, $sensor) = @_;
    my $name = $hash->{NAME};
	my $GATEYWAY = $hash->{GATEYWAY};
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	
	Log3 $name, 4, "$name> PushSingelRead:" .  $sensor;
	XiaomiSmartHome_Write($hash, $sensor);
	
}
#####################################

sub XiaomiSmartHome_updateAllReadings($)
{
	my $hash = shift;
    my $name = $hash->{NAME};
	my $GATEYWAY = $hash->{GATEYWAY};
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	
	my $msg = '{"cmd" : "get_id_list"}';
	$sock->mcast_send($msg, $GATEYWAY .':9898') or die "send: $!";
	eval {
		$sock->recv($msg, $MAXLEN)      or die "recv: $!";
		Log3 $name, 5, "$name> " . $msg;
		my $json = $hash->{helper}{JSON}->incr_parse($msg);
		my $decoded = decode_json($msg);
		if ($json){
			Log3 $name, 5, "$name> Read:" .  $msg;
			if ($decoded->{'cmd'} eq 'get_id_list_ack'){
				my @sensors = split('\"', $decoded->{'data'});
				@sensors = grep {$_ ne ',' and $_ ne ']' and $_ ne '[' } @sensors;
				foreach my $sensor (@sensors)	
				{
					$msg = '{"cmd":"read","sid":"' . $sensor . '" }';
					Log3 $name, 4, "$name> PushRead:" . $sensor;
					my $msg = '{"cmd":"read","sid":"' . $sensor . '" }';
					$sock->mcast_send($msg, $GATEYWAY .':9898') or die "send: $!";
					eval {
						$sock->recv($msg, $MAXLEN)      or die "recv: $!";
						Log3 $name, 5, "$name> " . $msg;
						Dispatch($hash, $msg, undef);
					}
					
				}
			}
		}
	}
}
#####################################

1;

=pod
=item device
=item summary Module fpr XiaomiSmartHome Gateway to use with FHEM
=item summary_DE Modul um ein XiaomiSmartHome Gateyway in FHEM zu nutzen

=begin html

<a name="XiaomiSmartHome"></a>
<h3>XiaomiSmartHome</h3>
<ul>
    <i>XiaomiSmartHome</i> implements the XiaomiSmartHome Gateway and Sensors. 
    <a name="XiaomiSmartHome"></a>
	<br>
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

<a name="XiaomiSmartHome"></a>
<h3>XiaomiSmartHome</h3>
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



