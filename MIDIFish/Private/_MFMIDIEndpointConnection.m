//
//  _MFMIDIEndpointConnection.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 05/02/2015.
//
//

#import "_MFMIDIEndpointConnection.h"
#import "_MFUtilities.h"
#import "MFMIDISession_Private.h"

@implementation _MFMIDIEndpointConnection

- (void)setEnabled:(BOOL)enabled
{
    // Everything goes through MIDISession
    [self.client _setStateForEndpointConnection:self toEnabled:enabled];
}


@end
