//
//  MFMIDISource.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>
#import "MFProtocols.h"
#import "_MFMIDIEndpointConnection.h"
#import "MFMIDIMessage.h"

@interface _MFMIDIEndpointSource : _MFMIDIEndpointConnection <MFMIDISource>

@end


