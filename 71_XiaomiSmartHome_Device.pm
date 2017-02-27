# 71_XiaomiSmartHome_Device.pm 2017-08-02 13:07:33Z torte $
package main;

use strict;
use warnings;

#####################################

sub XiaomiSmartHome_Device_Initialize($)
{
  my ($hash) = @_;
  
  $hash->{Match}     = "^.+magnet|motion|sensor_ht";
  $hash->{DefFn}     = "XiaomiSmartHome_Device_Define";
  #$hash->{SetFn}     = "XiaomiSmartHome_Device_Set";
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

sub XiaomiSmartHome_Device_on_timeout($){
	my ($hash) = @_;
	readingsSingleUpdate($hash, "state", "off", 1 );
}
#####################################



sub XiaomiSmartHome_Device_Parse($$) {
	my ($io_hash, $msg) = @_;
	my $decoded = decode_json($msg);
	
	my $sid = $decoded->{'sid'};
	my $model = $decoded->{'model'};
	
	if (my $hash = $modules{XiaomiSmartHome_Device}{defptr}{$sid})
	{
		my $name = $hash->{NAME};
		Log3 $name, 5, "$name: SID: " . $hash->{SID} . " " . $hash->{TYPE};
		my @status = split('\"', $decoded->{'data'});
		if ($status[1] eq 'status'){
			Log3 $name, 3, "$name:  Sensor: " . $hash->{MODEL} . " SID: " . $sid . " Status: " . $status[3];
			readingsSingleUpdate($hash, "state", "$status[3]", 1 );
			}
		elsif($status[1] eq 'voltage'){
			Log3 $name, 3, "$name:  Sensor: " . $hash->{MODEL} . " SID: " . $sid . " Voltage: " . $status[3];
			readingsSingleUpdate($hash, "voltage", "$status[3]", 1 );
			}
		elsif($status[1] eq 'temperature'){
			Log3 $name, 3, "$name:  Sensor: " . $hash->{MODEL} . " SID: " . $sid . " Temperature: " . $status[3];
			readingsSingleUpdate($hash, "temperature", "$status[3]", 1 );
			$status[3] =~ s/(^[-+]?\d+?(?=(?>(?:\d{2})+)(?!\d))|\G\d{2}(?=\d))/$1./g;
			readingsSingleUpdate($hash, "temperatureP", "$status[3]", 1 );
			}
		elsif($status[1] eq 'humidity'){
			Log3 $name, 3, "$name:  Sensor: " . $hash->{MODEL} . " SID: " . $sid . " Humidity: " . $status[3];
			readingsSingleUpdate($hash, "humidity", "$status[3]", 1 );
			}
		XiaomiSmartHome_Device_update($hash);
		return $hash->{NAME};
	}
	else
	{
		return "UNDEFINED $sid XiaomiSmartHome_Device $model $sid";
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
    my ($name, $modul, $type, $sid) = split("[ \t]+", $def);
    Log3 $name, 3, "$name: $modul $type $sid";
	$hash->{TYPE} = $modul;
	$hash->{MODEL} = $type;
	$hash->{SID} = $sid;
	$hash->{NAME} = $sid;
	$hash->{STATE} = "initialized";
	$modules{XiaomiSmartHome_Device}{defptr}{$sid} = $hash;
	AssignIoPort($hash);

}

sub XiaomiSmartHome_Device_Undef($)
{
	my ($hash, $arg) = @_; 
	RemoveInternalTimer($hash);
	delete($modules{XiaomiSmartHome_Device}{defptr}{$hash->{SID}});
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