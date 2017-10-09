//
//  _MFMIDIConnection.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import "_MFMIDIConnection.h"
#import "_MFUtilities.h"

@implementation _MFMIDIConnection

- (instancetype)initWithEndpoint:(MIDIEndpointRef)endpoint client:(__weak MFMIDISession *)client
{
    self = [super init];
    if (self) {
        _endpoint = endpoint;
        _client = client;
    }
    return self;
}

//---------------------------------------------------------------------

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@ (endpoint=%@, enabled=%@)>", NSStringFromClass(self.class), self.name, @(self.endpoint), self.enabled?@"YES":@"NO"];
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

@synthesize endpoint=_endpoint;
@synthesize isVirtualConnection=_isVirtualConnection;
@synthesize enabled=_enabled;


- (NSString *)name
{
    return _MFGetMIDIObjectDisplayName(self.endpoint);
}

//---------------------------------------------------------------------

// Create a setter for MIDISession's readwrite override of the property
- (void)setIsVirtualConnection:(BOOL)isVirtual { _isVirtualConnection = isVirtual; }



/////////////////////////////////////////////////////////////////////////
#pragma mark - Protected
/////////////////////////////////////////////////////////////////////////

/** Update the enabled ivar alone - ie without updating MIDINetworkSession */
- (void)_setEnabledFlag:(BOOL)enabled
{
    _enabled = enabled;
}


@end
