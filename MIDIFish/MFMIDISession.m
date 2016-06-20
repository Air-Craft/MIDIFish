//
//  MFMIDIServer.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 01/02/2015.
//
//
#import <CoreMIDI/CoreMIDI.h>
#import <CoreMIDI/MIDINetworkSession.h>
#import "MFMIDISession.h"
#import "MFMIDISession_Private.h"

#import "MFNonFatalException.h"
#import "_MFUtilities.h"
#import "_MFMIDINetworkConnection.h"
#import "_MFMIDIEndpointConnection.h"
#import "_MFMIDIEndpointSource.h"
#import "_MFMIDIEndpointDestination.h"
#import "_MFMIDINetworkSource.h"
#import "_MFMIDINetworkDestination.h"

// @TEMP
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/types.h>
#import <sys/socket.h>

// Channelised Logging
#undef echo
#if LOG_MIDIFISH
#   define echo(fmt, ...) NSLog((@"[MIDIFISH] " fmt), ##__VA_ARGS__);
#else
#   define echo(...)
#endif
#undef warn
#define warn(fmt, ...) NSLog((@"[MIDIFISH] WARNING: " fmt), ##__VA_ARGS__);


/////////////////////////////////////////////////////////////////////////
#pragma mark - Defs
/////////////////////////////////////////////////////////////////////////

/** Convert MIDIEndpointsRefs to object. In 64bit they are integers. in 32bit they are struct pointers :(. Note they need to compare well as they are placed in arrays and checked with `containsObject:` */
//#if __LP64__
#define _EP2Obj(endpoint) @(endpoint);
//#else
//#define _EP2Obj(endpoint) [NSValue valueWithPointer:endpoint];
//#endif


/** Timeout for resolving Bonjour names into IP/Port addresses. 5 was too short sometimes */
static const NSTimeInterval _NETSERVICE_RESOLVE_TIMEOUT = 15;   // seconds

/** When refresh is called whilst refreshing, cancelRefresh is called and then refresh is called again  after this time delay */
static const NSTimeInterval _REFRESH_RETRY_TIME_AFTER_STOP = 0.5;


// C callbacks: definitions are near their ObjC counterparts
static void _MFMIDINotifyProc(const MIDINotification *message, void *refCon);
static void _MFMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

static NSString * const _kUserDefsKeyEnabledStates = @"co.air-craft.MIDIFish.connectionsEnabledStates";
static NSString * const _kUserDefsKeyManualConnections = @"co.air-craft.MIDIFish.manualConnections";


/////////////////////////////////////////////////////////////////////////
#pragma mark - Private Extensions
/////////////////////////////////////////////////////////////////////////

@interface MFMIDISession () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, readwrite) BOOL isRefreshing;
@end

//---------------------------------------------------------------------

@interface _MFMIDIConnection ()
@property (nonatomic, readwrite) BOOL isVirtualConnection;
/** Update the enabled ivar alone - ie without updating MIDINetworkSession */
- (void)_setEnabledFlag:(BOOL)enabled;
@end

//---------------------------------------------------------------------

@interface _MFMIDINetworkConnection ()
@property (nonatomic, readwrite) BOOL isManualConnection;
@end



/////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////

/**
 DEV NOTES:
 
 Where connections are added: 
 1: _refresh... -- (endpoint-based conx and the single network session endpoint)
 2: addNetworkConnectionWithHost:  -- used by netBrowserDidFind as well
 3:
 
 TODOS:
 - Persistence should probably have a built in clean out mechanism for ones that havent appeared in say a year. Very low priority for now.
 */
@implementation MFMIDISession
{
    MIDIClientRef _clientRef;
    MIDIPortRef _outputPortRef;
    MIDIPortRef _inputPortRef;
    
    // These are the actualy CoreMIDI endpoints which are separate in both code and concept from our "Connection" objects. Note, property backing ivars _endpointSources/Destinations represent our MIDIConnections objects which have their own endpoint (as opposed to Network ones which all share 1 endpoint). These ivars INCLUDE the network endpoint while the endpoint* properties do not.
    NSMutableArray *_destinationEndpoints;    // [@(MIDIEndpointRef)]
    NSMutableArray *_sourceEndpoints;  // [@(MIDIEndpointRef)]
    
    NSMutableArray *_delegates;
    
    NSNetServiceBrowser *_netBrowser;
    MIDINetworkSession *_midiNetSession;
    BOOL _isBrowsingForNetworkConnections;
    NSMutableArray *_netConxToRemove;   // tracking var for notifying delegates after a rescan
    
    NSUserDefaults *_userDefs;
    
    // The trackers for knowing when a net scan has finished
    BOOL _netServiceBrowserIsSearching;
    NSMutableArray *_netServicesAwaitingResolve;
}

//---------------------------------------------------------------------

+ (instancetype)sessionWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

//---------------------------------------------------------------------

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _netServicesAwaitingResolve = [NSMutableArray array];
        _name = name;
        _netBrowser = [[NSNetServiceBrowser alloc] init];
        _netBrowser.delegate = self;
        _excludeSelfInNetworkScan = YES;
        _persistManualNetworkConnections = YES;
        _endpointSources = (id)[NSArray array];
        _endpointDestinations = (id)[NSArray array];
        _networkSources = (id)[NSArray array];
        _networkDestinations = (id)[NSArray array];
        _virtualDestinations = (id)[NSArray array];
        _virtualSources = (id)[NSArray array];
        _destinationEndpoints = [NSMutableArray array];
        _sourceEndpoints = [NSMutableArray array];
        _delegates = [NSMutableArray array];
        _midiNetSession = [MIDINetworkSession defaultSession];
        _userDefs = [NSUserDefaults standardUserDefaults];

        _midiNetSession.connectionPolicy = MIDINetworkConnectionPolicy_Anyone;
        
        // Create the MIDI I/O structure
        OSStatus s;
        NSString *portName, *format;
        
        echo("Creating MIDI Client with name \"%@\"", name);
        s = MIDIClientCreate((__bridge CFStringRef)_name, _MFMIDINotifyProc, (__bridge void *)self, &_clientRef);
        _MFCheckErr(s, @"Unable to create MIDI Client");
        
        
        format = NSLocalizedString(@"%@ Input",
                                   @"MIDIFish: Text appended to MIDIClient name for the Input Port name");
        portName = [NSString stringWithFormat:format, _name];
        echo("Creating MIDI Input Port with name \"%@\"", portName);
        s = MIDIInputPortCreate(_clientRef, (__bridge CFStringRef)portName, _MFMIDIReadProc, (__bridge void *)self, &_inputPortRef);
        _MFCheckErr(s, @"Unable to create MIDI Input Port");
        
        
        format = NSLocalizedString(@"%@ Output",
                                   @"MIDIFish: Text appended to MIDIClient name for the Output Port name");
        portName = [NSString stringWithFormat:format, _name];
        echo("Creating MIDI Output Port with name \"%@\"", portName);
        s = MIDIOutputPortCreate(_clientRef, (__bridge CFStringRef)portName, &_outputPortRef);
        _MFCheckErr(s, @"Unable to create MIDI Ouput Port");
        
        self.networkEnabled = YES;
    }
    return self;
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

