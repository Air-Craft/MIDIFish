//
//  MFProtocols.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#ifndef AC_Sabre_MFProtocols_h
#define AC_Sabre_MFProtocols_h

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDINetworkSession.h>
@class MFMIDIMessage;
@class MFMIDISession;

/** Protocols = verbs. Nouns are concrete classes. Don't rewrite until swift
    Ok I think we should unwind these protocols and make the private classes public. The confuscation isnt necessary I dont think. The key issues are around NetworkMIDIDestination (and analagously "..Source") which are at once MIDIConnections, MIDINetworkConnections, and MIDIDestination. Protocols should only be made where type genericity is required in the MIDISess or client code, e.g. to allow similar API for Endpoint and Network destinations even though they are different beasts */

/////////////////////////////////////////////////////////////////////////
#pragma mark - Connections
/////////////////////////////////////////////////////////////////////////

@protocol MFMIDIConnection <NSObject>

/** System name of the connection, derived from the Endpoint name or Network Host details  */
@property (nonatomic, readonly) NSString *name;

/** Get/Set whether this connection will send/receive MIDI */
@property (nonatomic) BOOL enabled;

@end

//---------------------------------------------------------------------

/** Base protocol for those which come through Network MIDI */
@protocol MFMIDINetworkConnection <MFMIDIConnection>

/** Network details for the connection */
@property (nonatomic, readonly) MIDINetworkHost *host;

/** Set to YES if this was entered manually by the user. Has implications on how we persist it */
@property (nonatomic, readonly) BOOL isManualConnection;

@end

/////////////////////////////////////////////////////////////////////////
#pragma mark - Source/Destination
/////////////////////////////////////////////////////////////////////////
@protocol MFMIDIMessageSender;
@protocol MFMIDIMessageReceiver;

/** Later we'll enable per-conx midi transactions @deprecated */
@protocol MFMIDISource <MFMIDIConnection>//, MFMIDIMessageReceiver>
@end

//---------------------------------------------------------------------

/** Later we'll enable per-conx midi transactions @deprecated */
@protocol MFMIDIDestination <MFMIDIConnection>//, MFMIDIMessageSender>
@end


/////////////////////////////////////////////////////////////////////////
#pragma mark - Receiver/Sender
/////////////////////////////////////////////////////////////////////////
@protocol MFMIDIMessageReceiverDelegate;

/** Defines an object which you can listen to to receive MIDI Messages */
@protocol MFMIDIMessageReceiver
- (void)addDelegate:(id<MFMIDIMessageReceiverDelegate>)delegate;
- (void)removeDelegate:(id<MFMIDIMessageReceiverDelegate>)delegate;
@end

//---------------------------------------------------------------------

@protocol MFMIDIMessageReceiverDelegate <NSObject>
@optional
- (void)MIDISource:(id<MFMIDISource>)midiSource didReceiveMessage:(MFMIDIMessage *)message;
@end

//---------------------------------------------------------------------

/** Define an object which you can use to send MIDI Messages */
@protocol MFMIDIMessageSender <NSObject>

/** Send a specific MIDI Message. Encapsulates the type, values and the channel. Use instead of the convenience methods when you want to send to another channel or do something unusual. Max MIDIMessage.length is 64k */
- (void)sendMIDIMessage:(MFMIDIMessage *)message;

/** Have the next level down as well too allow more complicated midi packets */
- (void)sendMIDIPacketList:(MIDIPacketList *)packetList;

@end

/////////////////////////////////////////////////////////////////////////
#pragma mark - Client Delegate
/////////////////////////////////////////////////////////////////////////

@protocol MFMIDISessionDelegate <MFMIDIMessageReceiverDelegate>

@optional
- (void)MIDISessionDidBeginConnectionRefresh:(MFMIDISession *)midiSession;
- (void)MIDISessionDidEndConnectionRefresh:(MFMIDISession *)midiSession;

- (void)MIDISession:(MFMIDISession *)midiSession didAddSource:(id<MFMIDISource>)source;
- (void)MIDISession:(MFMIDISession *)midiSession didRemoveSource:(id<MFMIDISource>)source;


- (void)MIDISession:(MFMIDISession *)midiSession didAddDestination:(id<MFMIDIDestination>)source;
- (void)MIDISession:(MFMIDISession *)midiSession didRemoveDestination:(id<MFMIDIDestination>)source;

@end



#endif
