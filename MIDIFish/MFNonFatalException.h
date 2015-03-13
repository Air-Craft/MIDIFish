//
//  MFNonFatalException.h
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import <Foundation/Foundation.h>

@interface MFNonFatalException : NSException

+ (instancetype)exceptionWithOSStatus:(OSStatus)osStatus reason:(NSString *)reason;
- (instancetype)initWithOSStatus:(OSStatus)osStatus reason:(NSString *)reason;

@property (nonatomic, readonly) OSStatus osStatus;

- (NSString *)osStatusAsString;

@end
