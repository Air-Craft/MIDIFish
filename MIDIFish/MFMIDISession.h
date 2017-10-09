//
//  MFMIDIServer.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 01/02/2015.
//
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDINetworkSession.h>

#import "MFProtocols.h"
#import "MFMIDIMessage.h"
#import "MFAudiobusDestination.h"

/////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////
@protocol MFMIDISessionDelegate;
@class ABAudiobusController;

@interface MFMIDISession : NSObject <MFMIDIMessageSender, MFMIDIMessageReceiver>


/////////////////////////////////////////////////////////////////////////
#pragma mark - Life Cycle
/////////////////////////////////////////////////////////////////////////

/** Create a new client. Won't have any connections until you call `refresh...` @throws MFNonFatalException if unable to create MIDI Client or In/Out ports */
+ (instancetype)sessionWithName:(NSString *)name;

/** Create a new client. Won't have any connections until you call `refresh...` @throws MFNonFatalException if unable to create MIDI Client or In/Out ports */
- (instancetype)initWithName:(NSString *)name;



/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

@property (nonatomic, readonly) NSString *name;

/** Enable MIDINetworkSession and Bonjour search for connections. Defaults to YES */
@property (nonatomic) BOOL networkEnabled;

/** Audiobus disables CoreMIDI at certain times. Use this property to check when. When it's YES then none of the network or endpoint connections will send */
@property (nonatomic, readonly) BOOL coreMIDISendEnabled;

// TODO:
@property (nonatomic, readonly) BOOL coreMIDIReceiveEnabled;

/** Stores enabled states for connections (in NSUserDefaults) and restores them upon re-discovery / re-creation (ie does NOT add them on launch, only sets them when found) */
@property (nonatomic) BOOL restorePreviousConnectionStates;

/** Default=YES. YES means ignore the endpoint which shares the same name as this device. */
@property (nonatomic) BOOL excludeSelfInNetworkScan;

/** Default=YES. YES means to store manual connections added by the client and recall them when refreshing. NO means previously stores ones will NOT be recalled on refresh, though they won't be erased. These are often IP address which don't come up in a Bonjour scan (e.g. Windows users). Note, just because they are persisted does not mean they are enabled */
@property (nonatomic) BOOL persistManualNetworkConnections;

//@property (nonatomic) BOOL reconnectVirtualConnections;
//@property (nonatomic) BOOL reconnectNetworkConnections;

/** Automatically enable all newly discovered on refresh. If `restorePreviousConnectionStates` is on then this will only auto-enable ones which are new. @{ */
@property (nonatomic) BOOL autoEnableDestinations;
@property (nonatomic) BOOL autoEnableSources;
/** @} */

/** YES when a Bonjour browse is in effect (via refresh) */
@property (nonatomic, readonly) BOOL isRefreshing;

/**
 Getter for just the *network* sources.
 @return Array of id<MFMIDISource, MFMIDINetworkConnection>
 */
@property (nonatomic, readonly) NSArray *networkSources;

/** 
 Getter for just the *network* destinations.
 @return Array of id<MFMIDIDestination, MFMIDINetworkConnection> 
 */
@property (nonatomic, readonly) NSArray *networkDestinations;

/**
 Getters for endpoint-based (device & app, non-network) connections. Does NOT include the NetworkSession endpoint
 @return Array of id<MFMIDISource>
 */
@property (nonatomic, readonly) NSArray *endpointSources;

/** 
 Getters for endpoint-based (device & app, non-network) connections. Does NOT include the NetworkSession endpoint 
 @return Array of id<MFMIDIDestination>
 */
@property (nonatomic, readonly) NSArray *endpointDestinations;

/**
 Array of "virtual destinations" we've created in relation to this app. These are also contained in `endpointSources`. Keep in mind that when the app is a VirtualDestination it means it is a MIDIDestination for *other* apps. Locally it appears as a MIDISource because we read from it
 
 @return Array of id<MFMIDISource>
 */
@property (nonatomic, readonly) NSArray *virtualDestinations;

/** 
 Array of "virtual sources" we've created in relation to this app. These are also contained in `endpointDestinations`. Keep in mind that when the app is a VirtualSource it means it is a MIDISource for *other* apps. Locally it appears as a MIDIDestination because we output to it.
 
 @return Array of id<MFMIDIDestinatio>
  */
@property (nonatomic, readonly) NSArray *virtualSources;


/** Above are a bit deprecated. The whole point of this API is to reduce the knowledge needed to work with midi and coremidi. For now this one will just contain Audiobus destinations but in the future it will merge with the others in a ".destinations" property */
@property (nonatomic, readonly) NSArray *audiobusDestinations;


/** The default channel that will be used for the shorthand methods below */
@property (nonatomic) UInt8 midiChannel;


/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id<MFMIDISessionDelegate>)delegate;
- (void)removeDelegate:(id<MFMIDISessionDelegate>)delegate;

/** Re-scan the connected devices (instantaneous) and Network (async) updating connections list. If called while scanning then a cancel is called first */
- (void)refreshConnections;

/** Cancel a refresh (relevant for network only really) */
- (void)cancelRefresh;

/** 
 Create/add Virtual Destination (as a MIDISource, locally). WARNING: It's only enabled if autoEnabledSources is set to YES. To enable manually, catch the return value and set the `enabled` property.
 
 To understand the return values, see notes in README and properties above. If one with the name already exists a new one is NOT created and the first one is returned. DOES trigger delegates
 */
- (id<MFMIDISource>)createVirtualDestinationWithName:(NSString *)name;

/**
 Create/add Virtual Source (as a MIDIDestination, locally). WARNING: It's only enabled if autoEnabledDestinations is set to YES. To enable manually, catch the return value and set the `enabled` property.
 
 To understand the return values, see notes in README and properties above. If one with the name already exists a new one is NOT created and the first one is returned. DOES trigger delegates
 */
- (id<MFMIDIDestination>)createVirtualSourceWithName:(NSString *)name;
/** @} */

/** Adds and enables a network host connection pair (Source/Destination - since they are coupled as per the way MIDINetwork works) with the given parameters. DOES trigger delegates. These will be persisted if this class's corresponding option is set. "name" must be unique or will silently overwrite the existing connections persistence entry
  @return [id<MIDISource>, id<key>] Returns the matching connections if a pair already exists
  @{ */
- (NSArray *)addManualNetworkConnectionWithName:(NSString *)name address:(NSString *)address port:(NSUInteger)port;
/** @} */

/** Remove's the connection with the specified details from the netsession as well as our internal persistence. Removes from persistence only if the persists... flag is set on the class */
- (void)forgetManualNetworkConnectionWithName:(NSString *)name;

/** Some introspection on the state of connections. "Available" includes those which are disabled */
- (NSUInteger)availableSourcesCountIncludeVirtual:(BOOL)includeVirtual;
- (NSUInteger)availableDestinationsCountIncludeVirtual:(BOOL)includeVirtual;
- (NSUInteger)enabledSourcesCountIncludeVirtual:(BOOL)includeVirtual;
- (NSUInteger)enabledDestinationsCountIncludeVirtual:(BOOL)includeVirtual;


#pragma mark Audiobus

- (void)assignAudiobusController:(ABAudiobusController *)abController;

- (void)addAudiobusDestination:(MFAudiobusDestination *)abDestination;

// convenience method for creating a destination
- (MFAudiobusDestination *)createAudiobusSenderPortWithName:(NSString *)name title:(NSString *)title;



#pragma mark MIDI Convenience Methods
/** @name Convenience Methods  */

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



