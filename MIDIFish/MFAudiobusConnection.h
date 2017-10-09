//
//  MFAudiobusConnection.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 15/03/2017.
//
//

#import <Foundation/Foundation.h>
#import "MFProtocols.h"
@class ABAudiobusController;

/**
 @abstract
 */
@interface MFAudiobusConnection : NSObject <MFMIDIConnection>

/** Uses AB title property as AB name is more an ID */
@property (nonatomic, strong, readonly) NSString *name;

- (id)initWithName:(NSString *)name title:(NSString *)title controller:(ABAudiobusController *)abController;





@end
