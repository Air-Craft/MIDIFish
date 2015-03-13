//
//  MFNonFatalException.m
//  AC-Sabre
//
//  Created by Hari Karam Singh on 02/02/2015.
//
//

#import "MFNonFatalException.h"

@implementation MFNonFatalException

+ (instancetype)exceptionWithOSStatus:(OSStatus)osStatus reason:(NSString *)reason
{
    return [[self alloc] initWithOSStatus:osStatus reason:reason];
}

//---------------------------------------------------------------------

- (instancetype)initWithOSStatus:(OSStatus)osStatus reason:(NSString *)reason
{
    self = [super initWithName:NSStringFromClass(self.class) reason:reason userInfo:nil];
    if (self) {
        _osStatus = osStatus;
    }
    return self;
}

//---------------------------------------------------------------------

- (NSString *)osStatusAsString
{
    char str[10]="";
    OSStatus error = _osStatus;
    
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig((u_int32_t)error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else {
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    }
    
    return [NSString stringWithUTF8String:str];
}


@end