- (BOOL)networkEnabled { return _midiNetSession.enabled; }
- (void)setNetworkEnabled:(BOOL)networkEnabled
{
    echo("%@abling MIDINetworkSession", networkEnabled ? @"En" : @"Dis");

    _midiNetSession.enabled = networkEnabled;
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id<MFMIDISessionDelegate>)delegate
{
    [_delegates addObject:delegate];
}

//---------------------------------------------------------------------

- (void)removeDelegate:(id<MFMIDISessionDelegate>)delegate
{
    [_delegates removeObject:delegate];
}

//---------------------------------------------------------------------

- (void)refreshConnections
{
    echo("Refreshing Connections (local and network)...");

    // If repeat refresh then stop and try again in a bit
    if (self.isRefreshing) {
        echo("...Already refreshing. Cancelling and will try again in %.1f", _REFRESH_RETRY_TIME_AFTER_STOP);
        [self cancelRefresh];
        [self performSelector:@selector(refreshConnections) withObject:nil afterDelay:_REFRESH_RETRY_TIME_AFTER_STOP];
        return;
    }
    
    [self _notifyDelegatesConnectionRefreshDidBegin];

    // Enable to more easily debug the "repeat refresh causes MIDINetworkConnectio bad access on deconstruct" errors
//    _networkDestinations = @[];
//    _networkSources = @[];
//    _destinationEndpoints = @[].mutableCopy;
//    _sourceEndpoints = @[].mutableCopy;
    
    // Rescan endpoints/direct connections and
    [self _refreshConnectionsForMIDIEndpoints];
    
    // For network, re-add persisted manuals and initiate a network scan if enabled
    // Otherwise send "End" straight away if network is disabled
    if (self.networkEnabled)
    {
        if (_persistManualNetworkConnections) {
            [self _restoreManualNetworkConnections];
        }
        
        [_netBrowser searchForServicesOfType:MIDINetworkBonjourServiceType inDomain:@""];
    }
    else
    {
        [self _notifyDelegatesConnectionsRefreshDidEnd];
    }
}

//---------------------------------------------------------------------

- (void)cancelRefresh
{
    if (!self.networkEnabled) {
        warn("Calling cancelRefresh when Network is disabled has no effect");
        return;
    }
    if (!self.isRefreshing) {
        warn("cancelRefresh called when not currently refreshing");
        return;
    }
    
    echo("Cancelling (net) refresh"); // just net b/c the other is instantaneous
    
    // Stop the netService resolves too
    for (NSNetService *netService in _netServicesAwaitingResolve.copy) {
        [netService stop];
    }
    [_netServicesAwaitingResolve removeAllObjects];

    [_netBrowser stop];
}

//---------------------------------------------------------------------

- (id<MFMIDIDestination>)createVirtualSourceWithName:(NSString *)name
{
    // Check whether one exists already with the given name
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSArray *matching = [_virtualSources filteredArrayUsingPredicate:pred];
    if (matching.count > 0) {
        warn("Virtual Source already exists with name %@", name);
        return matching[0];
    }
    
    MIDIEndpointRef endpoint;
    _MFCheckErr(MIDISourceCreate(_clientRef,
                                 (__bridge CFStringRef)name,
                                 &endpoint),
                @"Could not create Virtual Source with name %@", name);
    
    echo("Creating MIDI Source with endpoint %i for Virtual Source with name \"%@\"", (int)endpoint, name);

    // Create the Object
    _MFMIDIEndpointDestination *vsource = [self _connectDestinationEndpoint:endpoint];
    vsource.isVirtualConnection = YES;
    _virtualSources = (id)[_virtualSources arrayByAddingObject:vsource];
    
    return vsource;
}

//---------------------------------------------------------------------

- (id<MFMIDISource>)createVirtualDestinationWithName:(NSString *)name
{
    // Check whether one exists already with the given name
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSArray *matching = [_virtualDestinations filteredArrayUsingPredicate:pred];
    if (matching.count > 0) {
        warn("Virtual Destination already exists with name %@", name);
        return matching[0];
    }
    
    echo("Creating Virtual Destination with name \"%@\"", name);

    MIDIEndpointRef endpoint;
    _MFCheckErr(MIDIDestinationCreate(_clientRef,
                                      (__bridge CFStringRef)name,
                                      _MFMIDIReadProc,
                                      (__bridge void *)self,
                                      &endpoint),
                @"Could not create Virtual Destination with name %@", name);
    
    // Create the Object
    _MFMIDIEndpointSource *vdest = [self _connectSourceEndpoint:endpoint];
    vdest.isVirtualConnection = YES;
    _virtualDestinations = (id)[_virtualDestinations arrayByAddingObject:vdest];
    
    return vdest;
}

//---------------------------------------------------------------------

- (NSArray *)addManualNetworkConnectionWithName:(NSString *)name address:(NSString *)address port:(NSUInteger)port
{
    echo("Adding Manual Network Connection '%@' addr=%@, port=%i", name, address, (int)port);
    
    NSArray *conns = [self _addNetworkConnectionWithName:name address:address port:port];
    
    [conns[0] setIsManualConnection:YES];
    [conns[1] setIsManualConnection:YES];
    
    // We need to for enablding as _addNetwork... will result in it obeying the autoEnableDestination flag which isnt really what we want here
    _MFMIDINetworkConnection *conn = conns[1];
    conn.enabled = YES;
    
    [self _storeConnectionEnabledState:conn];
    
    // Store in userdefs if specified
    if (_persistManualNetworkConnections)
    {
        echo("...Storing Connection in UserDefs");
        
        NSMutableDictionary *manualConns = [[_userDefs objectForKey:_kUserDefsKeyManualConnections] mutableCopy];
        // Create dict of none previously
        if (manualConns == nil) {
            echo("...First ever entry!");
            manualConns = [NSMutableDictionary new];
        }
        manualConns[name] = @{ @"address": address, @"port": @(port) };
        
        [_userDefs setObject:manualConns forKey:_kUserDefsKeyManualConnections];
        [_userDefs synchronize];
    }
    
    return conns;
}

//---------------------------------------------------------------------

