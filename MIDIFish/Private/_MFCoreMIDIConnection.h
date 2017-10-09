//
//  _MFMIDIConnection.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>
#import "MFProtocols.h"

/**
 Abstract base class for all network and non-network connections
 @abstract
 */
@interface _MFCoreMIDIConnection : NSObject <MFMIDIConnection>

/** The CoreMIDI Endpoint ref */
@property (nonatomic, readonly) MIDIEndpointRef endpoint;

/** YES when this is an Endpoint Connection that we've created for this app to appear in other apps as a Source or Destination */
@property (nonatomic, readonly) BOOL isVirtualConnection;

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDISession *)client;

/** Weak ref to the client as it handles all the dispatching */
@property (nonatomic, readonly, weak) MFMIDISession *client;


@end
