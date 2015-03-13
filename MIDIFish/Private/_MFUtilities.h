//
//  _MFUtilities.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

/////////////////////////////////////////////////////////////////////////
#pragma mark - Error checking macro
/////////////////////////////////////////////////////////////////////////
// Exception-based
#ifndef _MFCheckErr
#define _MFCheckErr(osStatus, reasonFmt, ...) { \
if (osStatus != noErr) { \
NSString *str = [NSString stringWithFormat:reasonFmt, ##__VA_ARGS__];\
@throw [MFNonFatalException exceptionWithOSStatus:osStatus reason:str]; \
} \
}
#endif

#ifdef __cplusplus
extern "C" {
#endif

/////////////////////////////////////////////////////////////////////////
#pragma mark - Utility Function
/////////////////////////////////////////////////////////////////////////

extern NSString *_MFGetMIDIObjectStringProperty(MIDIObjectRef obj, CFStringRef property);

extern NSString *_MFGetMIDIObjectDisplayName(MIDIObjectRef obj);


extern BOOL _MFIsNetworkSessionEndpoint(MIDIEndpointRef ref);



#ifdef __cplusplus
}
#endif