- (void)forgetManualNetworkConnectionWithName:(NSString *)name
{
    echo("Removing connection and persistence for Manual Network Connection '%@'", name);
    
    // Find the connections
    _MFMIDINetworkConnection *source, *destination;
    for (_MFMIDINetworkConnection *conn in _networkSources)
    {
        if ([conn.name isEqual:name]) {
            source = conn;
            break;
        }
    }
    for (_MFMIDINetworkConnection *conn in _networkDestinations)
    {
        if ([conn.name isEqual:name]) {
            destination = conn;
            break;
        }
    }
    
    // Sanity check
    NSAssert(source && destination, @"Something's weird. We dont have a complete pair: source=%@, destination=%@", source, destination);
    
    // Disable them (only one required as they are coupled)
    destination.enabled = NO;
    
    // Remove them from the connections list
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF != %@", source];
    _networkSources = [_networkSources filteredArrayUsingPredicate:pred];
    NSPredicate *pred2 = [NSPredicate predicateWithFormat:@"SELF != %@", destination];
    _networkDestinations = [_networkDestinations filteredArrayUsingPredicate:pred2];
    
    // Remove from the UserDefs if set
    if (_persistManualNetworkConnections)
    {
        NSMutableDictionary *manualConns = [[_userDefs objectForKey:_kUserDefsKeyManualConnections] mutableCopy];
        if (manualConns && [manualConns objectForKey:name]) {
            [manualConns removeObjectForKey:name];
            [_userDefs setObject:manualConns forKey:_kUserDefsKeyManualConnections];
            [_userDefs synchronize];
        }
    }
}

//---------------------------------------------------------------------

- (NSUInteger)availableSourcesCountIncludeVirtual:(BOOL)includeVirtual
{
    NSArray *connections = [_networkSources arrayByAddingObjectsFromArray:_endpointSources];

    if (includeVirtual) return connections.count;
    
    NSUInteger cnt = 0;
    for (id<MFMIDIConnection> conn in connections) {
        if (!conn.isVirtualConnection) cnt++;
    }
    return cnt;
}

//---------------------------------------------------------------------

- (NSUInteger)availableDestinationsCountIncludeVirtual:(BOOL)includeVirtual
{
    NSArray *connections = [_networkDestinations arrayByAddingObjectsFromArray:_endpointDestinations];

    if (includeVirtual) return connections.count;
    
    NSUInteger cnt = 0;
    for (id<MFMIDIConnection> conn in connections) {
        if (!conn.isVirtualConnection) cnt++;
    }
    return cnt;
}

//---------------------------------------------------------------------

- (NSUInteger)enabledSourcesCountIncludeVirtual:(BOOL)includeVirtual
{
    NSArray *connections = [_networkSources arrayByAddingObjectsFromArray:_endpointSources];
    
    NSUInteger cnt = 0;
    for (id<MFMIDIConnection> conn in connections) {
        if (conn.enabled && (includeVirtual || !conn.isVirtualConnection))
            cnt++;
    }
    return cnt;
}

//---------------------------------------------------------------------

- (NSUInteger)enabledDestinationsCountIncludeVirtual:(BOOL)includeVirtual
{
    NSArray *connections = [_networkDestinations arrayByAddingObjectsFromArray:_endpointDestinations];
    
    NSUInteger cnt = 0;
    for (id<MFMIDIConnection> conn in connections) {
        if (conn.enabled && (includeVirtual || !conn.isVirtualConnection))
            cnt++;
    }
    return cnt;
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - <MFMIDIMessageSender>
/////////////////////////////////////////////////////////////////////////

/** 
 @throws MFNonFatalException on send error. Will attempt to send to all relevant connections b4 throwing the exception
 */
- (void)sendMIDIMessage:(MFMIDIMessage *)message
{
    echo(@"Sending MIDI Message %@", message);
    
    // Form a MIDIPacketList (thanks PGMIDI!)
    NSParameterAssert(message.length < 65536);
    Byte packetBuffer[message.length + 100];
    MIDIPacketList *packetList = (MIDIPacketList *)packetBuffer;
    MIDIPacket     *packet     = MIDIPacketListInit(packetList);
    
    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, message.length, message.bytes);
    
    // Most efficient for now is to loop through _destinations sending to the endpoints of those which are enabled skipping the network ones. Then doing *1* network one at the end if available (as they share the same endpoint
    OSStatus res = noErr;
    for (_MFMIDIConnection *conx in _endpointDestinations)
    {
        if (!conx.enabled) continue;

        // MIDI Source acts the other way aroud
        OSStatus s;
        if (conx.isVirtualConnection) {
            s = MIDIReceived(conx.endpoint, packetList);
        } else {
            s = MIDISend(_outputPortRef, conx.endpoint, packetList);
        }
        
        if (res == noErr && s != noErr) res = s;    // track the first error
    }
    
    // Network Conx
    if (self.networkDestinations.count > 0)
    {
        MIDIEndpointRef endpoint = [self.networkDestinations[0] endpoint];
        OSStatus s = MIDISend(_outputPortRef, endpoint, packetList);
        if (res == noErr && s != noErr) res = s;    // track the first error
    }
    
    // Except on error
    if (res != noErr) {
        @throw [MFNonFatalException exceptionWithOSStatus:res reason:@"Error sending midi message"];
    }
}

//---------------------------------------------------------------------

@synthesize channel=_channel;

//---------------------------------------------------------------------

- (void)sendNoteOn:(UInt8)key velocity:(UInt8)velocity
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypeNoteOn channel:_channel];
    msg.key = key;
    msg.velocity = velocity;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendNoteOff:(UInt8)key velocity:(UInt8)velocity
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypeNoteOff channel:_channel];
    msg.key= key;
    msg.velocity = velocity;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendCC:(UInt8)ccNumber value:(UInt8)value
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypeControlChange channel:_channel];
    msg.controller = ccNumber;
    msg.value = value;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendPitchbend:(UInt16)value
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypePitchbend channel:_channel];
    msg.pitchbendValue = value;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendProgramChange:(UInt8)value
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypeProgramChange channel:_channel];
    msg.programNumber = value;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendChannelAftertouch:(UInt8)pressure
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypeChannelAftertouch channel:_channel];
    msg.channelPressure = pressure;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendPolyphonicAftertouch:(UInt8)key pressure:(UInt8)pressure
{
    MFMIDIMessage *msg = [MFMIDIMessage messageWithType:kMFMIDIMessageTypePolyphonicAftertouch channel:_channel];
    msg.key = key;
    msg.keyPressure = pressure;
    [self sendMIDIMessage:msg];
}

//---------------------------------------------------------------------

- (void)sendAllNotesOffForCurrentChannel
{
    [self sendCC:123 value:127];
}

//---------------------------------------------------------------------

