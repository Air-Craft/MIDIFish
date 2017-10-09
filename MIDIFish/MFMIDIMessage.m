//
//  MFMIDIMessage.m
//  MIDIFish
//
//  Created by Hari Karam Singh on 01/02/2015.
//
//
#import "MFMIDIMessage.h"

/** 
 Lots of snippets adapted from https://github.com/JRHeaton/MIDIKit. Thank you!
 */
@implementation MFMIDIMessage
{
    NSMutableData *_data;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Life Cycle
/////////////////////////////////////////////////////////////////////////

- (instancetype)init
{
    self = [super init];
    if (self) {
        _data = [NSMutableData dataWithCapacity:3];
        ((UInt8 *)_data.mutableBytes)[0] = 0;
        ((UInt8 *)_data.mutableBytes)[1] = 0;
        ((UInt8 *)_data.mutableBytes)[2] = 0;
    }
    return self;
}

//---------------------------------------------------------------------

+ (instancetype)messageWithType:(MFMIDIMessageType)type channel:(UInt8)channel
{
    NSAssert(channel >= 0 && channel <= 15, @"Channel must be 0-15");
    channel = MIN(MAX(0, channel), 15); // sanitise anyway in case NSAsserts are off
    MFMIDIMessage *me = self.new;
    me.status = type | channel;
    return me;
}

//---------------------------------------------------------------------

+ (instancetype)messageWithBytes:(UInt8)status :(UInt8)data1 :(UInt8)data2
{
    MFMIDIMessage *me = [self new];
    me.status = status;
    me.data1 = data1;
    me.data2 = data2;
    return me;
}

//---------------------------------------------------------------------

+ (instancetype)messageWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    NSParameterAssert(data);
    self = [super init];
    if (self) {
        _data = [data isKindOfClass:[NSMutableData class]] ? data : data.mutableCopy;
    }
    return self;
}

//---------------------------------------------------------------------

+ (instancetype)messageWithPacket:(MIDIPacket *)packet
{
    return [[self alloc] initWithPacket:packet];
}

/** @private */
- (instancetype)initWithPacket:(MIDIPacket *)packet
{
    if(!(self = [self init])) return nil;
    
    [self.data setLength:packet->length];
    memcpy(self.bytes, packet->data, packet->length);
    
    return self;
}

//---------------------------------------------------------------------

+ (instancetype)messageWithType:(MFMIDIMessageType)type
{
    MFMIDIMessage *me = [[self alloc] init];
    me.type = type;
    return me;
}

//---------------------------------------------------------------------

+ (NSArray *)messagesWithData:(NSData *)data
{
    NSMutableArray *me = [NSMutableArray array];
    
    static const NSUInteger NUM_TYPES = 8;
    static MFMIDIMessageType handledTypes[NUM_TYPES] = {
        kMFMIDIMessageTypeNoteOff,
        kMFMIDIMessageTypeNoteOn,
        kMFMIDIMessageTypePolyphonicAftertouch,
        kMFMIDIMessageTypeControlChange,
        kMFMIDIMessageTypeProgramChange,
        kMFMIDIMessageTypeChannelAftertouch,
        kMFMIDIMessageTypePitchbend,
        kMFMIDIMessageTypeSysex
    };
    
    // Run through the loop, check the type byte, and handle the data accordingly building messages along the way
    UInt8 *buff = (UInt8 *)data.bytes;
    UInt8 off = 0;
    while(off < data.length) {
        UInt8 *buf = &buff[off];
        
        bool found = false;
        for(int i=0;i<NUM_TYPES;++i) {
            MFMIDIMessageType type = handledTypes[i];
            
            if((buf[0] & 0xf0) == type) {
                UInt8 goodLen = (data.length - off);
                switch (type) {
                    case kMFMIDIMessageTypeSysex:
                        for(NSUInteger x=0;x<goodLen;++x) {
                            if(buf[x] == 0xF7) { // EOX
                                goodLen = x + 1;
                                goto done;
                            }
                        }
                        
                        break;
                    default: goodLen = MIN(3, goodLen); // standard MIDI message
                }
            done:
                [me addObject:[MFMIDIMessage messageWithData:[NSData dataWithBytes:buf length:goodLen]]];
                
                off += goodLen;
                found = true;
            }
        }
        if (found)
            found = false;
        else
            off++;
    }
    
    return me;
}

//---------------------------------------------------------------------

