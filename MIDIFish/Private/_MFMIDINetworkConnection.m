//
//  _MFMIDINetworkConnection.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <CoreMIDI/MIDINetworkSession.h>
#import "MFMIDISession_Private.h"
#import "_MFMIDINetworkConnection.h"
#import "_MFUtilities.h"

static NSMutableArray *_tmpRetainer;

/////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////

@implementation _MFMIDINetworkConnection


- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(MFMIDISession *__weak)client host:(MIDINetworkHost *)host
{
    self = [super initWithEndpoint:endpoint client:client];
    if (self) {
        _host = host;
        _midiNetworkConnection = [MIDINetworkConnection connectionWithHost:host];
        if (!_tmpRetainer) { _tmpRetainer = [NSMutableArray array]; }
        [_tmpRetainer addObject:_midiNetworkConnection];
    }
    return self;
}

//---------------------------------------------------------------------

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(MFMIDISession *__weak)client netService:(NSNetService *)netService
{
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:netService.name netService:netService];
    return [self initWithEndpoint:endpoint client:client host:host];
}

//---------------------------------------------------------------------

- (void)dealloc
{
    // debugging badaccess on midiNetCon dealloc
    _host = nil;
    _midiNetworkConnection = nil;
}

//---------------------------------------------------------------------

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@ (endpoint=%@, enabled=%@, host=%@)>", NSStringFromClass(self.class), self.name, @(self.endpoint), self.enabled?@"YES":@"NO", self.host];
}


/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

@synthesize host=_host;
@synthesize isManualConnection=_isManualConnection;

// Create a setter for MIDISession's readwrite override of the property
- (void)setIsManualConnection:(BOOL)isManual { _isManualConnection = isManual; }


/////////////////////////////////////////////////////////////////////////
#pragma mark - Overrides
/////////////////////////////////////////////////////////////////////////

/** @override */
- (BOOL)isNetworkConnection { return YES; }

//---------------------------------------------------------------------

/** 
 @override
 NetService name > host user-tagged "name" > endpoint name
 */
- (NSString *)name
{
    if (self.host.netServiceName.length)
        return self.host.netServiceName;
    if (self.host.name.length)
        return self.host.name;
    return _MFGetMIDIObjectDisplayName(self.endpoint);
}

//---------------------------------------------------------------------

/** @override */
- (BOOL)isEqual:(_MFMIDINetworkConnection *)object
{
    // Check they are the same class
    if (![object.class isEqual:self.class])
        return NO;
    
    return [self hasSameHostAs:object];
}

//---------------------------------------------------------------------

- (void)setEnabled:(BOOL)enabled
{
    // Everything runs through the client
    [self.client _setStateForNetworkConnection:self toEnabled:enabled];
}



/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////

- (BOOL)hasSameHostAs:(_MFMIDINetworkConnection *)otherConx
{
    // If they arent the same address then don't both
    if (![otherConx.host hasSameAddressAs:self.host]) {
        return NO;
    }
    else {
        // If netService stuff is filled out in one of them then check the name/domain. If they aren't then dont do this check as it might be a manual connection
        if ( (otherConx.host.netServiceName && otherConx.host.netServiceName.length) ||
            (self.host.netServiceName && self.host.netServiceName.length) )
        {
            return [otherConx.host.netServiceName isEqualToString:self.host.netServiceName] &&
            [otherConx.host.netServiceDomain isEqualToString:self.host.netServiceDomain];
        }
        
        // Check the user name tag if it's available
        if ( (otherConx.host.name && otherConx.host.name.length) ||
            (self.host.name && self.host.name.length) )
        {
            return [otherConx.host.name isEqualToString:self.host.name];
        }
        
        // Otherwise it's a YES because they have the same address, we've determined already
        return YES;
    }
}


@end
