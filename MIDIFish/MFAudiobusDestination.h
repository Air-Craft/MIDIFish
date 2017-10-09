//
//  MFAudiobusDestination.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 15/03/2017.
//
//

#import "MFAudiobusConnection.h"

@class ABMIDISenderPort;

@interface MFAudiobusDestination : MFAudiobusConnection <MFMIDIMessageSender>

// Readonly as for audiobus we'll keep the management within their environment as to not confuse users. 
@property (nonatomic, readonly) BOOL enabled;

/** Ref to the audiobus port for your convenvience */
@property (nonatomic, strong, readonly) ABMIDISenderPort *abMIDISenderPort;

@end
