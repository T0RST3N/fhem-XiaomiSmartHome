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

my $version = "0.10";
sub XiaomiSmartHome_Device_updateSReading($);

#####################################

sub XiaomiSmartHome_Device_Initialize($)
{
  my ($hash) = @_;
  
  $hash->{Match}     = "^.+magnet|motion|sensor_ht|switch|plug|cube";
  $hash->{DefFn}     = "XiaomiSmartHome_Device_Define";
  $hash->{SetFn}     = "XiaomiSmartHome_Device_Set";
  $hash->{UndefFn}   = "XiaomiSmartHome_Device_Undef";
  $hash->{ParseFn}   = "XiaomiSmartHome_Device_Parse";

  $hash->{AttrList}  = "IODev follow-on-for-timer:1,0 follow-on-timer ".
                       "do_not_notify:1,0 ignore:1,0 dummy:1,0 showtime:1,0 valueFn:textField-long motionOffTimer:1,5,10 ".
                       $readingFnAttributes ;
}
#####################################

sub XiaomiSmartHome_Device_mot($$)
{
	my ($hash, $mot) = @_;

	InternalTimer(gettimeofday()+$mot, "XiaomiSmartHome_Device_on_timeout",$hash, 0);
	# on-for-timer is now a on.


}
#####################################

sub XiaomiSmartHome_Device_Set($@)
{
	my ( $hash, $name, $cmd, @args ) = @_;

	return "\"set $name\" needs at least one argument" unless(defined($cmd));
	
	my $setlist = "";
	$setlist .= "power:on,off " if ($hash->{MODEL} eq 'plug');
	
	if($cmd eq "power")
	{
	   if($args[0] eq "on")
	   {
			IOWrite($hash,"power","on",$hash);
	   }
	   elsif($args[0] eq "off")
	   {
			IOWrite($hash,"power","off",$hash);
	   }
	}
	else
	{
		return "Unknown argument $cmd, choose one of $setlist";
	}
}


#####################################

sub XiaomiSmartHome_Device_on_timeout($){
	my ($hash) = @_;
	my $name = $hash->{LASTInputDev};
	if ($hash->{STATE} eq 'motion') {
		readingsSingleUpdate($hash, "state", "off", 1 );
		Log3 $name, 3, "$name>" . " SID: " . $hash->{SID} . " Type: " . $hash->{MODEL}  . " Status: off";
		}
}
#####################################
sub XiaomiSmartHome_Device_Read($$$){
	my ($hash, $msg, $name) = @_;
	my $decoded = decode_json($msg);
	
	my $sid = $decoded->{'sid'};
	my $model = $decoded->{'model'};
	Log3 $name, 5, "$name: SID: " . $hash->{SID} . " " . $hash->{TYPE};
	my $data = decode_json($decoded->{data});
	readingsBeginUpdate( $hash );
	if (defined $data->{status}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " Status: " . $data->{status};
		readingsBulkUpdate($hash, "state", "$data->{status}", 1 );
		if ($data->{status} eq 'motion' && $hash->{MODEL} eq 'motion'){
			readingsBulkUpdate($hash, "no_motion", "0", 1 );
			}		
		if ($data->{status} eq 'close' && $hash->{MODEL} eq 'magnet'){
			readingsBulkUpdate($hash, "no_close", "0", 1 );
			}
	if(defined $data->{no_motion}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " NO_motion: " . $data->{no_motion};
		readingsBulkUpdate($hash, "no_motion", "$data->{no_motion}", 1 );
		}
	if(defined $data->{no_close}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " NO_close: " . $data->{no_close};
		readingsBulkUpdate($hash, "no_close", "$data->{no_close}", 1 );
		}
	if(defined $data->{voltage}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " Voltage: " . $data->{voltage};
		readingsBulkUpdate($hash, "voltage", "$data->{voltage}", 1 );
		}
	if(defined $data->{temperature}){
		my $temp = $data->{temperature};
		$temp =~ s/(^[-+]?\d+?(?=(?>(?:\d{2})+)(?!\d))|\G\d{2}(?=\d))/$1./g;
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " Temperature: " . $temp;
		readingsBulkUpdate($hash, "temperature", "$temp", 1 );
		}
	if(defined $data->{humidity}){
		my $hum = $data->{humidity};
		$hum =~ s/(^[-+]?\d+?(?=(?>(?:\d{2})+)(?!\d))|\G\d{2}(?=\d))/$1./g;
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " Humidity: " . $hum;
		readingsBulkUpdate($hash, "humidity", "$hum", 1 );
		}
	#plug start
	if(defined $data->{load_voltage}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " LOAD_Voltage: " . $data->{load_voltage};
		readingsBulkUpdate($hash, "LOAD_Voltage", "$data->{load_voltage}", 1 );
		}
	if(defined $data->{load_power}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " LOAD_Power: " . $data->{load_power};
		readingsBulkUpdate($hash, "LOAD_Power", "$data->{load_power}", 1 );
		}
	if(defined $data->{power_consumed}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " POWER_Consumed: " . $data->{power_consumed};
		readingsBulkUpdate($hash, "POWER_Consumed", "$data->{power_consumed}", 1 );
		}
	if(defined $data->{inuse}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " InUse: " . $data->{inuse};
		readingsBulkUpdate($hash, "inuse", "$data->{inuse}", 1 );
		}
	#plug end
	#cube start
	if(defined $data->{rotate}){
		Log3 $name, 3, "$name>" . " SID: " . $sid . " Type: " . $hash->{MODEL}  . " Rotate: " . $data->{rotate};
		readingsBulkUpdate($hash, "rotate", "$data->{rotate}", 1 );
		}
	#cube end	
	}
	if ($decoded->{'cmd'} eq 'heartbeat'){
		readingsBulkUpdate($hash, 'heartbeat', $decoded->{'sid'} , 1 );
		}
	readingsEndUpdate( $hash, 1 );
	XiaomiSmartHome_Device_update($hash);
	return $hash->{NAME};


}
#####################################

