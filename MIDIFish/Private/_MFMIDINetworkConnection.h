//
//  _MFMIDINetworkConnection.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDINetworkSession.h>
#import "_MFCoreMIDIConnection.h"
#import "MFProtocols.h"

/** 
 Abstract base class for network-based connections  @abstract 
 */
@interface _MFMIDINetworkConnection : _MFCoreMIDIConnection <MFMIDINetworkConnection>

/////////////////////////////////////////////////////////////////////////
#pragma mark - Life Cycle & Overrides
/////////////////////////////////////////////////////////////////////////

/** @override 
    Disable the super's init here 
 */
- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDISession *)client __attribute__((unavailable("Must use designated init!")));;

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDISession *)client host:(MIDINetworkHost *)host;

/** Convenience method for creation from an NSNetService */
- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDISession *)client netService:(NSNetService *)netService;

/** Considered equal if they have matching class and ths hosts check out the using `hasSameHostAs:` @override */
- (BOOL)isEqual:(_MFMIDINetworkConnection *)object;


/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

@property (nonatomic, strong) MIDINetworkConnection *midiNetworkConnection;


/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////

/** Compare hosts on two NetworkConnection's - even between a Source and a Destination. Considered the same if IP addresses match AND either the netService name/domain match (first priority, if set) or the `name`'s match (fallback, if set)  */
- (BOOL)hasSameHostAs:(_MFMIDINetworkConnection *)otherConx;




@end
