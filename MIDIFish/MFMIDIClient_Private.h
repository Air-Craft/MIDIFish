//
//  MFMIDIClient_Private.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 05/02/2015.
//
//

#import "MFMIDIClient.h"
@class _MFMIDINetworkConnection;
@class _MFMIDIEndpointConnection;

@interface MFMIDIClient ()

/////////////////////////////////////////////////////////////////////////
#pragma mark - Protected
/////////////////////////////////////////////////////////////////////////

- (void)_setStateForNetworkConnection:(_MFMIDINetworkConnection *)conx toEnabled:(BOOL)toEnabled;

- (void)_setStateForEndpointConnection:(_MFMIDIEndpointConnection *)conx toEnabled:(BOOL)toEnabled;


@end