sub XiaomiSmartHome_Device_Parse($$) {
	my ($io_hash, $msg) = @_;
	my $decoded = decode_json($msg);
	
	my $sid = $decoded->{'sid'};
	my $model = $decoded->{'model'};
	my $name = $io_hash->{NAME};
	
	if (my $io_hash = $modules{XiaomiSmartHome_Device}{defptr}{$sid})
	{
		Log3 $name, 4, "$name>  IS DEFINED " . $model . " : " .$sid;
		XiaomiSmartHome_Device_Read($io_hash, $msg, $name);
	}
	else
	{

		Log3 $name, 4, "$name> UNDEFINED " . $model . " : " .$sid;
		return "UNDEFINED XMI_$sid XiaomiSmartHome_Device $sid $model $name";
	}
}
#####################################

sub XiaomiSmartHome_Device_update($){
  my ($hash) = @_;
  my $model = $hash->{MODEL};
  my $name = $hash->{NAME};
  my $value_fn = AttrVal( $name, "valueFn", "" );
  my $mot =  AttrVal( $name, "motionOffTimer", "" );
  if( $value_fn =~ m/^{.*}$/s ) {

    my $LASTCMD = ReadingsVal($name,"lastCmd",undef);

    my $value_fn = eval $value_fn;
    Log3 $name, 3, $name .": valueFn: ". $@ if($@);
    return undef if( !defined($value_fn) );
  }
  if( $model eq 'motion') {
	XiaomiSmartHome_Device_mot($hash, $mot) if( $mot);
	}
}
#####################################
 

sub XiaomiSmartHome_Device_Define($$) {
	my ($hash, $def) = @_;
	my ($name, $modul, $sid, $type, $iodev) = split("[ \t]+", $def);
	#Log3 "test", 3, "Define status = " . $status;
  	$hash->{TYPE} = $modul;
	$hash->{MODEL} = $type;
	$hash->{SID} = $sid;
	$hash->{NAME} = $name;
	$hash->{VERSION}  = $version;
	$hash->{STATE} = 'initialized';
	$modules{XiaomiSmartHome_Device}{defptr}{$sid} = $hash;
	AssignIoPort($hash,$iodev);
	
	if(defined($hash->{IODev}->{NAME})) {
        my $IOname = $hash->{IODev}->{NAME};
		Log3 $name, 3, $IOname . "> " .$name. ": " . $type . " I/O device is " . $hash->{IODev}->{NAME};
      } else {
           Log3 $name, 1, "$name $type - no I/O device";
    }
    $iodev = $hash->{IODev}->{NAME};
       
    my $d = $modules{XiaomiSmartHome_Device}{defptr}{$name};
    
    return "XiaomiSmartHome device $hash->{SID} on XiaomiSmartHome $iodev already defined as $d->{NAME}." if( defined($d) && $d->{IODev} == $hash->{IODev} && $d->{NAME} ne $name );

    Log3 $name, 3, $iodev . "> " . $name . ": defined as ". $hash->{MODEL};
    $attr{$name}{room} = "MiSmartHome" if( !defined( $attr{$name}{room} ) );
    if( $type eq 'motion') {
		$attr{$name}{devStateIcon}  = 'motion:motion_detector@red off:motion_detector@green no_motion:motion_detector@green' if( !defined( $attr{$name}{devStateIcon} ) );
	}
	elsif ( $type eq 'magnet') {
		$attr{$name}{devStateIcon}  = 'open:fts_door_open@red close:fts_door@green' if( !defined( $attr{$name}{devStateIcon} ) );
	}
	elsif ( $type eq 'sensor_ht') {
		$attr{$name}{stateFormat}  = 'temperature °C, humidity %' if( !defined( $attr{$name}{stateFormat} ) );
	}		
	
	if( $init_done ) {
		InternalTimer( gettimeofday()+int(rand(2)), "XiaomiSmartHome_Device_updateSReading", $hash, 0 );
		Log3 $name, 4, $iodev . "> " . $name . " Init Done set InternalTimer for Update";
	}
	return undef;
}
#####################################
sub XiaomiSmartHome_Device_updateSReading($) {

    my $hash        = shift;
	#my $name = $hash->{NAME};
	#Log3 $name, 3, $name . " Updae SR";
	RemoveInternalTimer($hash,'XiaomiSmartHome_Device_updateSReading');
    IOWrite($hash,'read',"$hash->{SID}");
}
#####################################

#####################################
sub XiaomiSmartHome_Device_Undef($)
{
	my ($hash, $arg) = @_; 
	my $name = $hash->{NAME};
	my $iodev = $hash->{IODev}->{NAME};
	RemoveInternalTimer($hash);
	delete($modules{XiaomiSmartHome_Device}{defptr}{$hash->{SID}});
    Log3 $name, 3, "$iodev> $name - device deleted";
    return undef;

}
1;
#####################################
=pod
=begin html

<a name="XiaomiSmartHome_Device"></a>
<h3>XiaomiSmartHome_Device</h3>


=end html

=cut