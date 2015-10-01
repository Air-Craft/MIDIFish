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

/////////////////////////////////////////////////////////////////////////
#pragma mark - Connections
/////////////////////////////////////////////////////////////////////////

/** Base protocol for all MIDI Connection types */
@protocol MFMIDIConnection <NSObject>

/** System name of the connection, derived from the Endpoint name or Network Host details  */
@property (nonatomic, readonly) NSString *name;

/** The CoreMIDI Endpoint ref */
@property (nonatomic, readonly) MIDIEndpointRef endpoint;

/** Flag indicating whether this refers to a connection over Wi-Fi. See README notes for important details about Network Connections and Core MIDI */
@property (nonatomic, readonly) BOOL isNetworkConnection;

/** YES when this is an Endpoint Connection that we've created for this app to appear in other apps as a Source or Destination */
@property (nonatomic, readonly) BOOL isVirtualConnection;

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

/** Later we'll enable per-conx midi transactions */
@protocol MFMIDISource <MFMIDIConnection>//, MFMIDIMessageReceiver>
@end

//---------------------------------------------------------------------

/** Later we'll enable per-conx midi transactions */
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

#pragma mark Convenience Methods
/** @name Convenience Methods  */

/** The default channel that will be used for the shorthand methods below */
@property (nonatomic) UInt8 channel;

/** Send MIDI Note On/Off message with note value and velocity (both 7bit 0..127) @{ */
- (void)sendNoteOn:(UInt8)key velocity:(UInt8)velocity;
- (void)sendNoteOff:(UInt8)key velocity:(UInt8)velocity;
/** @} */

- (void)sendCC:(UInt8)ccNumber value:(UInt8)value;

/**
 @param value This is a hi-res, 14bit value 0-16383.  8192 = center, no bend.
 */
- (void)sendPitchbend:(UInt16)value;

- (void)sendProgramChange:(UInt8)value;

- (void)sendChannelAftertouch:(UInt8)pressure;
- (void)sendPolyphonicAftertouch:(UInt8)key pressure:(UInt8)pressure;

/** MIDI All Notes Off Message (CC:123) */
- (void)sendAllNotesOffForCurrentChannel;

- (void)sendAllNotesOffForAllChannels;


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