+ (NSArray *)messagesWithPacket:(MIDIPacket *)packet
{
    return [self messagesWithData:[NSData dataWithBytesNoCopy:packet->data length:packet->length freeWhenDone:NO]];
}

+ (NSArray *)messagesWithPacketList:(MIDIPacketList *)list {
    NSMutableArray *me = [NSMutableArray array];
    
    MIDIPacket *packet = &list->packet[0];
    for (int i=0;i<list->numPackets;++i) {
        [me addObjectsFromArray:[self messagesWithPacket:packet]];
        
        packet = MIDIPacketNext(packet);
    }
    
    return me.count ? me.copy : nil;
}

//---------------------------------------------------------------------

- (id)copyWithZone:(NSZone *)zone
{
    // Be sure to copy the bytes too
    NSMutableData *dataCopy = [NSMutableData dataWithBytes:self.data.bytes length:self.data.length];
    MFMIDIMessage *copy = [[self.class allocWithZone:zone] initWithData:dataCopy];
    return copy;
}

//---------------------------------------------------------------------

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[MFMIDIMessage class]] && [self.data isEqualToData:((MFMIDIMessage *)object).data];
}

//---------------------------------------------------------------------

- (NSString *)description {
    if(self.empty) {
        return [NSString stringWithFormat:@"%@ [Empty Message]%@", [super description], !self.length ? @"" : [NSString stringWithFormat:@", length=%lu", (unsigned long)self.length]];
    }
    
    NSString *typeName;
    NSString *dataInfo;
    switch (self.type) {
        case kMFMIDIMessageTypeSysex:
            typeName = @"Sysex";
            dataInfo = [self _hexStringForData:self.data maxByteCount:20];
            goto rawstyle;
        
        default:
            typeName = @"Unknown";
            dataInfo = [self _hexStringForData:self.data maxByteCount:20];
            goto rawstyle;
            
        case kMFMIDIMessageTypeChannelAftertouch:
            typeName = @"Channel Aftertouch";
            dataInfo = [NSString stringWithFormat:@"pressure=%d", self.self.channelPressure];
            
            break;
        case kMFMIDIMessageTypeControlChange:
            typeName = @"Control Change";
            dataInfo = [NSString stringWithFormat:@"key=%d, value=%d", self.controller, self.value];
            
            break;
        case kMFMIDIMessageTypeNoteOff:
            typeName = @"Note Off";
            dataInfo = [NSString stringWithFormat:@"key=%d, velocity=%d", self.key, self.velocity];
            
            break;
        case kMFMIDIMessageTypeNoteOn:
            typeName = @"Note On";
            dataInfo = [NSString stringWithFormat:@"key=%d, velocity=%d", self.key, self.velocity];
            
            break;
        case kMFMIDIMessageTypePitchbend:
            typeName = @"Pitch Bend";
            dataInfo = [NSString stringWithFormat:@"value=%d", self.pitchbendValue];
            
            break;
        case kMFMIDIMessageTypePolyphonicAftertouch:
            typeName = @"Polyphonic Aftertouch";
            dataInfo = [NSString stringWithFormat:@"key=%d, pressure=%d", self.key, self.keyPressure];
            
            break;
        case kMFMIDIMessageTypeProgramChange:
            typeName = @"Program Change";
            dataInfo = [NSString stringWithFormat:@"programNumber=%d", self.programNumber];
            
            break;
    }
    
friendlystyle:
    if(self.type != kMFMIDIMessageTypeSysex && self.length > 3) {
        dataInfo = [dataInfo stringByAppendingString:[self _hexStringForData:self.data maxByteCount:20]];
    }
    return [NSString stringWithFormat:@"<%@: ch=%i, %@>", typeName, (int)self.channel, dataInfo];

    
rawstyle:
    return [NSString stringWithFormat:@"<%@ status=0x%x, length=0x%lx, %@>", typeName, self.status, (unsigned long)self.length, dataInfo];

}



/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

- (BOOL)isEmpty
{
    if(!self.length) return YES;
    for(NSUInteger i=0;i<self.length;++i) {
        if(self.bytes[i]) return NO;
    }
    return YES;
}

//---------------------------------------------------------------------

- (NSUInteger)length
{
    return self.data.length;
}

//---------------------------------------------------------------------

- (UInt8)channel { return self.length ? (self.status & 0x0F) : 0; }

- (void)setChannel:(UInt8)channel
{
    NSAssert(channel >= 0 && channel <= 15, @"Channel must be 0-15!");
    channel = MIN(MAX(0, channel), 15); // sanitise anyway in case NSAsserts are off
    [self setByte:(self.type | channel) atIndex:0];
}

