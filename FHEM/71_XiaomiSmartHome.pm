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
use Data::Dumper;

eval "use HTTP::Request::Common";
return "\nERROR: Please install HTTP::Request::Common" if($@);
eval "use JSON qw( decode_json )";
return "\nERROR: Please install JSON qw( decode_json )" if($@);
eval "use IO::Socket";
return "\nERROR: Please install IO::Socket" if($@);
eval "use IO::Socket::Multicast";
return "\nERROR: Please install IO::Socket::Multicast" if($@);
eval "use Crypt::CBC";
return "\nERROR: Please install Crypt::CBC" if($@);
eval "use Net::Ping";
return "\nERROR: Please install Net::Ping" if($@);

use Color;
use SetExtensions;



sub XiaomiSmartHome_Notify($$);
sub XiaomiSmartHome_updateSingleReading($$);
sub XiaomiSmartHome_updateAllReadings($);
my $iv="\x17\x99\x6d\x09\x3d\x28\xdd\xb3\xba\x69\x5a\x2e\x6f\x58\x56\x2e";
my $version = "0.22";
my %XiaomiSmartHome_gets = (
	"getDevices"	=> ["get_id_list", '^.+get_id_list_ack' ],

);

my %sets = (
  "password"            => 1,
  "rgb:colorpicker,RGB" => 1,
  "pct:colorpicker,BRI,0,1,100" => 1,
  "volume:slider,0,1,100" => 1,
  "off"                 => 0,
  "on"                  => 0,
  "ringtone:0,1,2,3,4,5,6,7,8,13,21,22,23,24,25,26,27,28,29,10000,10001" => 1,
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
						  $readingFnAttributes;
	
	$hash->{MatchList} = { "1:XiaomiSmartHome_Device"      => "^.+magnet",
						"2:XiaomiSmartHome_Device"      => "^.+motion",
						"3:XiaomiSmartHome_Device"      => "^.+sensor_ht",
						"4:XiaomiSmartHome_Device"      => "^.+switch",
						"5:XiaomiSmartHome_Device"      => "^.+cube",
						"6:XiaomiSmartHome_Device"      => "^.+plug",
						"7:XiaomiSmartHome_Device"      => "^.+86sw2"};
	FHEM_colorpickerInit();
}
#####################################

