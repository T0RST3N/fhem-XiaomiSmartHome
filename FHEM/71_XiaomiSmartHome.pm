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

sub XiaomiSmartHome_updateSingleReading($$);
my $iv="\x17\x99\x6d\x09\x3d\x28\xdd\xb3\xba\x69\x5a\x2e\x6f\x58\x56\x2e";

my $version = "1.42";

my %XiaomiSmartHome_gets = (
	"getDevices"	=> ["get_id_list", '^.+get_id_list_ack' ],

);

my %sets = (
  "password"            => 1,
  "rgb:colorpicker,RGB" => 1,
  "pct:colorpicker,BRI,0,1,100" => 1,
  "off"                 => 0,
  "on"                  => 0,
  "volume:slider,1,1,100" => 1,
  "ringtone:0,1,2,3,4,5,6,7,8,13,21,22,23,24,25,26,27,28,29,10000,10001" => 1,
  "ringvol" => 2,
  "learn" => 0,
);


#####################################

sub XiaomiSmartHome_Initialize($) {
    my ($hash) = @_;

	$hash->{Clients}    = 'XiaomiSmartHome_Device';
    $hash->{DefFn}      = 'XiaomiSmartHome_Define';
    $hash->{UndefFn}    = 'XiaomiSmartHome_Undef';
	$hash->{NotifyFn}   = 'XiaomiSmartHome_Notify';
    $hash->{SetFn}      = 'XiaomiSmartHome_Set';
    $hash->{GetFn}      = 'XiaomiSmartHome_Get';
    $hash->{AttrFn}     = 'XiaomiSmartHome_Attr';
    $hash->{ReadFn}     = 'XiaomiSmartHome_Read';
	$hash->{ReadyFn}    = 'XiaomiSmartHome_Ready';
    $hash->{WriteFn}    = 'XiaomiSmartHome_Write';
	$hash->{AttrList}	= 'disable:1,0 FHEMIP ' .
						  $readingFnAttributes;

	$hash->{MatchList} = { "1:XiaomiSmartHome_Device"   => ".*magnet.*",
						"2:XiaomiSmartHome_Device"      => ".*motion.*",
						"3:XiaomiSmartHome_Device"      => "^.+sensor_ht",
						"4:XiaomiSmartHome_Device"      => ".*switch.*",
						"5:XiaomiSmartHome_Device"      => ".*cube.*",
						"6:XiaomiSmartHome_Device"      => "^.+plug",
						"7:XiaomiSmartHome_Device"      => "^.+86sw1",
						"8:XiaomiSmartHome_Device"      => "^.+86sw2",
						"9:XiaomiSmartHome_Device"      => "^.+ctrl_neutral1",
						"10:XiaomiSmartHome_Device"     => "^.+ctrl_neutral2",
						"11:XiaomiSmartHome_Device"     => "^.+rgbw_light",
						"12:XiaomiSmartHome_Device"     => "^.+curtain",
						"13:XiaomiSmartHome_Device"     => "^.+ctrl_ln1",
						"14:XiaomiSmartHome_Device"     => "^.+ctrl_ln2",
						"15:XiaomiSmartHome_Device"     => "^.+86plug",
						"16:XiaomiSmartHome_Device"     => "^.+natgas",
						"17:XiaomiSmartHome_Device"     => "^.+smoke",
						"18:XiaomiSmartHome_Device"     => "^.+weather.v1",
						"19:XiaomiSmartHome_Device"     => "^.+sensor_motion.aq2",
						"20:XiaomiSmartHome_Device"     => "^.+sensor_wleak.aq1",
						"21:XiaomiSmartHome_Device"     => "^.+vibration",
						"22:XiaomiSmartHome_Device"     => "^.*b186acn01",
						"23:XiaomiSmartHome_Device"     => "^.*b286acn01",
						"24:XiaomiSmartHome_Device"     => "^.*b1acn01"};
	FHEM_colorpickerInit();
}
#####################################
sub XiaomiSmartHome_Read($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
	my $self = {}; # my new hash

	Log3 $name, 5, "$name: Read> Read start";
    if ( ! $hash->{SID} ){
		Log3 $name, 3, "$name: Read> No SID, Stop Read";
		return;
	}
	my $buf = "";
    my $ret = sysread($hash->{CD}, $buf, 1024);
    if (!defined($ret) || $ret <= 0)
    {
        XiaomiSmartHome_disconnect($hash);

        InternalTimer(gettimeofday() + 2, "XiaomiSmartHome_connect", $hash, 0);
        return;
    }
  my $json = $hash->{helper}{JSON}->incr_parse($buf);
	my $decoded = eval{decode_json($buf)};
	if ($@) {
		Log3 $name, 1, "$name: Read> Error while request: $@";
		return;
	}
	if ( ! $decoded ) {
		Log3 $name, 5, "$name: Read> Error no JSON Data " . $buf;
		return;
	}
    if ($json)
    {
    Log3 $name, 5, "$name: Read> [PLAIN] " .  $buf;
		my $rsid = $decoded->{'sid'};
		if ($decoded->{'cmd'} eq 'read_ack' || $decoded->{'cmd'} eq 'report' && $decoded->{'model'} ne 'gateway'|| $decoded->{'cmd'} eq 'heartbeat' && $decoded->{'model'} ne 'gateway' || $decoded->{'cmd'} eq 'write_ack' && $decoded->{'model'} ne 'gateway') {
			# devices does not exist yet
			if (!$modules{XiaomiSmartHome_Device}{defptr}{$rsid}{IODev}->{NAME}){
				Log3 $name, 5, "$name: Read> XiaomiSmartHome_Device unknown trying autocreate" ;
				my $def=$modules{XiaomiSmartHome}{defptr};
				while(my ($key, $value) =each(%$def)){
					XiaomiSmartHome_Write($value, 'get_id_list');
					Log3 $value->{NAME}, 5, "$value->{NAME}: Push to get all Sensors for Gateway $value->{NAME} " . $key;
					if ($value->{helper}{sensors} =~ m/$rsid/ ) {
						Log3 $value->{NAME}, 5, "$value->{NAME}: $rsid is sensor from $value->{NAME}";
						Dispatch($value, $buf, undef);
						return;
						}
				}
			}
			# devices available with proper and HEARTBEAT gw
			elsif ($decoded->{'cmd'} eq 'heartbeat' && $modules{XiaomiSmartHome_Device}{defptr}{$rsid}{IODev}->{NAME} eq $hash->{NAME}) {
				Log3 $name, 5, "$name: Read> Dispatching! " . "SID: " . $rsid . " " . $modules{XiaomiSmartHome_Device}{defptr}{$rsid}{IODev}->{NAME} . " " . $hash->{NAME};
				Dispatch($hash, $buf, undef);
				return;
				}
			elsif ($decoded->{'cmd'} eq 'report' && $modules{XiaomiSmartHome_Device}{defptr}{$rsid}{IODev}->{NAME} eq $hash->{NAME}) {
				Log3 $name, 5, "$name: Read> Dispatching! " . "SID: " . $rsid . " " . $modules{XiaomiSmartHome_Device}{defptr}{$rsid}{IODev}->{NAME} . " " . $hash->{NAME};
				Dispatch($hash, $buf, undef);
				return;
				}
			# Senosoren check change to right GW
			elsif ($decoded->{'cmd'} eq 'read_ack')  {	
				$hash = $modules{XiaomiSmartHome_Device}{defptr}{$rsid}->{IODev};
				Log3 $name, 4, "$name: Read> Dispatching using this GW " . $hash->{NAME} ;
				Dispatch($hash, $buf, undef);
				return;
				}

		}
		# gateway sensor list
		elsif ($decoded->{'cmd'} eq 'get_id_list_ack'){
			$self = $modules{XiaomiSmartHome}{defptr}{$rsid};
			Log3 $name, 5, "$name: Read> Reading Sensorlist with $self->{NAME}" ;
			XiaomiSmartHome_Reading ($self, $buf);
			return;
			}
		# gateway not definded
		elsif (!$modules{XiaomiSmartHome}{defptr}{$rsid}){
			Log3 $name, 1, "$name: Read> GW not defined " . $buf;
			return;
			}
		# gateway defined but not the right modul instance - change
		elsif ( $modules{XiaomiSmartHome}{defptr}{$rsid}->{SID} ne $hash->{SID} ){
			$self = $modules{XiaomiSmartHome}{defptr}{$rsid};
			Log3 $name, 5, "$name: Read> Wrong Modul HASH skipping $self->{NAME}";
			#XiaomiSmartHome_Reading ($self, $buf); no reading anymore!
			return;
			}
		#gateway defined and the right modul instance - nothing to change
		elsif ( $modules{XiaomiSmartHome}{defptr}{$rsid}->{SID} eq $hash->{SID} ){
			Log3 $name, 5, "$name: Read> HASH correctly";
			XiaomiSmartHome_Reading ($hash, $buf);
			return;
		}
	 }
}
#####################################
sub XiaomiSmartHome_Reading ($@) {
	my ($hash, $buf) = @_;
	my $name = $hash->{NAME};
	Log3 $name, 5, "$name: Reading> Reading start";
    my $json = $hash->{helper}{JSON}->incr_parse($buf);
	my $decoded = eval{decode_json($buf)};
	if ($@) {
		Log3 $name, 1, "$name: Reading> Error while request: $@";
		return;
		}
	if ($json){
		if ($decoded->{'cmd'} eq 'report' && $decoded->{'model'} eq 'gateway' || $decoded->{'cmd'} eq 'heartbeat' && $decoded->{'model'} eq 'gateway' || $decoded->{'cmd'} eq 'write_ack'){
					if ($decoded->{'sid'} ne $hash->{SID} ){
						Log3 $name, 5, "$name: Reading> $decoded->{'sid'} not matching with my SID $hash->{SID} skipping $hash->{SID} TT";
						return;
					}
					readingsBeginUpdate( $hash );
					if ($decoded->{'model'} && $decoded->{'model'} eq 'gateway' ){
						if ($decoded->{'cmd'} eq 'report'){
							my $data = eval{decode_json($decoded->{data})};
								if ($@) {
									Log3 $name, 1, "$name: Reading> Error while request: $@";
									return;
								}
							if (defined $data->{rgb}){
								Log3 $name, 3, "$name: Reading>" . " SID: " . $decoded->{'sid'}  . " Type: Gateway" . " RGB: " . $data->{rgb} ;
								readingsBulkUpdate($hash, "RGB", $data->{rgb} , 1 );
								}
							if (defined $data->{illumination}){
								Log3 $name, 3, "$name: Reading>" . " SID: " . $decoded->{'sid'}  . " Type: Gateway" . " Illumination: " . $data->{illumination} ;
								readingsBulkUpdate($hash, "illumination", $data->{illumination} , 1 );
								}
						}
						elsif ($decoded->{'cmd'} eq 'heartbeat'){
							my $data = eval{decode_json($decoded->{data})};
							if ($@) {
								Log3 $name, 1, "$name: Reading> Error while request: $@";
								return;
							}
							if ($data->{ip} eq $hash->{GATEWAY_IP}){
								readingsBulkUpdate($hash, 'heartbeat', $decoded->{'sid'}, 1 );
								readingsBulkUpdate($hash, 'token', $decoded->{'token'}, 1 );
								Log3 $name, 4, "$name: Reading> Heartbeat from $data->{ip} received with $decoded->{'sid'}";
								#$hash->{SID} = $decoded->{'sid'};
							}
							else {
								Log3 $name, 5, "$name: Reading> IP-Heartbeat Data didnt match! $data->{ip}  " . $hash->{GATEWAY_IP} ;
							}
						}
					}
					if ($decoded->{'cmd'} eq 'write_ack'){
						if ($decoded->{'sid'} ne $hash->{SID} ){
							Log3 $name, 5, "$name: Reading> $decoded->{'sid'} not matching with my SID $hash->{SID} skipping";
						return;
						}
						Log3 $name, 4, "$name: Reading> Write answer " . $hash->{GATEWAY} ;
						my $data = eval{decode_json($decoded->{data})};
							if ($@) {
								Log3 $name, 1, "$name: Reading> Error while request: $@";
								return;
							}
						if ($data->{error}){
							readingsBulkUpdate($hash, 'heartbeat', $data->{error}, 1 );
						}
						else {
							readingsBulkUpdate($hash, 'heartbeat', "Write_OK", 1 );
							readingsBulkUpdate($hash, "proto_version", $data->{proto_version} , 1 );
						}
					}
					readingsEndUpdate( $hash, 1 );
					return;
				}
		elsif ($decoded->{'cmd'} eq 'get_id_list_ack'){
			if ($decoded->{'sid'} ne $hash->{SID} ){
				Log3 $name, 5, "$name: Reading> $decoded->{'sid'} not matching with my SID $hash->{SID} skipping $hash";
				return;
			}
			my @sensors = eval{ @{decode_json($decoded->{data})}};
				if ($@) {
					Log3 $name, 1, "$name: Reading> Error while request: $@";
					return;
				}
			my $all_sensors = "";
			foreach my $sensor (@sensors)
				{
				Log3 $name, 4, "$name: Reading> PushRead:" . $sensor;
				XiaomiSmartHome_Write($hash, 'read',  $sensor );
				$all_sensors = $all_sensors . $sensor . ",";
				}
			$hash->{helper}{sensors} = $all_sensors;
			return;
		}
	}

	Log3 $name, 5, "$name: Reading> Dispatch " . $buf;
	Dispatch($hash, $buf, undef);
}
#####################################


