# MIDIFish

Translating the arcane language of CoreMIDI into one natural to iOS.

## Features ##

* High level semantics for MIDI operations, e.g. `sendPitchbend`
* Normalises the API for Network, Hardware/App, and Virtual connections  
* Network MIDI scanning made easy(er)
* UserDefaults stores and restores manual network connections
* Arbitrary number of virtual source/destinations
* API Simplicity with optional granularity,
* Public exposure of CoreMIDI objects for digging deeper


## Usage ##

### Basic Usage ###

````
_midiSession = [MFMIDISession sessionWithName:@"Your App Name"];
_midiSession.networkEnabled = YES;
_midiSession.restorePreviousConnectionStates = YES;
_midiSession.autoEnableDestinations = YES;
_midiSession.channel = 0;
        
// Create the Virtual Source to expose to other apps
[_midiSession createVirtualSourceWithName:_midiSession.name]; // disabled by default

// ...some time later...
[_midiSession sendNoteOn:64 velocity:127];
[_midiSession sendPitchbend:0x3FFF];
// etc

````

For more, see the `MFMIDISession.h`.


## Terminology ##

_Connection:_ A source or destination for MIDI Messages
_Message_: NoteOn, NoteOff, CC, Pitchbend, Program Change, Channel Aftertouch, Poly Aftertouch, Sysex

_Virtual Source/Destination_: Connections which we create in the app with a specified name which show up in other apps. Keep in mind that when the app is a VirtualSource it means it is a MIDISource for *other* apps. Locally it appears as a MIDIDestination because we output to it

_ connect vs enable:_ "Connect" refers to discovering the existence of a physical/virtual/wifi connection. All devices are auto-connected so-to-speak in that they are discovered by the system scan. "Enable" indicates whether they send/receive midi messages when you send them through MIDISession. This is slightly confusing in the code as "en/disabling" a Network Connection does indeed "connect/disconnect" the host from the MIDINetworkSession (see notes above). This is one example of the abnormal lingo in CoreMIDI that MIDIFish seeks to normalise.

## Connection Persistence ##

Setting `restorePreviousConnectionStates` causes previous connections, when re-discovered, to be enabled/disabled based on their value from a previous run of the app. Currently, it does NOT restore Virtual Connections or IP based network ones which were discovered


## Special Notes ##

- Network Connections have their Sources and Destinations coupled such that enabling/disabling one enables/disables the other. 

- MIDINetworkHost's created with NSNetService's discovered by Bonjour are currently unreliable. I believe this is due to an IPv6 address being interpreted as IPv4 (0.0.0.0:5004) the actual IPv4 address (NSNetService::resolve results in 2 address) is ignored. In the client, we manually resolve the NSNetService and then connect with a MIDINetworkHost instantiated with IP/Port. (See https://developer.apple.com/library/mac/qa/qa1298/_index.html)

