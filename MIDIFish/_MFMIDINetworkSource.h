//
//  _MFMIDINetworkSource.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <CoreMIDI/MIDINetworkSession.h>
#import "MFProtocols.h"
#import "_MFMIDINetworkConnection.h"

@interface _MFMIDINetworkSource : _MFMIDINetworkConnection <MFMIDISource>

@end
