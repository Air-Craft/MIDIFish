//
//  MFAudiobusDestination.m
//  AC-Sabre
//
//  Created by Hari Karam Singh on 15/03/2017.
//
//

#import "MFAudiobusDestination.h"
#import "Audiobus/Audiobus.h"

// Channelised Logging
#undef echo
#if LOG_MIDIFISH
#   define echo(fmt, ...) NSLog((@"[MIDIFISH] " fmt), ##__VA_ARGS__);
#else
#   define echo(...)
#endif
#undef warn
#define warn(fmt, ...) NSLog((@"[MIDIFISH] WARNING: " fmt), ##__VA_ARGS__);



@implementation MFAudiobusDestination
{
}

- (id)initWithName:(NSString *)name title:(NSString *)title controller:(ABAudiobusController *)abController
{
    self = [super init];
    if (self) {
        _abMIDISenderPort = [[ABMIDISenderPort alloc] initWithName:name title:title];
        [abController addMIDISenderPort:_abMIDISenderPort];
    }
    return self;
}


/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

- (NSString *)name
{
    // AB name is more an ID
    return _abMIDISenderPort.title;
}

//---------------------------------------------------------------------

- (BOOL)enabled
{
    return _abMIDISenderPort.connected;
}


/////////////////////////////////////////////////////////////////////////
#pragma mark - <MFMIDIMessageSender>
/////////////////////////////////////////////////////////////////////////

- (void)sendMIDIMessage:(MFMIDIMessage *)message
{
    if (!self.enabled) {
        echo(@"Skipping send message on Audiobus destination %@ (disabled)", self)
        return;
    }
    [message toMIDIPacketList:^(MIDIPacketList *packetList) {
        ABMIDIPortSendPacketList(_abMIDISenderPort, packetList);
    }];
}

//---------------------------------------------------------------------

- (void)sendMIDIPacketList:(MIDIPacketList *)packetList
{
    if (!self.enabled) {
        echo(@"Skipping send message on Audiobus destination %@ (disabled)", self)
        return;
    }
    
    ABMIDIPortSendPacketList(_abMIDISenderPort, packetList);
}



@end
