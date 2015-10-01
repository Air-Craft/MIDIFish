//
//  _MFUtilities.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import "_MFUtilities.h"


NSString *_MFGetMIDIObjectStringProperty(MIDIObjectRef obj, CFStringRef property)
{
    CFStringRef string = nil;
    OSStatus s = MIDIObjectGetStringProperty(obj, property, ( CFStringRef *)&string);
    if ( s != noErr )
    {
        return @"<Unknown>";
    }
    return (NSString *)CFBridgingRelease(string);
}

//---------------------------------------------------------------------

NSString *_MFGetMIDIObjectDisplayName(MIDIObjectRef obj)
{
    return _MFGetMIDIObjectStringProperty(obj, kMIDIPropertyDisplayName);
}

//---------------------------------------------------------------------

BOOL _MFIsNetworkSessionEndpoint(MIDIEndpointRef ref)
{
    MIDIEntityRef entity = 0;
    MIDIEndpointGetEntity(ref, &entity);
    
    BOOL hasMidiRtpKey = NO;
    CFPropertyListRef properties = nil;
    OSStatus s = MIDIObjectGetProperties(entity, &properties, true);
    if (!s)
    {
        NSDictionary *dictionary = (__bridge NSDictionary *)(properties);
        hasMidiRtpKey = [dictionary valueForKey:@"apple.midirtp.session"] != nil;
        CFRelease(properties);
    }
    
    return hasMidiRtpKey;
}