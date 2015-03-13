//
//  _MFMIDIConnection.h
//  AC-Sabre
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
@interface _MFMIDIConnection : NSObject <MFMIDIConnection>

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDIClient *)client;

/** Weak ref to the client as it handles all the dispatching */
@property (nonatomic, readonly, weak) MFMIDIClient *client;


@end
