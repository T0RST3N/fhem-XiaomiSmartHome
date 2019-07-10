# fhem-XiaomiSmartHome Gateway
With this module, the Xiaomi Smarthome Gateway is bound to FHEM. The module listens for multicast messages from the gateway. 
Changing and switching the LED from the gateway and changing ringtone and volume of the gateway is also possible

* Please read the Wiki !! you need to install some Perl modules.
* https://github.com/T0RST3N/fhem-XiaomiSmartHome/wiki

# Supported Sensors
* magnet: Window/Door magnetic sensor
* motion: Human body motion sensor
* sensor_motion.aq2: Aqara Human body motion sensor with lux readings
* sensor_ht: Temperature and humidity sensor
* weather.v1: Aqara Temperature, pressure and humidity sensor
* switch: Wireless sensor switch
* plug & 86plug: Smart socket
* cube: Cube sensor
* 86sw1: Wireless switch single
* 86sw2: Wireless switch double
* ctrl_neutral1: Single bond ignition switch
* ctrl_neutral2: Double bond ignition switch
* rgbw_light: Smart lights (report only)
* curtain: Curtain (Control only if device has reporte curtain_level)
* wleak: Watersensor
* smoke: smoke alarm detector
* * 0: disarm
* * 1: arlarm
* * 8: battery arlarm
* * 64: arlarm sensitivity
* * 32768: ICC communication failure
* gas: gas alarm detector
* * 0: disarm
* * 1: arlarm
* * 2: analog arlarm
* * 64: arlarm sensitivity
* * 32768: ICC communication failure
* vibration: Detect vibration

# A BIG ThankYOU to my Supporters
* StefanB from Coburg
* Hendrik S
* Karsten B
* Juergen K
* FHEM-Wohnung
* Chrisnitt
