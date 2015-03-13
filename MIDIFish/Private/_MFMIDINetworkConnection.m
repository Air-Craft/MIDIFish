//
//  _MFMIDINetworkConnection.m
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <CoreMIDI/MIDINetworkSession.h>
#import "MFMIDIClient_Private.h"
#import "_MFMIDINetworkConnection.h"
#import "_MFUtilities.h"


/////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////

@implementation _MFMIDINetworkConnection

@synthesize host=_host;

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(MFMIDIClient *__weak)client host:(MIDINetworkHost *)host
{
    self = [super initWithEndpoint:endpoint client:client];
    if (self) {
        _host = host;
        _midiNetworkConnection = [MIDINetworkConnection connectionWithHost:host];
    }
    return self;
}

//---------------------------------------------------------------------

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(MFMIDIClient *__weak)client netService:(NSNetService *)netService
{
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:netService.name netService:netService];
    return [self initWithEndpoint:endpoint client:client host:host];
}


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