sub XiaomiSmartHome_getLocalIP($){

        my ($hash) = @_;
        my $name = $hash->{NAME};
        my $attrFHEMIP = AttrVal($name, 'FHEMIP', undef);
        my $socket;

        if (defined $attrFHEMIP){
                $socket = IO::Socket::INET->new(
                        Proto       => 'udp',
                        LocalAddr   => $attrFHEMIP,
                        PeerAddr    => '8.8.8.8:53',    # google dns
                );
        }else{
                $socket = IO::Socket::INET->new(
                        Proto       => 'udp',
                        PeerAddr    => '8.8.8.8:53',    # google dns
                );
        }
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
	my $ip = $hash->{GATEWAY_IP};
	my $json;
	my $decoded;
	my $timeout = $hash->{TIMEOUT} ? $hash->{TIMEOUT} : 3;
	my $sidsock = IO::Socket::Multicast->new( Proto     => 'udp',LocalAddr => $hash->{FHEMIP}, LocalPort =>'4321', ReuseAddr => 1, Timeout => $timeout) or die "Creating socket: $!\n";
	$sidsock->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 10, 0))   or die "setsockopt: $!";
	if ($sidsock){
		my $msg = '{"cmd":"whois"}';
		$sidsock->mcast_send($msg,$ip . ':4321') or die "send: $!";
		eval {
			$sidsock->recv($msg, 1024)  or die "recv: $!";
			$json = $hash->{helper}{JSON}->incr_parse($msg);
			Log3 $name, 5, "$name: getGatewaySID> Answer $msg";
			$decoded = eval{decode_json($msg)};
			if ($@) {
				Log3 $name, 1, "$name: getGatewaySID> Error while request: $@";
				return;
			}
			if ($json) {
				if ($decoded->{'ip'} eq $ip){
					Log3 $name, 3, "$name: getGatewaySID> Find SID for Gateway: $decoded->{sid}";
					$sidsock->close();
					$hash->{SID} =  $decoded->{sid};
					$modules{XiaomiSmartHome}{defptr}{$decoded->{sid}} = $hash;
					return $decoded->{sid};
					}
				else {
					Log3 $name, 5, "$name: getGatewaySID> whois Data didnt match! $decoded->{sid} $decoded->{'ip'} ". $ip ;
					}
				}
			};
		if ($@) {
			Log3 $name, 1, "$name: getGatewaySID> Error no response from whois!! STOP!!";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
	}
	else {
		Log3 $name, 5, "$name: Did not find a SID for Gateway disconnecting";
		$hash->{STATE} = "Disconnected";
		XiaomiSmartHome_disconnect($hash);
		return undef;
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
		Log3 $name, 1, "$name: Define> Ping ERROR Gateway disconnecting";
		$p->close();
	}
	my $GATEWAY_IP = $param[2];
	my $definition = $param[2];
	$hash->{DEF} = $definition;
	$hash->{NOTIFYDEV} = "global";
	$hash->{NAME}  = $param[0];
	$hash->{VERSION}  = $version;
    $hash->{GATEWAY} = $param[2];
	$hash->{helper}{JSON} = JSON->new->utf8();
	$hash->{FHEMIP} = XiaomiSmartHome_getLocalIP($hash);
	$hash->{STATE} = "initialized";
	$hash->{helper}{host} = $definition;
	if( $hash->{GATEWAY} !~ m/^\d+\.\d+\.\d+\.\d+$/ ){
		eval {
			$GATEWAY_IP = inet_ntoa(inet_aton($hash->{GATEWAY})) ;
			$hash->{GATEWAY_IP} = $GATEWAY_IP;
			Log3 $name, 5, "$name: Define> Set GATEWAYs IP: " .  $GATEWAY_IP;
			};
		if ($@) {
			Log3 $name, 1, "$name: Define> Error $@\n";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
	}
	$hash->{GATEWAY_IP} = $GATEWAY_IP;
	#$modules{XiaomiSmartHome}{defptr}{$GATEWAY_IP} = $hash;
	#$hash->{SID} =  XiaomiSmartHome_getGatewaySID($hash);

	Log3 $name, 5, "$name: Define> $definition";
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
		Log3 $name, 1, "$name: Write> Cannot write iam Disconnected";
		return undef;
		}
	else{
		#Check DNS if IP has changed
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
	elsif ($cmd eq 'get_id_list')
		{
		Log3 $name, 4, "$name: Write> Get all Sensors";
		$msg  = '{"cmd" : "get_id_list"}';
		}
	else {
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
			if ($cmd eq '86power')
				{
				$msg  = '{"cmd":"write","model":"86plug","sid":"' . $iohash->{SID} . '","data":"{\"status\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'ctrl')
				{
				$msg  = '{"cmd":"write","model":"ctrl_neutral1","sid":"' . $iohash->{SID} . '","data":"{\"channel_0\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'ctrl_ln1')
				{
				$msg  = '{"cmd":"write","model":"ctrl_ln1","sid":"' . $iohash->{SID} . '","data":"{\"channel_0\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
			}
			if ($cmd eq 'channel_0')
				{
				$msg  = '{"cmd":"write","model":"ctrl_neutral2","sid":"' . $iohash->{SID} . '","data":"{\"channel_0\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'channel_1')
				{
				$msg  = '{"cmd":"write","model":"ctrl_neutral2","sid":"' . $iohash->{SID} . '","data":"{\"channel_1\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'ctrl_ln2_0')
				{
				$msg  = '{"cmd":"write","model":"ctrl_ln2","sid":"' . $iohash->{SID} . '","data":"{\"channel_0\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'ctrl_ln2_1')
				{
				$msg  = '{"cmd":"write","model":"ctrl_ln2","sid":"' . $iohash->{SID} . '","data":"{\"channel_1\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
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
			if ($cmd eq 'status')
				{
				$msg  = '{"cmd":"write","model":"curtain","sid":"' . $iohash->{SID} . '","data":"{\"status\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'level')
				{
				$msg  = '{"cmd":"write","model":"curtain","sid":"' . $iohash->{SID} . '","data":"{\"curtain_level\":\"' . $val . '\",\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			if ($cmd eq 'learn')
				{
				my $t = '"yes"';
				$msg  = '{"cmd":"write","model":"gateway","sid":"' . $hash->{SID} . '","data":"{\"join_permission\":' . $t . ',\"key\":\"'. XiaomiSmartHome_EncryptKey($hash) .'\"}" }';
				}
			}
		}
	return Log3 $name, 4, "$name: Write> - socket not connected" unless($hash->{CD});
    Log3 $name, 4, "$name: Write> $msg " . $GATEWAY;
	my $sock = $hash->{CD};
	my $MAXLEN  = 1024;
	$sock->mcast_send($msg,$GATEWAY .':9898') or die "send: $!";
    Log3 $name, 4, "$name: Write> End " . $GATEWAY;
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

sub XiaomiSmartHome_Ready($)
{
	my ($hash) = @_;
      
	# Versuch eines Verbindungsaufbaus, sofern die Verbindung beendet ist.
	return DevIo_OpenDev($hash, 1, undef ) if ( $hash->{helper}{ConnectionState} eq "Disconnected" );

	# This is relevant for Windows/USB only
	if(defined($hash->{USBDev})) {
		my $po = $hash->{USBDev};
		my ( $BlockingFlags, $InBytes, $OutBytes, $ErrorFlags ) = $po->status;
		return ( $InBytes > 0 );
	}
}
#####################################

sub XiaomiSmartHome_Get($@)
{
	my ($hash , $name, $opt, $args ) = @_;

	if ($opt eq "UpdateAll")
		{
		XiaomiSmartHome_updateAllReadings($hash);
		Log3 $name, 3, "$name: Get> UpdateALLReadings Started";
		return "UpdateALLReadings Started";
		}
	elsif($opt eq "UpdateSingle")
		{
		XiaomiSmartHome_updateSingleReading($hash,$args);
		Log3 $name, 3, "$name: Get> UpdateSingel Started";
		return "UpdateSingel " . $args . " Started";
		}
	else
	{
		return "unknown argument $opt choose one of UpdateAll:noArg UpdateSingle";
	}
}
#####################################

sub XiaomiSmartHome_Notify($$)
{
 	my ($hash, $dev_hash) = @_;
	my $ownName = $hash->{NAME}; # own name / hash
	#my $evName = $dev_hash->{NAME}; # triggered device
	#my $rsid = $dev_hash->{SID};
	Log3 $ownName, 5, "$ownName: Notify> NotifyStart";# . $rsid . " " . $evName;
	
	# gateway defined but not the right modul instance
	#if ( $modules{XiaomiSmartHome}{defptr}{$rsid}->{SID} ne $hash->{SID} ){
	#	Log3 $ownName, 5, "$ownName: Notify> Wrong Event-Modul HASH skipping " . $evName;
	#	#XiaomiSmartHome_Reading ($self, $buf);
	#	return;
	#}

	
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
	$attr{$hash->{NAME}}{webCmd} = "pct:rgb:rgb ff0000:rgb 00ff00:rgb 0000ff:on:off" if ( ! $attr{$hash->{NAME}}{webCmd} || $attr{$hash->{NAME}}{webCmd} eq "rgb:rgb ff0000:rgb 00ff00:rgb 0000ff:on:off" );
	readingsSingleUpdate($hash, "pct", 100, 1) if ( ! $hash->{READINGS}{pct}{VAL});
	readingsSingleUpdate($hash, "ringtone", 21, 1) if ( ! $hash->{READINGS}{ringtone}{VAL});
	readingsSingleUpdate($hash, "volume", 10, 1) if ( ! $hash->{READINGS}{volume}{VAL});
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		Log3 $ownName, 5, "$ownName: Notify> Starting Connect after global";
		XiaomiSmartHome_connect($hash) if ($hash->{SID});
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
	elsif($cmd eq "learn")
	{
		XiaomiSmartHome_Write($hash,'learn', 1);
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
	elsif($cmd eq "ringtone" || $cmd eq "ringvol" )
	{
		my $ownName = $hash->{NAME};
		Log3 $ownName, 4, "$ownName: Set> $cmd, $args[0]";
		readingsSingleUpdate( $hash, 'ringtone', $args[0], 1 );
		if ($args[1]){
			readingsSingleUpdate( $hash, 'volume', $args[1], 1 );
		}
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
			Log3 $name, 5, "$name: Connect> Set GATEWAYs IP: " .  $GATEWAY_IP;
			};
		if ($@) {
			Log3 $name, 1, "$name: Connect> Error $@\n";
			$hash->{STATE} = "Disconnected";
			XiaomiSmartHome_disconnect($hash);
			return undef;
			}
		}
    XiaomiSmartHome_getGatewaySID($hash);
	my $timeout = $hash->{TIMEOUT} ? $hash->{TIMEOUT} : 3;
	my $sock = IO::Socket::Multicast->new( Proto     => 'udp', LocalPort =>'9898', ReusePort => 1, ReuseAddr => 1, Timeout => $timeout) or die "Creating socket: $!\n";
	$sock->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 30, 0))   or die "setsockopt: $!";
	if ($sock)
	{
		Log3 $name, 3, "$name: connect> Connected";
		$sock->mcast_add('224.0.0.50', $hash->{FHEMIP} ) || die "Couldn't set group: $!\n"; #$hash->{FHEMIP}
		$sock->mcast_ttl(32);
		$sock->mcast_loopback(1);
		$hash->{helper}{ConnectionState} = "Connected";
		#$hash->{SID} = XiaomiSmartHome_getGatewaySID($hash);
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
    Log3 $name, 1, "$name: disconnect> disconnecting";

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
	Log3 $name, 5, "$name: updateAllReadings> Starting UpdateALLReadings";
	my $GATEWAY;
	my $p = Net::Ping->new();
	if ( ! $p->ping($hash->{GATEWAY})){
		Log3 $name, 1, "$name: updateAllReadings> Ping to $hash->{helper}{host} failed";
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


1;

=pod
=item device
=item summary Module to control XiaomiSmartHome Gateway
=item summary_DE Modul zum steuern des  XiaomiSmartHome Gateway


=begin html

<a name="XiaomiSmartHome"></a>
<h3>XiaomiSmartHome</h3>
<ul>
    <i>XiaomiSmartHome</i> implements the XiaomiSmartHome Gateway and Sensors.
    <a name="XiaomiSmartHome"></a>
	<br/>
	<b>Prerequisite</b>
	<ul>
		<li>Installation of the following packages: apt-get install libio-socket-multicast-perl libjson-perl libcrypt-cbc-perl</li>
		<li>And with CPAN: cpan Crypt::Cipher::AES</li>
	</ul>
	<br/>
	<b>Define</b>
    <ul>
        <code>define &lt;name&gt; XiaomiSmartHome &lt;IP or Hostname&gt;</code>
        <br><br>
        Example: <code>define XiaomiSmartHome XiaomiSmartHome 192.168.1.xxx</code>
        <br><br>
    </ul>
	<br/>
	<b>Set Developermode on the gateway!</b>
    <ul>
		<p>Without the developer mode, no communication with the XiaomiSmartHome gateway is possible.
		<br/>You need an android or ios device. You must often click on the APP versionsnumber to activate the hidden menu.
		<br/>Here is how to turn on the developer mode.
		<br/>Android -> https://louiszl.gitbooks.io/lumi-gateway-local-api/content/device_discover.html
		<br/>IOS go here -> https://github.com/fooxy/homeassistant-aqara/wiki/Enable-dev-mode
		<br/>The password shown in the app must set on the FHEM XioamiSmartHome Gatewaydevice!</p>
    </ul>
	<br/>
	<b>Supported Sensors</b>
	<ul>
		<li>magnet: Window/Door magnetic sensor</li>
		<li>motion: Human body motion sensor</li>
		<li>sensor_motion.aq2: Aqara Human body motion sensor with lux readings</li>
		<li>sensor_ht: Temperature and humidity sensor</li>
		<li>weather.v1: Aqara Temperature, pressure and humidity sensor</li>
		<li>switch: Wireless sensor switch</li>
		<li>plug & 86plug: Smart socket</li>
		<li>cube: Cube sensor</li>
		<li>86sw1: Wireless switch single</li>
		<li>86sw2: Wireless switch double</li>
		<li>ctrl_neutral1: Single bond ignition switch</li>
		<li>ctrl_neutral2: Double bond ignition switch</li>
		<li>rgbw_light: Smart lights (report only)</li>
		<li>curtain: Curtain (Control only if device has reporte curtain_level)</li>
		<li>water: water detector</li>
		<li>smoke: smoke alarm detector</li>
		<ul>
			<li>0: disarm</li>
			<li>1: alarm</li>
			<li>8: battery alarm</li>
			<li>64: alarm sensitivity</li>
			<li>32768: ICC communication failure</li>
		</ul>
		<li>gas: gas alarm detector</li>
		<ul>
			<li>0: disarm</li>
			<li>1: alarm</li>
			<li>2: analog alarm</li>
			<li>64: alarm sensitivity</li>
			<li>32768: ICC communication failure</li>
		</ul>
	</ul>
	<br/>
	<b>Heartbeat</b>
	<ul>
		<li>The XiaomiSmartHome Gateway send every 10 seconds a heartbeat</li>
		<li>The XiaomiSmartHome Devices send every 60 minutes</li>
		<li>The Reading heartbeat will show the SID if a heartbeat received</li>
	</ul>
	<br/>
	<b>Set: Gateway</b>
	<ul>
		<li>password: without password no write to the gateway is possible. Use the MI APP to find the password</li>
		<li>RGB(Colorpicker): set the color</li>
		<li>PCT(Slider): set the brightness in percent</li>
		<li>intervals: set the gateway to on for an time eg. set intervals 07:00-08:00</li>
		<li>ringtone: set the ringtone 0-8,13,21-29,10001-.. | 10000 = off</li>
		<li>volume: set the volume 1-100, (100 is very loud)</li>
		<li>ringvol: set ringtone and volume in on step e.g. set [GWNAME] ringvol 21 10</li>
		<li>learn: set the gateway in learningmode to learn new sensors now push the button from the new sensor</li>
	</ul>
	<br/>
	<b>Set: Devices</b>
	<ul>
		<li>motionOffTimer:  (only motionsensor)
		<br/>You can set a motion Off Timer Attribut on the motion sensor device. You can set 1, 5 or 10 seconds after
		<br/>the motion sensors will automatically set to off. MotionOffTimer is set to 5 by default.
		<br/>Background: The motionsensors does not send off immediately.
		<br/>The Motionsensor send a no_motion after 120, 180, 300, 600, 1200 seconds no motion is detected.</li>
		<li>Power: (only smart soket) on off switch a plug on or off</li>
		<li>ctrl: (only single wirless switch) on off switch </li>
		<li>channel_0: (only double wirless switch) on off switch </li>
		<li>channel_1: (only double wirless switch) on off switch </li>
	</ul>
</ul>

=end html

=begin html_DE

<a name="XiaomiSmartHome"></a>
<h3>XiaomiSmartHome</h3>
<ul>
    <i>XiaomiSmartHome</i> Steuern des XiaomiSmartHome Gateway und deren verbundener Sensoren.
    <a name="XiaomiSmartHome"></a>
	<br/>
	<b>Voraussetzungen</b>
	<ul>
		<li>Diese Pakete m&uuml;ssen installiert sein: apt-get install libio-socket-multicast-perl libjson-perl libcrypt-cbc-perl</li>
		<li>Und mit CPAN: cpan Crypt::Cipher::AES</li>
	</ul>
	<br/>
	<b>Define</b>
    <ul>
        <code>define &lt;name&gt; XiaomiSmartHome &lt;IP oder Name&gt;</code>
        <br><br>
        Example: <code>define XiaomiSmartHome XiaomiSmartHome 192.168.1.xxx</code>
        <br><br>
    </ul>
	<br/>
	<b>Entwicklermodus am Gateway setzen!</b>
    <ul>
		<p>Ohne Entwicklermodus ist keine Kommunikation mit dem Gateway m&ouml;glich.
		<br/>Zum setzen des Entwicklermodusses braucht man ein android oder ios Ger&auml;t mit installierter MI APP.
		<br/>Um das versteckte Men&uuml; zu &ouml;ffnen muss man mehrmals auf die Versionsnummer der MI APP klicken.
		<br/>Hier finden Sie eine Anleitung mit Bildern.
		<br/>Android -> https://louiszl.gitbooks.io/lumi-gateway-local-api/content/device_discover.html
		<br/>IOS  -> https://github.com/fooxy/homeassistant-aqara/wiki/Enable-dev-mode
		<br/>Das Passwort welches in der MI APP angezeigt wird muss im FHEM XiaomiSmartHome Gateway Device gesetzt werden!</p>
    </ul>
	<br/>
	<b>Unterstütze Sensoren</b>
	<ul>
		<li>magnet: Magnetischer Fenster/T&uuml;r Sensor</li>
		<li>motion: Bewegungsmelder</li>
		<li>sensor_ht: Temperatur und Luftdruck</li>
		<li>switch: Funkschalter</li>
		<li>plug & 86plug: Schaltbare Funksteckdose</li>
		<li>cube: W&uuml;rfel Sensor</li>
		<li>86sw1: Einfacher Wandfunkschalter</li>
		<li>86sw2: Wandfunkschalter doppelt</li>
		<li>ctrl_neutral1: Einfacher Wandschalter schaltbar</li>
		<li>ctrl_neutral2: Doppelter Wandschalter schaltbar</li>
		<li>rgbw_light: RBGW Lampe (nur Anzeige)</li>
		<li>curtain: Vorhangmotor (ohne dass das Device den curtain_level gemeldet hat ist ein Steuern nicht m&ouml;glich)</li>
		<li>water: Wasser Sensor</li>
		<li>smoke: Rauchmelder</li>
		<ul>
			<li>0: disarm</li>
			<li>1: alarm</li>
			<li>8: battery alarm</li>
			<li>64: alarm sensitivity</li>
			<li>32768: ICC communication failure</li>
		</ul>
		<li>gas: Gasmelder</li>
		<ul>
			<li>0: disarm</li>
			<li>1: alarm</li>
			<li>2: analog alarm</li>
			<li>64: alarm sensitivity</li>
			<li>32768: ICC communication failure</li>
		</ul>
	</ul>
	<br/>
	<b>Heartbeat</b>
	<ul>
		<li>Das XiaomiSmartHome Gateway sendet alle 10 seconds einen heartbeat</li>
		<li>Jedes XiaomiSmartHome Devices sendet alle 60 Minuten einen heartbeat</li>
		<li>Das Reading heartbeat wird mit der SID des jeweiligen Gerätes beim Empfang eines Heartbeat aktualisiert</li>
	</ul>
	<br/>
	<b>Set: Gateway</b>
	<ul>
		<li>password: Ohne Passwort ist ein Schalten des GATEWAY nicht m&ouml;glich. Das Passwort findet man in der MI APP</li>
		<li>RGB(Colorpicker): Einstellen der LED Farbe des Gateways</li>
		<li>PCT(Slider): Einstellen der Helligkeit des Gateways</li>
		<li>intervals: Einschalten des Gateways für einen Zeitraum zb. set intervals 07:00-08:00</li>
		<li>ringtone: Wiedergeben eines Alarmtones 0-8,13,21-29,10001-.. Benutzerdefinierte| 10000 = aus</li>
		<li>volume: Einstellen der Lautst&auml;rke des Alarmtones 1-100, (100 ist sehr laut!)</li>
		<li>ringvol: Wiedergeben eines Arlamtones und gleichzeitiges ver&auml;ndern der Lautst&auml;rke set [GWNAME] ringvol 21 10</li>
		<li>learn: Anlernen neuer Sensoren, nach dem Set an dem neuen Sensor den Button dr&uuml;cken</li>
	</ul>
	<br/>
	<b>Set: Devices</b>
	<ul>
		<li>motionOffTimer:  (nur Bewegungsmelder)
		<br/>Durch setzen des Parameters ist es m&ouml;glich, dass das Reading des Bewegungsmelder nach 1, 5 oder 10 Sekunden
		<br/>automatisch wieder auf off gestellt wird.
		<br/>Hintergrund: Der Bewegungsmelder sendet selber kein off.
		<br/>Der Bewegungsmelder sendet no_motion nach 120, 180, 300, 600, 1200 Sekunden, wenn keine Bewegung festgestellt wurde.</li>
		<li>Power: (nur Funksteckdose) on off Funksteckdose ein oder ausschalten</li>
		<li>ctrl: (nur Funkschalter) on off Funkschalter </li>
		<li>channel_0: (nur Doppelter Wandschalter schaltbar) ein oder ausschalten </li>
		<li>channel_1: (nur Doppelter Wandschalter schaltbar) ein oder ausschalten </li>
	</ul>
</ul>

=end html_DE


=cut