//---------------------------------------------------------------------

- (MFMIDIMessageType)type
{
    return self.length ? (MFMIDIMessageType)(self.status & 0xF0) : 0;
}

- (void)setType:(MFMIDIMessageType)type
{
    [self setByte:(type | self.channel) atIndex:0];
}

//---------------------------------------------------------------------

- (UInt8)status { return self.length ? self.bytes[0] : 0; }

- (void)setStatus:(UInt8)status
{
    [self setByte:status atIndex:0];
}

//---------------------------------------------------------------------

// All these are the same
- (UInt8)key { return self.length > 1 ? self.bytes[1] : 0; }
- (UInt8)controller { return self.length > 1 ? self.bytes[1] : 0; }
- (UInt8)data1 { return self.length > 1 ? self.bytes[1] : 0; }

- (void)setKey:(UInt8)val { [self setByte:val & 0x7f atIndex:1]; }
- (void)setController:(UInt8)val { [self setByte:val & 0x7f atIndex:1]; }
- (void)setData1:(UInt8)val { [self setByte:val & 0x7f atIndex:1]; }

//---------------------------------------------------------------------

- (UInt8)velocity { return self.length > 2 ? self.bytes[2] : 0; }
- (UInt8)value { return self.length > 2 ? self.bytes[2] : 0; }
- (UInt8)programNumber { return self.length > 2 ? self.bytes[2] : 0; }
- (UInt8)channelPressure { return self.length > 2 ? self.bytes[2] : 0; }
- (UInt8)keyPressure { return self.length > 2 ? self.bytes[2] : 0; }
- (UInt8)data2 { return self.length > 2 ? self.bytes[2] : 0; }

- (void)setVelocity:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }
- (void)setValue:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }
- (void)setProgramNumber:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }
- (void)setChannelPressure:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }
- (void)setKeyPressure:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }
- (void)setData2:(UInt8)val { [self setByte:val & 0x7f atIndex:2]; }

//---------------------------------------------------------------------

- (UInt16)doublePrecisionValue { return (self.bytes[2] << 7) + self.bytes[1]; }
- (UInt16)pitchbendValue { return (self.bytes[2] << 7) + self.bytes[1]; }

- (void)setDoublePrecisionValue:(UInt16)value
{
    self.data2 = (value >> 7) & 0x7F;    // msb in data 2
    self.data1 = value & 0x7F;           // lsb in data 1
}
- (void)setPitchbendValue:(UInt16)value
{
    self.data2 = (value >> 7) & 0x7F;    // msb in data 2
    self.data1 = value & 0x7F;           // lsb in data 1
}

//---------------------------------------------------------------------

- (NSMutableData *)data { return _data; }

//---------------------------------------------------------------------

- (UInt8 *)bytes { return (UInt8 *)_data.mutableBytes; }


/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////


- (void)setByte:(UInt8)byte atIndex:(NSUInteger)idx
{
    if (idx >= self.length)
    {
        [self.data setLength:idx+1];
    }
    self.bytes[idx] = byte;
}

//---------------------------------------------------------------------

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)idx
{
    if ([object isKindOfClass:[NSNumber class]])
    {
        [self setByte:((NSNumber *)object).unsignedCharValue atIndex:idx];
    }
}

//---------------------------------------------------------------------

- (void)toMIDIPacketList:(void (^)(MIDIPacketList *))packetListHandler
{
    // Form a MIDIPacketList (thanks PGMIDI!)
    NSParameterAssert(self.length < 65536);
    Byte packetBuffer[self.length + 100];
    MIDIPacketList *packetList = (MIDIPacketList *)packetBuffer;
    MIDIPacket     *packet     = MIDIPacketListInit(packetList);
    
    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, self.length, self.bytes);
    
    packetListHandler(packetList);
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Additional Privates
/////////////////////////////////////////////////////////////////////////

- (NSString *)_hexStringForData:(NSData *)data maxByteCount:(NSUInteger)max
{
    NSMutableString *str = [NSMutableString string];
    
    for(NSUInteger i=0;i<MIN(max, data.length); ++i) {
        BOOL atDataEnd = (i == (data.length - 1));
        BOOL atMax = (i == (max - 1));
        [str appendFormat:@"0x%02X%@", ((unsigned char *)data.bytes)[i], (atMax && !atDataEnd) ? @", ..." : (atDataEnd ? @"" : @" ")];
    }
    
    return str;
}




@end
