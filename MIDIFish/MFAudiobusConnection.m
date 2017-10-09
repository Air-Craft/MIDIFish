//
//  MFAudiobusConnection.m
//  AC-Sabre
//
//  Created by Hari Karam Singh on 15/03/2017.
//
//

#import "MFAudiobusConnection.h"

@implementation MFAudiobusConnection

@synthesize enabled=_enabled;

- (id)initWithName:(NSString *)name title:(NSString *)title controller:(ABAudiobusController *)abController
{
    [NSException raise:NSGenericException format:@"Abstract!"];
    return nil;
}

//---------------------------------------------------------------------

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MFAudioBusConnection: name=%@>", _name];
}



@end