sub XiaomiSmartHome_Read($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
	Log3 $name, 5, "$name: Read> Read start";
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
	if ( ! $decoded ) {
		Log3 $name, 4, "$name: Read> Error no JSON Data " . $buf;
		return;
	}
    if ($json)
    {
        Log3 $name, 5, "$name: Read> " .  $buf;
		readingsBeginUpdate( $hash ); 
		if ($decoded->{'cmd'} eq 'report' && $decoded->{'model'} eq 'gateway' || $decoded->{'cmd'} eq 'heartbeat' && $decoded->{'model'} eq 'gateway' || $decoded->{'cmd'} eq 'write_ack'){
			readingsBeginUpdate( $hash );
			if ($decoded->{'model'} && $decoded->{'model'} eq 'gateway' ){
				if ($decoded->{'cmd'} eq 'report'){
					my $data = decode_json($decoded->{data});
					if (defined $data->{rgb}){
						Log3 $name, 3, "$name: Read>" . " SID: " . $decoded->{'sid'}  . " Type: Gateway" . " RGB: " . $data->{rgb} ;
						readingsBulkUpdate($hash, "RGB", $data->{rgb} , 1 );
						}
				}
				elsif ($decoded->{'cmd'} eq 'heartbeat'){
					my $data = decode_json($decoded->{data});
					if ($data->{ip} eq $hash->{GATEWAY_IP}){
						readingsBulkUpdate($hash, 'heartbeat', $decoded->{'sid'}, 1 );
						readingsBulkUpdate($hash, 'token', $decoded->{'token'}, 1 );
					}
					else {
						Log3 $name, 4, "$name: Read> IP-Heartbeat Data didnt match! $data->{ip}  " . $hash->{GATEWAY_IP} ;
					}
				}
			}
			if ($decoded->{'cmd'} eq 'write_ack'){
				Log3 $name, 4, "$name: Read> Write answer " . $hash->{GATEWAY} ;
				my $data = decode_json($decoded->{data});
				if ($data->{error}){
					readingsBulkUpdate($hash, 'heartbeat', $data->{error}, 1 );	
				}
				else {
					readingsBulkUpdate($hash, 'heartbeat', "Write_OK", 1 );	
				}
			}
			readingsEndUpdate( $hash, 1 );
			return;
		}
		if ($decoded->{'cmd'} eq 'get_id_list_ack'){
			my @sensors = @{decode_json($decoded->{data})};
			foreach my $sensor (@sensors)	
				{
				Log3 $name, 4, "$name: Read> PushRead:" . $sensor;
				XiaomiSmartHome_Write($hash, 'read',  $sensor );
				}
			return;
		}

		Log3 $name, 4, "$name: Read> dispatch " . $buf;
		Dispatch($hash, $buf, undef);
			

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

sub XiaomiSmartHome_getGatewaySID($){
	my ($hash, $def) = @_;
	my $name = $hash->{NAME};
	my $json;
	my $decoded;
	my $timeout = $hash->{TIMEOUT} ? $hash->{TIMEOUT} : 3;
	my $sidsock = IO::Socket::Multicast->new( Proto     => 'udp',LocalAddr => $hash->{FHEMIP}, LocalPort =>'4321', ReuseAddr => 1, Timeout => $timeout) or die "Creating socket: $!\n";
	$sidsock->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 30, 0))   or die "setsockopt: $!";
	if ($sidsock){
		my $msg = '{"cmd":"whois"}';
		$sidsock->mcast_send($msg,'224.0.0.50:4321') or die "send: $!";
		eval {
			$sidsock->recv($msg, 1024)  or die "recv: $!";
			$json = $hash->{helper}{JSON}->incr_parse($msg);
			$decoded = decode_json($msg);
			$sidsock->close();
			};
		if ($@) {
			Log3 $name, 1, "$name: getGatewaySID> Error $@\n";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
	}
	if ($json)
    {
		if ($decoded->{'sid'} ne '')
		{
			Log3 $name, 4, "$name: Find SID for Gateway: $decoded->{'sid'}";
			return $decoded->{'sid'};
		}
    }
	else {
		Log3 $name, 5, "$name: Did not find a SID for Gateway disconnecting";
		$hash->{STATE} = "Disconnected";
		XiaomiSmartHome_disconnect($hash);
		}
}
#####################################

sub XiaomiSmartHome_Define($$) {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    my $name = $hash->{NAME};

    if(int(@param) < 3) {
        return "too few parameters: define <name> XiaomiSmartHome <GatewayIP>";
    }
	my $p = Net::Ping->new();
	if ( ! $p->ping($param[2])){
		$hash->{STATE} = "Disconnected";
		XiaomiSmartHome_disconnect($hash);
		Log3 $name, 5, "$name: Ping ERROR Gateway disconnecting";
		$p->close(); 
	}
	my $definition = $param[2];
	$hash->{DEF} = $definition;
	$hash->{NOTIFYDEV} = "global";
	$hash->{NAME}  = $param[0];
	$hash->{VERSION}  = $version;
    $hash->{GATEWAY} = $param[2];
	$hash->{GATEWAY_IP} = $param[2];
	$hash->{helper}{JSON} = JSON->new->utf8();
	$hash->{FHEMIP} = XiaomiSmartHome_getLocalIP();
	$hash->{STATE} = "initialized";
	$hash->{SID} = XiaomiSmartHome_getGatewaySID($hash);
    $hash->{helper}{host} = $definition;    
	Log3 $name, 5, "$name: $definition";
	# Define devStateIcon
	$attr{$hash->{NAME}}{devStateIcon} = '{Color_devStateIcon(ReadingsVal($name,"rgb","000000"))}' if(!defined($attr{$hash->{NAME}}{devStateIcon}));
	
	$attr{$hash->{NAME}}{room} = "MiSmartHome" if( !defined( $attr{$hash->{NAME}}{room} ) );
	
	InternalTimer(gettimeofday() + 5, "XiaomiSmartHome_connect", $hash, 0);		
	
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

sub XiaomiSmartHome_Write($@)
{
	my ($hash,$cmd,$val,$iohash)  = @_;
    my $name = $hash->{NAME};
	if ( $hash->{helper}{ConnectionState} eq 'Disconnected') {	
		Log3 $name, 1, "$name: Write> Cannot write iam disconnected";
		return undef;
		}
	else{
		my $p = Net::Ping->new();
		if ( ! $p->ping($hash->{GATEWAY})){
			Log3 $name, 1, "$name: Write> Ping to $hash->{helper}{host} failed";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			$p->close(); 
			return undef;
			}
		}
	my $GATEWAY = inet_ntoa(inet_aton($hash->{GATEWAY}));
	$hash->{GATEWAY_IP} = $GATEWAY;
	my $msg;
	if ($cmd eq 'read')
		{
		$msg  = '{"cmd":"' .$cmd . '","sid":"' . $val . '"}';
		}
	if ($cmd eq 'get_id_list')
		{
		Log3 $name, 5, "$name: Write> Get all Sensors";
		$msg  = '{"cmd" : "get_id_list"}';
		}
	if ( $hash->{READINGS}{password}{VAL}  !~ /^[a-zA-Z0-9]{16}$/ )
		{
		Log3 $name, 1, "$name: Write> Password not SET!";
		readingsSingleUpdate($hash, "password", "giveaPassword!", 1);
		return "for $cmd, wrong password, it must be hex and 16 characters";
		}
	else {
		if ($cmd eq 'rgb')
			{
			$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{SID} . '","short_id":0,"key":"8","data":"{\"rgb\":' . $val . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
		if ($cmd eq 'pct')
			{
			$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{SID} . '","short_id":0,"key":"8","data":"{\"rgb\":' . $val . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
		if ($cmd eq 'power')
			{
			$msg  = '{"cmd":"write","model":"plug","sid":"' . $iohash->{SID} . '","data":"{\"status\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
		if ($cmd eq 'ringtone')
			{
			my $vol = $hash->{READINGS}{volume}{VAL};
			$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{SID} . '","short_id":0,"key":"8","data":"{\"mid\":' . $val . ',\"vol\":' . $vol . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
		if ($cmd eq 'volume')
			{
			my $rt = $hash->{READINGS}{ringtone}{VAL};
			$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{SID} . '","short_id":0,"key":"8","data":"{\"mid\":' . $rt . ',\"vol\":' .$val . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
		}
	return Log3 $name, 4, "$name: Write> - socket not connected" unless($hash->{CD});
    Log3 $name, 4, "$name: Write> $msg " . $GATEWAY;
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	$sock->mcast_send($msg,$GATEWAY .':9898') or die "send: $!";
    Log3 $name, 5, "$name: Write> End " . $GATEWAY;
    return undef;
}
#####################################

sub XiaomiSmartHome_EncryptKey($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	if ( $hash->{READINGS}{password}{VAL}  =~ /^[a-zA-Z0-9]{16}$/ ) {
		my $key = $hash->{READINGS}{password}{VAL};
		my $cipher = Crypt::CBC->new(-key => $key, -cipher => 'Cipher::AES',-iv => $iv, -literal_key => 1, -header => "none", -keysize => 16 );  
		my $encryptkey = $cipher->encrypt_hex($hash->{READINGS}{token}{VAL});
		$encryptkey = substr($encryptkey, 0, 32);	
		return $encryptkey;
		}
	else
		{
		Log3 $name, 1, "$name: EncryptKey> Password not SET!";
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
		Log3 $name, 5, "$name: Get> UpdateALLReadings Started";
		}
	elsif($opt eq "UpdateSingle")
		{
		XiaomiSmartHome_updateSingleReading($hash,$args);
		Log3 $name, 5, "$name: Get> UpdateSingel Started";
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
	Log3 $ownName, 5, "$ownName: Notify> NotifyStart";
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
	$attr{$own_hash->{NAME}}{webCmd} = "pct:rgb:rgb ff0000:rgb 00ff00:rgb 0000ff:on:off" if ( ! $attr{$own_hash->{NAME}}{webCmd} || $attr{$own_hash->{NAME}}{webCmd} eq "rgb:rgb ff0000:rgb 00ff00:rgb 0000ff:on:off" );
	readingsSingleUpdate($own_hash, "pct", 100, 1) if ( ! $own_hash->{READINGS}{pct}{VAL});	
	readingsSingleUpdate($own_hash, "ringtone", 21, 1) if ( ! $own_hash->{READINGS}{ringtone}{VAL});	
	readingsSingleUpdate($own_hash, "volume", 10, 1) if ( ! $own_hash->{READINGS}{volume}{VAL});	
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		Log3 $ownName, 5, "$ownName: Notify> Starting Connect after global";
		XiaomiSmartHome_connect($own_hash);
		CommandDeleteReading( undef, "$ownName HEARTBEAT" ) if(defined(ReadingsVal($ownName,"HEARTBEAT",undef)));
	}
}
#####################################

sub XiaomiSmartHome_Set($@) 
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	my $dec_num;
	my $MIpct;
	my @match = grep( $_ =~ /^$cmd($|:)/, keys %sets );
	#-- check argument
	return SetExtensions($hash, join(" ", keys %sets), $name, $cmd, @args) unless @match == 1;
	return "$cmd expects $sets{$match[0]} parameters" unless (@args eq $sets{$match[0]});
		
	return "\"set $name\" needs at least one argument" unless(defined($cmd));
	if (!defined $hash->{READINGS}{pct}) {
		$MIpct = $hash->{READINGS}{pct}{VAL};
		}
	else {
		$MIpct = 64;
		}		
	if($cmd eq "password")
	{
	   #if($args[0] =~ /^[a-zA-Z0-9_.-]*$/)
	   if($args[0] =~ /^[a-zA-Z0-9]{16}$/)
	   {
			readingsSingleUpdate( $hash, $cmd, $args[0], 0 );
			return;
	   }
	   else
	   {
	      return "Unknown value $args[0] for $cmd, wrong password, it must be hex and 16 characters";
	   }   
	}
	if ( $hash->{READINGS}{password}{VAL} !~ /^[a-zA-Z0-9]{16}$/)
	{
		readingsSingleUpdate($hash, "password", "giveaPassword!", 1);
		Log3 $name, 1, "$name: Set> Password not SET!";
		return "for $cmd, wrong password, it must be hex and 16 characters";
	}
	elsif($cmd eq "rgb")
	{
		my $ownName = $hash->{NAME};
		
		Log3 $ownName, 4, "$ownName: Set> $cmd, $args[0]";
		$dec_num = sprintf("%d", hex($MIpct . $args[0]));
		Log3 $ownName, 4, "$ownName: Set> $cmd, $dec_num";
		$hash->{helper}{prevrgbvalue} = $args[0];
		readingsSingleUpdate( $hash, 'rgb', $args[0], 1 );
		readingsSingleUpdate( $hash, 'state', 'on', 1 );
		XiaomiSmartHome_Write($hash,$cmd,$dec_num);
	}
	elsif($cmd eq "off")
	{
		$hash->{helper}{prevrgbvalue} = $hash->{READINGS}{rgb}{VAL};
		readingsSingleUpdate( $hash, 'state', 'off', 1 );
		readingsSingleUpdate( $hash, 'rgb', '000000', 0 );
		XiaomiSmartHome_Write($hash,'rgb', 0);
	}
	elsif($cmd eq "on")
	{
		readingsBeginUpdate( $hash );
		readingsBulkUpdate( $hash, 'state', 'on', 1 );
		if ($hash->{helper}{prevrgbvalue})
			{
			$dec_num = sprintf("%d", hex($MIpct . $hash->{helper}{prevrgbvalue}));
			readingsBulkUpdate( $hash, 'rgb', $hash->{helper}{prevrgbvalue}, 1 );
			XiaomiSmartHome_Write($hash,'rgb', $dec_num);
			}
		else 
			{
			readingsBulkUpdate( $hash, 'rgb', "00ff00", 1 );
			XiaomiSmartHome_Write($hash,'rgb', 1677786880);
			}
		readingsEndUpdate( $hash, 1 );
	}
	elsif($cmd eq "pct")
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName: Set> $cmd, $args[0], $hash->{helper}{prevrgbvalue}";
		readingsSingleUpdate( $hash, 'pct', $args[0], 1 );
		readingsSingleUpdate( $hash, 'rgb', $hash->{helper}{prevrgbvalue}, 1 );
		readingsSingleUpdate( $hash, 'state', 'on', 1 );
		my $MIpct = sprintf( "%.0f", (0.64 * $args[0]));
		Log3 $ownName, 4, "$ownName: Set> $cmd, $MIpct";
		my $rgb = sprintf("%d", hex($MIpct . $hash->{helper}{prevrgbvalue}));
		XiaomiSmartHome_Write($hash,'pct',$rgb);
	}
	elsif($cmd eq "ringtone")
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName: Set> $cmd, $args[0]";
		readingsSingleUpdate( $hash, 'ringtone', $args[0], 1 );
		XiaomiSmartHome_Write($hash,'ringtone',$args[0]);
	}
	elsif($cmd eq "volume")
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName: Set> $cmd, $args[0]";
		readingsSingleUpdate( $hash, 'volume', $args[0], 1 );
		XiaomiSmartHome_Write($hash,'volume',$args[0]);
	}
	else
	{
		return "Unknown argument! $cmd, $args[0], choose one of password rgb volume";
	}
}
#####################################


#####################################


sub XiaomiSmartHome_Attr(@) {
	my ($cmd,$NAME,$name, $val) = @_;
	if ($cmd eq "delete"){
		delete $attr{$NAME}{$name}; 
		CommandDeleteAttr(undef, "$NAME $name");
		Log3 $name, 1, "$name: Attr> delete $name";
	}
	if ($cmd eq "create"){
		$attr{$NAME}{$name} = $val;
		Log3 $name, 1, "$name: Attr> create $name $val";
	}
	return undef;
}
#####################################

sub XiaomiSmartHome_connect($)
{
    my $hash = shift;
    my $name = $hash->{NAME};
	my $GATEWAY_IP;
	Log3 $name, 5, "$name: connect> ConnectStart";

    Log3 $name, 4, "$name: connecting";
	my $p = Net::Ping->new();
	if ( ! $p->ping($hash->{GATEWAY})){
		Log3 $name, 1, "$name: connect> Ping to $hash->{helper}{host} failed";
		$hash->{STATE} = "Disconnected";
		XiaomiSmartHome_disconnect($hash);
		$p->close(); 
		return undef;
	}
	if( $hash->{GATEWAY} !~ m/^\d+\.\d+\.\d+\.\d+$/ ){
		eval {
			$GATEWAY_IP = inet_ntoa(inet_aton($hash->{GATEWAY})) ;
			$hash->{GATEWAY_IP} = $GATEWAY_IP;
			Log3 $name, 4, "$name: Connect> Set GATEWAYs IP: " .  $GATEWAY_IP;
			};
		if ($@) {
			Log3 $name, 1, "$name: Connect> Error $@\n";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
		}

	my $timeout = $hash->{TIMEOUT} ? $hash->{TIMEOUT} : 3;
	my $sock = IO::Socket::Multicast->new( Proto     => 'udp', LocalPort =>'9898', ReuseAddr => 1, Timeout => $timeout) or die "Creating socket: $!\n";
	$sock->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 30, 0))   or die "setsockopt: $!";
	if ($sock)
	{
		Log3 $name, 3, "$name: connect> Connected";
		$sock->mcast_add('224.0.0.50', $hash->{fhemIP} ) || die "Couldn't set group: $!\n"; #$hash->{fhemIP}
		$sock->mcast_ttl(32);
		$sock->mcast_loopback(1);
		$hash->{helper}{ConnectionState} = "Connected";
		$hash->{SID} = XiaomiSmartHome_getGatewaySID($hash);
		if ($hash->{helper}{ConnectionState} ne ReadingsVal($name, "state", "" ))
		{
			readingsSingleUpdate($hash, "state", $hash->{helper}{ConnectionState}, 1);
		}
		$hash->{FD} = $sock->fileno();
		$hash->{CD} = $sock;
		$selectlist{$name} = $hash;
		readingsSingleUpdate($hash, "password", 'giveaPassword!', 1) if(!defined $hash->{READINGS}{password}{VAL});
		InternalTimer(gettimeofday() + 7, "XiaomiSmartHome_updateAllReadings", $hash, 0);
	}

	else
	{
		Log3 $name, 1, "$name: connect> connect to $hash->{helper}{host} failed";
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
    Log3 $name, 3, "$name: disconnect> disconnecting";
	
	close($hash->{CD}) if($hash->{CD});
    delete($hash->{FD});
    delete($hash->{CD});
    delete($selectlist{$name});
	

    return undef;
}
#####################################

sub XiaomiSmartHome_updateSingleReading($$)
{
	my ($hash, $sensor) = @_;
    my $name = $hash->{NAME};
	my $GATEWAY = $hash->{GATEWAY};
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	
	Log3 $name, 4, "$name: updateSingleReading> PushSingelRead:" .  $sensor;
	XiaomiSmartHome_Write($hash, 'read', $sensor);
	
}
#####################################

sub XiaomiSmartHome_updateAllReadings($)
{
	my $hash = shift;
    my $name = $hash->{NAME};
	Log3 $name, 5, "$name> updateAllReadings> Starting UpdateALLReadings";
	my $GATEWAY;
	my $p = Net::Ping->new();
	if ( ! $p->ping($hash->{GATEWAY})){
		Log3 $name, 4, "$name: updateAllReadings> Ping to $hash->{helper}{host} failed";
		$hash->{STATE} = "Disconnected";
		XiaomiSmartHome_disconnect($hash);
		$p->close(); 
		return undef;
	}
	if( $hash->{GATEWAY} !~ m/^\d+\.\d+\.\d+\.\d+$/ ){
		eval {
			$GATEWAY = inet_ntoa(inet_aton($hash->{GATEWAY})) ;
			Log3 $name, 4, "$name: updateAllReadings> Using DNS to IP: " .  $GATEWAY;
			};
		if ($@) {
			Log3 $name, 1, "$name: updateAllReadings> Error $@\n";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
		}
	else
		{
		$GATEWAY = $hash->{GATEWAY};
		}

	if ( $hash->{helper}{ConnectionState} eq 'Disconnected') 
		 {
		 Log3 $name, 1, "$name: updateAllReadings> Gateway is $hash->{STATE} trying to reconnect to $hash->{GATEWAY}";
		 XiaomiSmartHome_connect($hash);
		 return undef;
		 }
		 
	XiaomiSmartHome_Write($hash, 'get_id_list');
}
#####################################

1;

=pod
=item device
=item summary Module for XiaomiSmartHome Gateway to use with FHEM
=item summary_DE Modul um ein XiaomiSmartHome Gateway in FHEM zu nutzen

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
	<b>Prerequisite</b>
	<ul>
		<li>Installation of the following packages: apt-get install libio-socket-multicast-perl libjson-perl libcrypt-cbc-perl</li>
		<li>And with CPAN: cpan Crypt::Cipher::AES</li>
	</ul>
</ul>
=end html


=cut



