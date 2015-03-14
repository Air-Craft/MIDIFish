//
//  MFMIDIDestination.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>
#import "MFProtocols.h"
#import "_MFMIDIEndpointConnection.h"
@class MFMIDISession;

@interface _MFMIDIEndpointDestination : _MFMIDIEndpointConnection <MFMIDIDestination>


@end
