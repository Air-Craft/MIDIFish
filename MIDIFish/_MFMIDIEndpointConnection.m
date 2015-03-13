//
//  _MFMIDIEndpointConnection.m
//  AC-Sabre
//
//  Created by Hari Karam Singh on 05/02/2015.
//
//

#import "_MFMIDIEndpointConnection.h"
#import "_MFUtilities.h"
#import "MFMIDIClient_Private.h"

@implementation _MFMIDIEndpointConnection

- (void)setEnabled:(BOOL)enabled
{
    // Everything goes through MIDIClient
    [self.client _setStateForEndpointConnection:self toEnabled:enabled];
}


@end