- (void)sendAllNotesOffForAllChannels
{
    NSUInteger currentChan = self.channel;
    
    for (NSUInteger i=0; i<=15; i++)
    {
        self.channel = i;
        [self sendAllNotesOffForCurrentChannel];
    }
    
    self.channel = currentChan;
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - MIDI Callback Procs
/////////////////////////////////////////////////////////////////////////

static void _MFMIDINotifyProc(const MIDINotification *message, void *refCon)
{
    //if (message->child == virtualDestinationEndpoint || notification->child == virtualSourceEndpoint) return;
    
    MFMIDISession *self = (__bridge MFMIDISession *)refCon;
    switch (message->messageID)
    {
        case kMIDIMsgObjectAdded:
        {
            // Choose the source/destination and wire it in
            const MIDIObjectAddRemoveNotification *notif = (const MIDIObjectAddRemoveNotification *)message;
            MIDIEndpointRef endpoint = (MIDIEndpointRef)notif->child;
            
            echo("CoreMIDI reported ADDED endpoint %i", (int)endpoint);

            // Skip if it's a virtual one as we were the ones who added it
            if ([self _endpointIsForVirtualConnection:endpoint]) {
                echo("...skipping as it's virtual");
                return;
            }
            
            if (notif->childType == kMIDIObjectType_Destination)
                [self _connectDestinationEndpoint:endpoint];
            else if (notif->childType == kMIDIObjectType_Source)
                [self _connectSourceEndpoint:endpoint];
            break;
        }
        case kMIDIMsgObjectRemoved:
        {
            // Choose the source/destination and wire it in
            const MIDIObjectAddRemoveNotification *notif = (const MIDIObjectAddRemoveNotification *)message;
            MIDIEndpointRef endpoint = (MIDIEndpointRef)notif->child;
            echo("CoreMIDI reported REMOVED endpoint %i", (int)endpoint);

            // virtual should never be but if it is then it's reversed terminology when local
            if ([self _endpointIsForVirtualConnection:endpoint])
            {
                echo("...it's for a virtual!?!");
                if (notif->childType == kMIDIObjectType_Destination)
                    [self _disconnectSourceEndpoint:endpoint];
                else if (notif->childType == kMIDIObjectType_Source)
                    [self _disconnectDestinationEndpoint:endpoint];
                break;
            }
            
            if (notif->childType == kMIDIObjectType_Destination)
                [self _disconnectDestinationEndpoint:endpoint];
            else if (notif->childType == kMIDIObjectType_Source)
                [self _disconnectSourceEndpoint:endpoint];
            break;
        }
        default:
        case kMIDIMsgSetupChanged:
        case kMIDIMsgPropertyChanged:
        case kMIDIMsgThruConnectionsChanged:
        case kMIDIMsgSerialPortOwnerChanged:
        case kMIDIMsgIOError:
            echo("CoreMIDI Notification with messageID %i", (int)message->messageID);
            break;
    }
}

//---------------------------------------------------------------------

static void _MFMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    id<MFMIDISource>self = (__bridge id<MFMIDISource>)srcConnRefCon;
    // @TODO: Source Read
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - NSNetServiceBrowser & NSNetService Delegates
/////////////////////////////////////////////////////////////////////////

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
    echo("NETSERVICE: NetServiceBrowser BEGAN");
    self.isRefreshing = YES; // use setter to invoke KVO
    _netServiceBrowserIsSearching = YES;
    
    // No need to notify delegates as it happens on the refresh method (in case network is disabled)
    
    // Grab a copy of existing net conx to report removals to delegate when done
    _netConxToRemove = [NSMutableArray array];
    [_netConxToRemove addObjectsFromArray:self.networkSources];
    [_netConxToRemove addObjectsFromArray:self.networkDestinations];
    
    // Note we tell delegates on the scan refresh as it's not just network
}

//---------------------------------------------------------------------

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    // Ignore the local device if specified
    // Don't use UIDevice.currentDevice.name as apparently it can be different: http://stackoverflow.com/questions/7723801/apple-bonjour-how-can-i-tell-which-published-service-is-my-own/31526432?noredirect=1#comment51654025_31526432
    if (_excludeSelfInNetworkScan && [aNetService.name isEqualToString:_midiNetSession.networkName])
    {
        echo("NETSERVICE: Browser will ignore self '%@'", aNetService.name);
    }
    else
    {
        echo("NETSERVICE: Found %@. Resolving...", aNetService);
        
        // See Special Notes in README about NSNetService. In short we need to resolve manually into IP/Port and create a connection with those
        
        [_netServicesAwaitingResolve addObject:aNetService];
        aNetService.delegate = self;
        [aNetService resolveWithTimeout:_NETSERVICE_RESOLVE_TIMEOUT];
    }
    
    // If that's it then stop the browser (it's manually controlled)
    if (!moreComing) {
        echo("...no more coming. Stopping NetServiceBrowser search.");
        [_netBrowser stop];
    }
}

//---------------------------------------------------------------------

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict
{
    // Happens when search is called when already searching. Shouldnt be the case if our code works.
    warn("NETSERVICE: NetServiceBrowser DID NOT SEARCH: %@", errorDict);
    _netServiceBrowserIsSearching = NO;
    [self _checkWhetherAllNetRefreshActivityHasStoppedAndHandleCleanup];
}

//---------------------------------------------------------------------

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
    echo("NETSERVICE: NetServiceBrowser STOPPED");
    _netServiceBrowserIsSearching = NO;
    [self _checkWhetherAllNetRefreshActivityHasStoppedAndHandleCleanup];
}

//---------------------------------------------------------------------

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    warn("NETSERVICE: %@ DID NOT RESOLVE. Adding to MIDINetworkSession anyway as a fallback (using the NSNetService) Error: %@", sender, errorDict);

    // Ignore the local device if specified. Do it here too to prevent it messing up the trackers below
    // Don't use UIDevice.currentDevice.name as apparently it can be different: http://stackoverflow.com/questions/7723801/apple-bonjour-how-can-i-tell-which-published-service-is-my-own/31526432?noredirect=1#comment51654025_31526432
    if (_excludeSelfInNetworkScan && [sender.name isEqualToString:_midiNetSession.networkName]) {
        return;
    }
    
    // Fallback - at least it will show up in MIDI Network Setup's "Directory"
    // @TODO: ???
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:sender.name netService:sender];
    NSArray *pair = [self _addNetworkConnectionWithHost:host];
    _MFMIDINetworkConnection *src = pair[0], *dest = pair[1];
    [_netConxToRemove removeObject:src];
    [_netConxToRemove removeObject:dest];
    
    // Remove it from our list and cleanup if done
    [_netServicesAwaitingResolve removeObject:sender];
    
    [self _checkWhetherAllNetRefreshActivityHasStoppedAndHandleCleanup];
}

//---------------------------------------------------------------------

- (void)netServiceWillResolve:(NSNetService *)sender
{
//    echo("NETSERVICE: WILL RESOLVE %@", sender);
}

