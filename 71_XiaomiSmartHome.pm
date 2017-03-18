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
use JSON qw( decode_json );
use Data::Dumper;
use IO::Socket;
use IO::Socket::Multicast;
use Crypt::CBC;
use Color;
use SetExtensions;

sub XiaomiSmartHome_Notify($$);
sub XiaomiSmartHome_updateSingleReading($$);
my $iv="\x17\x99\x6d\x09\x3d\x28\xdd\xb3\xba\x69\x5a\x2e\x6f\x58\x56\x2e";
my $version = "0.05";
my %XiaomiSmartHome_gets = (
	"getDevices"	=> ["get_id_list", '^.+get_id_list_ack' ],

);

my %sets = (
  "password"            => 1,
  "rgb:colorpicker,RGB" => 1,
  #"pct:colorpicker,BRI,0,300,1300" =>1,
  "off"                 => 0,
  "on"                  => 0,
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
	FHEM_colorpickerInit();
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
				my $data = decode_json($decoded->{data});
				if (defined $data->{rgb}){
					Log3 $name, 4, "$name>" . " SID: " . $decoded->{'sid'}  . " Type: Gateway" . " RGB: " . $data->{rgb} ;
					readingsSingleUpdate($hash, "RGB", $data->{rgb} , 1 );
					}
			}
			elsif ($decoded->{'cmd'} eq 'heartbeat'){
				readingsSingleUpdate($hash, 'HEARTBEAT', $decoded->{'sid'}, 1 );
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
	$attr{$hash->{NAME}}{webCmd} = "rgb:rgb ff0000:rgb 00ff00:rgb 0000ff:on:off";
	# Define devStateIcon
	$attr{$hash->{NAME}}{devStateIcon} = '{Color_devStateIcon(ReadingsVal($name,"rgb","000000"))}' if(!defined($attr{$hash->{NAME}}{devStateIcon}));
	$attr{$hash->{NAME}}{room} = "MiSmartHome" if( !defined( $attr{$hash->{NAME}}{room} ) );
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

sub XiaomiSmartHome_Write($$$)
{
	my ($hash,$cmd,$val)  = @_;
    my $name = $hash->{NAME};
	my $msg;
    if ($cmd eq 'read')
		{
		$msg  = '{"cmd":"' .$cmd . '","sid":"' . $val . '"}';
		}
	elsif ($cmd eq 'rgb')
		{
		# TODO SID des Gateway nicht im und aus dem Reading!!
		$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{READINGS}{HEARTBEAT}{VAL} . '","short_id":0,"key":"8","data":"{\"rgb\":' . $val . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				
		}
	elsif ($cmd eq 'illumination')
		{
		# TODO SID des Gateway nicht im und aus dem Reading!!
		#$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{READINGS}{HEARTBEAT}{VAL} . '","short_id":0,"key":"8","data":"{\"illumination\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
		$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{READINGS}{HEARTBEAT}{VAL} . '","short_id":0,"key":"8","data":"{\"mid\":\"3\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
		#$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{READINGS}{HEARTBEAT}{VAL} . '","short_id":0,"key":"8","data":"{\"hue\":\"170\",\"saturation\":\"254\", \"color_temperature\":\"65279\", \"x\":\"10\", \"y\":\"10\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';

			
		}
	return Log3 $name, 4, "Master ($name) - socket not connected" unless($hash->{CD});
    
    Log3 $name, 4, "$name> $msg " . $hash->{GATEYWAY};
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	$sock->mcast_send($msg,$hash->{GATEYWAY} .':9898') or die "send: $!";
    
    return undef;
}
#####################################

sub XiaomiSmartHome_EncryptKey($)
{
	my ($hash) = @_;
	if (defined $hash->{READINGS}{password}{VAL}){
		my $key = $hash->{READINGS}{password}{VAL};
		my $cipher = Crypt::CBC->new(-key => $key, -cipher => 'Cipher::AES',-iv => $iv, -literal_key => 1, -header => "none", -keysize => 16 );  
		my $encryptkey = $cipher->encrypt_hex($hash->{READINGS}{token}{VAL});
		$encryptkey = substr($encryptkey, 0, 32);	
		return $encryptkey;
		}
	return undef;
}
#####################################

sub XiaomiSmartHome_Get($@)
{
	my ($hash , $name, $opt, $args ) = @_;
	
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

sub XiaomiSmartHome_Set($@) 
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	my $dec_num;
	my @match = grep( $_ =~ /^$cmd($|:)/, keys %sets );
	#-- check argument
	return SetExtensions($hash, join(" ", keys %sets), $name, $cmd, @args) unless @match == 1;
	return "$cmd expects $sets{$match[0]} parameters" unless (@args eq $sets{$match[0]});
		
	return "\"set $name\" needs at least one argument" unless(defined($cmd));

		
	if($cmd eq "password")
	{
	   if($args[0] =~ /^[a-zA-Z0-9_.-]*$/)
	   {
			readingsSingleUpdate( $hash, $cmd, $args[0], 0 );
			return;
	   }
	   else
	   {
	      return "Unknown value $args[0] for $cmd, wrong password, it must be hex";
	   }   
	}
	elsif($cmd eq "rgb")
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName> Set $cmd, $args[0]";
		$dec_num = sprintf("%d", hex('ff' . $args[0]));
		Log3 $ownName, 4, "$ownName> Set $cmd, $dec_num";
		readingsSingleUpdate( $hash, 'rgb', $args[0], 1 );
		readingsSingleUpdate( $hash, 'state', 'on', 1 );
		XiaomiSmartHome_Write($hash,$cmd,$dec_num);
	}
	elsif($cmd eq "off")
	{
		$hash->{helper}{prevrgbvalue} = $hash->{READINGS}{rgb}{VAL};
		readingsSingleUpdate( $hash, 'state', 'off', 1 );
		readingsSingleUpdate( $hash, 'rgb', 'off', 1 );
		XiaomiSmartHome_Write($hash,'rgb', 0);
	}
	elsif($cmd eq "on")
	{
		readingsSingleUpdate( $hash, 'state', 'on', 1 );
		if ($hash->{helper}{prevrgbvalue})
			{
			$dec_num = sprintf("%d", hex('ff' . $hash->{helper}{prevrgbvalue}));
			readingsSingleUpdate( $hash, 'rgb', $hash->{helper}{prevrgbvalue}, 1 );
			XiaomiSmartHome_Write($hash,'rgb', $dec_num);
			}
		else 
			{
			XiaomiSmartHome_Write($hash,'rgb', 1677786880);
			readingsSingleUpdate( $hash, 'rgb', '00ff00', 1 );
			}
	}
	elsif($cmd eq "pct")
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName> Set $cmd, $args[0]";
		XiaomiSmartHome_Write($hash,'illumination',$args[0]);
	}
	
	else
	{
		return "Unknown argument! $cmd, $args[0], choose one of password rgb";
	}
}
#####################################


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
	XiaomiSmartHome_Write($hash, 'read', $sensor);
	
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
				my @sensors = @{decode_json($decoded->{data})};
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