//---------------------------------------------------------------------

- (void)netServiceDidStop:(NSNetService *)sender
{
    echo("NETSERVICE: %@ resolving STOPPED.", sender);
    
    // Remove it from our list and cleanup if done
    [_netServicesAwaitingResolve removeObject:sender];
    
    // ~~Don't do the cleanup here as this is called BEFORE didResolve~~
    // Ok thats true but sometimes this is called when there aren't any more addresses coming and we haven't found a good one, so we need to do it here. It's no big deal the connection will be removed and then immediately re-added if it is found again.
    
    [self _checkWhetherAllNetRefreshActivityHasStoppedAndHandleCleanup];
}

//---------------------------------------------------------------------

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    // Ignore the local device if specified
    // Don't use UIDevice.currentDevice.name as apparently it can be different: http://stackoverflow.com/questions/7723801/apple-bonjour-how-can-i-tell-which-published-service-is-my-own/31526432?noredirect=1#comment51654025_31526432
    if (_excludeSelfInNetworkScan && [sender.name isEqualToString:_midiNetSession.networkName])
    {
        echo("NETSERVICE: Resolve will ignore self '%@'", sender.name);
        return;
    }

    uint16_t port;
    NSString *ipAddress = nil;
    
    echo("NETSERVICE: %@ RESOLVED with %i addresses", sender, (int)sender.addresses.count);
    
    for (NSData *address in sender.addresses)
    {
        // Resolve into IP:port. If it's IPv6 the skip...
        struct sockaddr *socketAddress = (struct sockaddr *)[address bytes];
        char buffer[256];

        /* Only continue if this is an IPv4 address. */
        // Oh thank you: https://developer.apple.com/library/mac/qa/qa1298/_index.html
        
        // Experimental IPv6 connections (doesnt work with MIDI Network Setup)
        // Just log for now
        if (socketAddress && socketAddress->sa_family == AF_INET6) {
            if (inet_ntop(AF_INET6, &((struct sockaddr_in *)
                                      socketAddress)->sin_addr, buffer, sizeof(buffer)))
            {
                port = ntohs(((struct sockaddr_in *)socketAddress)->sin_port);
                
                echo("NETSERVICE: IPv6 address %s:%i resolved for %@", buffer, (int)port, sender);
                
                //            ipAddress = [NSString stringWithUTF8String:buffer];
                //            [sender stop];
            }
        }
        
        
        if (socketAddress && socketAddress->sa_family == AF_INET)
        {
            if (inet_ntop(AF_INET, &((struct sockaddr_in *)
                                     socketAddress)->sin_addr, buffer, sizeof(buffer)))
            {
                port = ntohs(((struct sockaddr_in *)socketAddress)->sin_port);
                
                ipAddress = [NSString stringWithUTF8String:buffer];
                
                break;
            }
        }
    }
    
    if (!ipAddress)
    {
        echo("NETSERVICE: %@ address did not resolve to IPv4. Hopefully there'll be another address...", sender)
    }
    else
    {
        echo("NETSERVICE: %@ resolved to %@:%i", sender, ipAddress, port);
        
        // Connect to MIDI
        // Handles delegate (if it's not an existing connection). Returns the created or existing conx pair
        NSArray *pair = [self _addNetworkConnectionWithName:sender.name address:ipAddress port:port];
        _MFMIDINetworkConnection *src = pair[0], *dest = pair[1];
        [_netConxToRemove removeObject:src];
        [_netConxToRemove removeObject:dest];

        // Don't keep resolving if we have a legit IPv4 address.
        [sender stop];
        
        // Cleanup check happens in the Stop delegate methods
    }
}

//---------------------------------------------------------------------

/** Checks that both the NetServiceBrowsers AND the NetService resolves have all completed and if so, updates conx, resets flags and notifies the delegates */
- (void)_checkWhetherAllNetRefreshActivityHasStoppedAndHandleCleanup
{
    if (_netServicesAwaitingResolve.count > 0 ||
        _netServiceBrowserIsSearching)
    {
        echo("NETSERVICE: Still resolving...");
    }
    else
    {
        echo("NETSERVICE: All done! Cleaning up...");

        // First remove manual connections so they dont get cleaned up
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF.isManualConnection == 0"];
        _netConxToRemove = [_netConxToRemove filteredArrayUsingPredicate:pred].mutableCopy;
        
        echo("...cleaning out old connections no longer present: %@", _netConxToRemove);
        NSMutableArray *newSrcs, *newDests;
        newSrcs = _networkSources.mutableCopy;
        [newSrcs removeObjectsInArray:_netConxToRemove];
        _networkSources = [NSArray arrayWithArray:newSrcs];
        newDests = _networkDestinations.mutableCopy;
        [newDests removeObjectsInArray:_netConxToRemove];
        _networkDestinations = [NSArray arrayWithArray:newDests];
        
        for (_MFMIDINetworkConnection *conx in _netConxToRemove)
        {
            [self _notifyDelegatesAboutConnection:conx didConnect:NO];
        }

        
        echo("...updating flags, notifying delegates");
        self.isRefreshing = NO;
        [self _notifyDelegatesConnectionsRefreshDidEnd];
    }
}


/////////////////////////////////////////////////////////////////////////
#pragma mark - Protected
/////////////////////////////////////////////////////////////////////////

/** Adds/removes the Connection's host to the MIDINetworkSession. Updates the enabled flag in both it and the it's corresponding source/destination pair since they are coupled */
- (void)_setStateForNetworkConnection:(_MFMIDINetworkConnection *)conx toEnabled:(BOOL)toEnabled
{
    // Check that it isn't (happens quite frequently given the coupling of NetworkDests and NetworkSources enabled states
    if (conx.enabled == toEnabled) {
        echo("Connection %@ is already %@abled", conx, toEnabled?@"en":@"dis");
        return;
    }
    
    // Find the other in the pair to update it's flag
    _MFMIDINetworkSource *src;
    _MFMIDINetworkDestination *dest;
    if ([conx isMemberOfClass:_MFMIDINetworkSource.class])
    {
        src = (id)conx;
        for (_MFMIDINetworkDestination *aDest in self.networkDestinations) {
            if ([aDest hasSameHostAs:src])
            {
                dest = aDest;
                break;
            }
        }
    } else {
        dest = (id)conx;
        for (_MFMIDINetworkSource *aSrc in self.networkSources) {
            if ([aSrc hasSameHostAs:dest])
            {
                src = aSrc;
                break;
            }
        }
    }
    
    // They should ALWAYS be in pairs
    NSAssert(src, @"Source missing from pair. Details:\nconx: %@\nsrc: %@\ndest: %@", conx, self.networkSources, self.networkDestinations);
    NSAssert(dest, @"Destination missing from pair. Details:\nconx: %@\nsrc: %@\ndest: %@", conx, self.networkSources, self.networkDestinations);
    
    // Add just one as it enabled both of them
    if (toEnabled) {
        echo("Enabled NetworkConnection with host %@", dest.midiNetworkConnection.host);
        [_midiNetSession addConnection:dest.midiNetworkConnection];
    } else {
        echo("Disabling NetworkConnection with host %@", dest.midiNetworkConnection.host);
        [_midiNetSession removeConnection:dest.midiNetworkConnection];
    }
    
    // Update the flags without invoking the setters (again) and store if set to do so
    [src _setEnabledFlag:toEnabled];
    [dest _setEnabledFlag:toEnabled];
    if (_restorePreviousConnectionStates)
    {
        [self _storeConnectionEnabledState:src];
        [self _storeConnectionEnabledState:dest];
    }
}

//---------------------------------------------------------------------

- (void)_setStateForEndpointConnection:(_MFMIDIEndpointConnection *)conx toEnabled:(BOOL)toEnabled
{
    [conx _setEnabledFlag:toEnabled];
    if (_restorePreviousConnectionStates)
        [self _storeConnectionEnabledState:conx];
}


/////////////////////////////////////////////////////////////////////////
#pragma mark - Additional Privates
/////////////////////////////////////////////////////////////////////////

/** Scans CoreMIDIs Endpoints updating our list and making MIDIConnection objects for non-network connections. Also removes Endpoints and related Connections no longer available and notifies delegates of connection changes. Does NOT do a Bonjour rescan. This is a synchronous operation. */
- (void)_refreshConnectionsForMIDIEndpoints
{
    echo("Scanning Endpoints...");
    
    const NSUInteger destinationCnt = MIDIGetNumberOfDestinations();
    const NSUInteger sourceCnt      = MIDIGetNumberOfSources();
    
    // Track which endpoints are added/removed so we can do our delegate notifications
    NSMutableArray *srcEndpointsToRemove = [NSMutableArray arrayWithArray:_sourceEndpoints];
    NSMutableArray *destEndpointsToRemove = [NSMutableArray arrayWithArray:_destinationEndpoints];
    
    /////////////////////////////////////////
    // DESTINATIONS
    /////////////////////////////////////////
    
    echo(@"...%i destination(s) found", (int)destinationCnt);
    for (NSUInteger index = 0; index < destinationCnt; ++index)
    {
        MIDIEndpointRef endpoint = MIDIGetDestination(index);
        NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
        
        // Skip virtuals
        if ([self _endpointIsForVirtualConnection:endpoint]) {
            [srcEndpointsToRemove removeObject:endpointObj]; //see notes below
            echo("...Endpoint %@ is Virtual, skipping", endpointObj);
            continue;
        }
        
        // Already exists? Remove from remove list :) Effectively a no-op on that endpoint
        // Otherwise connect it
        if ([_destinationEndpoints containsObject:endpointObj]) {
            echo("...Destination Endpoint %@ already in our list", endpointObj);
            [destEndpointsToRemove removeObject:endpointObj];
        } else {
            [self _connectDestinationEndpoint:endpoint];
        }
    }
    
    /////////////////////////////////////////
    // SOURCES
    /////////////////////////////////////////
    
    echo(@"...%i source(s) found", (int)sourceCnt);
    for (NSUInteger index = 0; index < sourceCnt; ++index)
    {
        MIDIEndpointRef endpoint = MIDIGetSource(index);
        NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
        
        // Skip virtuals
        if ([self _endpointIsForVirtualConnection:endpoint]) {
            [destEndpointsToRemove removeObject:endpointObj]; //see notes below
            echo("...Endpoint %@ is Virtual, skipping", endpointObj);
            continue;
        }

        // Already exists? Remove from remove list :) Effectively a no-op on that endpoint
        // Otherwise connect it
        if ([_sourceEndpoints containsObject:endpointObj]) {
            echo("...Source Endpoint %@ already in our list", endpointObj);
            [srcEndpointsToRemove removeObject:endpointObj];
        } else {
            [self _connectSourceEndpoint:endpoint];
        }
    }
    
    // Remove the missing ones
    // NOTE: We do this last b/c Virtual "Sources" show up as MIDIDestinations and vice versa so we need to process both before we have an accurate list to remove
    for (NSNumber *endpointNum in destEndpointsToRemove) {
        [self _disconnectDestinationEndpoint:(MIDIEndpointRef)endpointNum.unsignedIntegerValue];
    }

    for (NSNumber *endpointNum in srcEndpointsToRemove) {
        [self _disconnectSourceEndpoint:(MIDIEndpointRef)endpointNum.unsignedIntegerValue];
    }
}

//---------------------------------------------------------------------

- (NSArray *)_addNetworkConnectionWithName:(NSString *)name address:(NSString *)address port:(NSUInteger)port
{
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:name address:address port:port];
    return [self _addNetworkConnectionWithHost:host];
}

//---------------------------------------------------------------------

/** @private See notes about NSNetService above. */
- (NSArray *)_addNetworkConnectionWithHost:(MIDINetworkHost *)host
{
    echo("Adding Network Source/Destination pair for host %@", host);
    
    // Get the endpoints for the MIDISession
    MIDIEndpointRef srcEndpoint = [_midiNetSession sourceEndpoint];
    MIDIEndpointRef destEndpoint = [_midiNetSession destinationEndpoint];
    
    // Look for a matching connection in our list
    // We can search either list
    _MFMIDINetworkDestination *dest = [[_MFMIDINetworkDestination alloc] initWithEndpoint:destEndpoint client:self host:host];
    _MFMIDINetworkSource *src = [[_MFMIDINetworkSource alloc] initWithEndpoint:srcEndpoint client:self host:host];
    
    NSInteger idx = [_networkDestinations indexOfObject:dest]; // uses isEqual:
    if (idx != NSNotFound) {
        return @[_networkSources[idx], _networkDestinations[idx]];
    }
    
    // Add to the list and enable if auto
    echo("...adding NetworkSource & NetworkDestination to our list.");
    _networkSources = [_networkSources arrayByAddingObject:src];
    _networkDestinations = [_networkDestinations arrayByAddingObject:dest];
    
    // Handle autoEnable. FYI they ARENT necessarily in the MIDI session if they appear here.
    // Do both even though they are coupled for futureproofing
    // The enabled flag is a smart setter and handles MIDISession stuff
    // Handle auto-enabled / restore
    [self _setEnabledStateForConnectionBasedOnSettings:src];
    [self _setEnabledStateForConnectionBasedOnSettings:dest];
    
    
    // And the delegates
    // NOTE: Why is delegate separate from connect here but for EndpointConnections? B/c for net conns we use the connection/disconnection for enabled/disabled where with Endpoint-based conns, they are always connected (we have no choice i dont think) and we use our enabled flag to determine whether to send. In the end its all b/c there is only 1 Endpoint for ALL network connections. Booooo.
   [self _notifyDelegatesAboutConnection:src didConnect:YES];
   [self _notifyDelegatesAboutConnection:dest didConnect:YES];
    
    return @[src, dest];
}

//---------------------------------------------------------------------

/** Recreates the connections and enables/disables them according to their persisted state */
- (void)_restoreManualNetworkConnections
{
    echo("Restoring persisted Manual Network Connections: ");
    NSDictionary *manualConns = [_userDefs objectForKey:_kUserDefsKeyManualConnections];
    for (NSString *name in manualConns)
    {
        NSDictionary *connDetails = manualConns[name];
        echo("Recreating Manual Network Connection '%@': %@", name, connDetails);
        
        NSArray *conns = [self _addNetworkConnectionWithName:name address:connDetails[@"address"] port:[connDetails[@"port"] integerValue]];
        [conns[0] setIsManualConnection:YES];
        [conns[1] setIsManualConnection:YES];
        // It'll be enabled/disabled automatically via the Enabled State Persistence
    }
}

//---------------------------------------------------------------------

///** Nil if not currently in our list */
//- (_MFMIDIEndpointDestination *)_existingDestinationWithEndpoint:(MIDIEntityRef)endpoint
//{
//    NSArray *matching = [_destinations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"endpoint = %u", endpoint]];
//    if (!matching || matching.count == 0) return nil;
//    return matching[0];
//}

//---------------------------------------------------------------------

/** Internally add reference for a newly discovered/created endpoint. Notify delegates 
    @return The created connection object or nil if it was a network endpoint
 */
- (_MFMIDIEndpointDestination *)_connectDestinationEndpoint:(MIDIEndpointRef)endpoint
{
    NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
    
    // Uniqueness is handled by the NSMutableArray
    [_destinationEndpoints addObject:endpointObj];
    
    if (_MFIsNetworkSessionEndpoint(endpoint))
    {
        echo("Added Destination Endpoint %@ (is a Network Endpoint - NOT creating MIDIDestination)", endpointObj);
        // Dont create our objects for Network endpoints as we treat the individual Network Hosts as "Connections" which requires some re-interpreting of how CoreMIDI works.  CoreMIDI has ALL network connections go through a single endpoint which is a bit weary IMO
        return nil;
    }
    else
    {
        _MFMIDIEndpointDestination *dest = [[_MFMIDIEndpointDestination alloc] initWithEndpoint:endpoint client:self];
        _endpointDestinations = (id)[_endpointDestinations arrayByAddingObject:dest];
        
        [self _setEnabledStateForConnectionBasedOnSettings:dest];
        
        echo(@"Added Destination Endpoint called \"%@\" (enabled=%@)", endpointObj, dest.name, dest.enabled?@"YES":@"NO");
        
        // Notify delegates
        [self _notifyDelegatesAboutConnection:dest didConnect:YES];
        
        return dest;
    }
}

//---------------------------------------------------------------------

/** Internally add reference for a newly discovered/created endpoint. Notify delegates
 @return The created connection object or nil if it was a network endpoint
 */
- (_MFMIDIEndpointSource *)_connectSourceEndpoint:(MIDIEndpointRef)endpoint
{
    NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
    
    // Uniqueness is handled by the NSMutableArray
    [_sourceEndpoints addObject:endpointObj];
    
    if (_MFIsNetworkSessionEndpoint(endpoint))
    {
        echo("Added Source Endpoint %@ (is a Network Endpoint - NOT creating MIDISource)", endpointObj);
        return nil;
    }
    else
    {
        _MFMIDIEndpointSource *src = [[_MFMIDIEndpointSource alloc] initWithEndpoint:endpoint client:self];
        _endpointSources = (id)[_endpointSources arrayByAddingObject:src];
        
        [self _setEnabledStateForConnectionBasedOnSettings:src];
        
        echo(@"Added Source Endpoint %@ called \"%@\" (enabled=%@)", endpointObj, src.name, src.enabled?@"YES":@"NO");
        
        [self _notifyDelegatesAboutConnection:src didConnect:YES];
        return src;
    }
}

//---------------------------------------------------------------------

/** Internally remove the references for an endpoint that has been removed by CoreMIDI. Notify delegates */
- (void)_disconnectDestinationEndpoint:(MIDIEndpointRef)endpoint;
{
    NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
    
    [_destinationEndpoints removeObject:endpointObj];
    echo("Disconnected Endpoint %@", endpointObj);
    
    // ~~There could be a several MIDIDestination objects with the same endpoint, particularly Network ones~~ No longer true I dont think b/c we track them in separate ivars now. But just in case we'll leave this...
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"endpoint == %u", (unsigned)endpoint];
    NSArray *destObjects = [_endpointDestinations filteredArrayUsingPredicate:pred];
    for (id<MFMIDIDestination>dest in destObjects)
    {
        NSMutableArray *dests = _endpointDestinations.mutableCopy;
        [dests removeObject:dest];
        _endpointDestinations = (id)[NSArray arrayWithArray:dests];
        echo("...and related MIDIDestination %@", dest.name);
        
        // Notify delegates
        [self _notifyDelegatesAboutConnection:dest didConnect:NO];
    }
}

//---------------------------------------------------------------------

- (void)_disconnectSourceEndpoint:(MIDIEndpointRef)endpoint;
{
    NSObject *endpointObj = _EP2Obj(endpoint); // normalise 32bit and 64bit heterogony
    
    [_sourceEndpoints removeObject:endpointObj];
    echo("Disconnected Endpoint %@", endpointObj);
    
    // ~~There could be a several MIDISource objects with the same endpoint, particularly Network ones~~ No longer true I dont think b/c we track them in separate ivars now. But just in case we'll leave this...
#if __LP64__
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"endpoint == %lu", endpoint];
#else
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"endpoint == %p", endpoint];
#endif 
    
    NSArray *srcObjects = [_endpointSources filteredArrayUsingPredicate:pred];
    for (id<MFMIDISource>src in srcObjects)
    {
        NSMutableArray *srcs = _endpointSources.mutableCopy;
        [srcs removeObject:src];
        _endpointSources = (id)[NSArray arrayWithArray:srcs];
        echo("...and related MIDISource %@", src.name);
        
        // Notify delegates
        [self _notifyDelegatesAboutConnection:src didConnect:NO];
    }
}


//---------------------------------------------------------------------

/** Shorthand. Checks conformity to determin if it's a source or destination. BOOL specifies whether it's connect or disconnect */
- (void)_notifyDelegatesAboutConnection:(id<MFMIDIConnection>)conx didConnect:(BOOL)isConnect
{
    echo("...DELEGATES: Connection %@ did %@CONNECT", conx, isConnect?@"":@"DIS");
    
    BOOL isSource = [conx conformsToProtocol:@protocol(MFMIDISource)];
    
    // Notify delegates
    if (isSource && isConnect)
    {
        for (id<MFMIDISessionDelegate>delegate in _delegates) {
            if ([delegate respondsToSelector:@selector(MIDISession:didAddSource:)]) {
                [delegate MIDISession:self didAddSource:(id)conx];
            }
        }
    }
    else if (isSource && !isConnect)
    {
        for (id<MFMIDISessionDelegate>delegate in _delegates) {
            if ([delegate respondsToSelector:@selector(MIDISession:didRemoveSource:)]) {
                [delegate MIDISession:self didRemoveSource:(id)conx];
            }
        }
    }
    else if (!isSource && isConnect)
    {
        for (id<MFMIDISessionDelegate>delegate in _delegates) {
            if ([delegate respondsToSelector:@selector(MIDISession:didAddDestination:)]) {
                [delegate MIDISession:self didAddDestination:(id)conx];
            }
        }
    }
    else if (!isSource && !isConnect)
    {
        for (id<MFMIDISessionDelegate>delegate in _delegates) {
            if ([delegate respondsToSelector:@selector(MIDISession:didRemoveDestination:)]) {
                [delegate MIDISession:self didRemoveDestination:(id)conx];
            }
        }
    }
    
}

//---------------------------------------------------------------------

- (void)_notifyDelegatesConnectionRefreshDidBegin
{
    // Tell delegates
    for (id<MFMIDISessionDelegate> delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(MIDISessionDidBeginConnectionRefresh:)]) {
            [delegate MIDISessionDidBeginConnectionRefresh:self];
        }
    }
}

//---------------------------------------------------------------------

- (void)_notifyDelegatesConnectionsRefreshDidEnd
{
    // Tell delegates
    for (id<MFMIDISessionDelegate> delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(MIDISessionDidEndConnectionRefresh:)]) {
            [delegate MIDISessionDidEndConnectionRefresh:self];
        }
    }
}

//---------------------------------------------------------------------

- (BOOL)_endpointIsForVirtualConnection:(MIDIEndpointRef)endpoint
{
    NSArray *virtConx = [self->_virtualSources arrayByAddingObjectsFromArray:self->_virtualDestinations];
    for (id<MFMIDIConnection> conx in virtConx) {
        if (conx.endpoint == endpoint) return YES;
    }
    return NO;
}

//---------------------------------------------------------------------

/** YES if there exists a userdefs value for the conx */
- (BOOL)_hasPreviouslyStoredEnabledStateForConnection:(_MFMIDIConnection *)conx
{
    NSString *idForConx = [self _storageIDForConnection:conx];
    NSDictionary *lookup = [_userDefs objectForKey:_kUserDefsKeyEnabledStates];
    return [lookup objectForKey:idForConx] != nil;
}

//---------------------------------------------------------------------

/** Check the persistence for the value set for the connection */
- (void)_setEnabledStateForConnectionBasedOnSettings:(_MFMIDIConnection *)conx
{
    NSString *idForConx = [self _storageIDForConnection:conx];

    // Look up the stored value.  If non use the autoEnable flags defaulting to NO if none
    NSDictionary *lookup = [_userDefs objectForKey:_kUserDefsKeyEnabledStates];
    if (_restorePreviousConnectionStates && [lookup objectForKey:idForConx])
    {
        conx.enabled = [lookup[idForConx] boolValue];
        echo("Restored Connection <%@> enabled state to %@", conx.name, conx.enabled?@"YES":@"NO");
        
    }
    else
    {
        conx.enabled = [conx conformsToProtocol:@protocol(MFMIDISource)] ? _autoEnableSources : _autoEnableDestinations;
        if (conx.enabled) {
            echo("Connection <%@> auto-enabled", conx.name);
        }
        
        // Store the auto state too if we're 'sposed to
        if (_restorePreviousConnectionStates)
            [self _storeConnectionEnabledState:conx];
    }
}

//---------------------------------------------------------------------

- (void)_storeConnectionEnabledState:(_MFMIDIConnection *)conx
{
    echo(@"Storing Connection <%@> enabled state: %@", conx.name, conx.enabled?@"YES":@"NO");
    NSString *idForConx = [self _storageIDForConnection:conx];
    
    // Look for the entry creating it if needed
    NSMutableDictionary *lookup = [[_userDefs objectForKey:_kUserDefsKeyEnabledStates] mutableCopy];
    if (!lookup) lookup = [NSMutableDictionary dictionary];
    lookup[idForConx] = @(conx.enabled);
    [_userDefs setObject:lookup forKey:_kUserDefsKeyEnabledStates];
    [_userDefs synchronize];
}

//---------------------------------------------------------------------

/** Create a reasonable unique id string given what we have. */
- (NSString *)_storageIDForConnection:(_MFMIDIConnection *)conx
{
    NSString *idStr;
    // Use the name but try to avoid collisions. Don't include the host address so we can be smart about the same machine connecting on different IP addresses
    if ([conx isKindOfClass:[_MFMIDINetworkSource class]])
    {
        idStr = [NSString stringWithFormat:@"%@::%@::%@", @"network", @"source", conx.name];
    }
    else if ([conx isKindOfClass:[_MFMIDINetworkDestination class]])
    {
        idStr = [NSString stringWithFormat:@"%@::%@::%@", @"network", @"destination", conx.name];
    }
    else if ([conx isKindOfClass:[_MFMIDIEndpointSource class]])
    {
        idStr = [NSString stringWithFormat:@"%@::%@::%@", @"endpoint", @"source", conx.name];
    }
    else if ([conx isKindOfClass:[_MFMIDIEndpointDestination class]])
    {
        idStr = [NSString stringWithFormat:@"%@::%@::%@", @"endpoint", @"destination", conx.name];
    }
    
    return idStr;
}

//---------------------------------------------------------------------

//- (void)_reconnectPreviousManualNetworkConnections
//{
//    NSArray *conxDetailsList = [_userDefs objectForKey:@"co.air-craft.MIDIFish.connections.network"];
//    for (NSDictionary *conxDetails in conxDetailsList)
//    {
//        // Creates a source/destination pair. No need to do each or differentiate
//        // Also no need to handle enabled states as that's covered elsewhere
//        [self addNetworkConnectionWithName:conxDetails[@"name"] address:conxDetails[@"address"] port:[(NSNumber *)conxDetails[@"port"] unsignedIntegerValue]];
//    }
//}
//
////---------------------------------------------------------------------
//
//- (void)_storeManualNetworkConnection:(_MFMIDINetworkConnection)connection
//{
//    
//}

//---------------------------------------------------------------------



@end
