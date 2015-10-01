//
//  MFMIDIMessage.h
//  MIDIFish
//
//  Created by Hari Karam Singh on 01/02/2015.
//
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

/////////////////////////////////////////////////////////////////////////
#pragma mark - Defs
/////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(UInt8, MFMIDIMessageType) {
    kMFMIDIMessageTypeNoteOff                           = 0x80,
    kMFMIDIMessageTypeNoteOn                            = 0x90,
    kMFMIDIMessageTypePolyphonicAftertouch              = 0xA0,
    kMFMIDIMessageTypeControlChange                     = 0xB0,
    kMFMIDIMessageTypeProgramChange                     = 0xC0,
    kMFMIDIMessageTypeChannelAftertouch                 = 0xD0,
    kMFMIDIMessageTypePitchbend                         = 0xE0,
    kMFMIDIMessageTypeSysex                             = 0xF0
};


/////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////


@interface MFMIDIMessage : NSObject <NSCopying>


/////////////////////////////////////////////////////////////////////////
#pragma mark - Life Cycle
/////////////////////////////////////////////////////////////////////////

/** Init with the Message type anf Channel and then use the setters to assign values in the semantics of the message type */
+ (instancetype)messageWithType:(MFMIDIMessageType)type
                        channel:(UInt8)channel;

/**
 Create a Message with 3 raw bytes.

 @param status The first byte (status byte).
 @param data1  The second byte.
 @param data2  The third byte.
 */
+ (instancetype)messageWithBytes:(UInt8)status :(UInt8)data1 :(UInt8)data2;

/**
 Init with the given data. Can be longer than 3 bytes (ie sysex). Data is copied unless it is NSMutableData in which case it's retained
 */
+ (instancetype)messageWithData:(NSData *)data;

/**
  Creates a new message with the given packet.

 @param packet The packet whose data is to be wrapped in the message.

 @return A new message wrapper for the data.
 */
+ (instancetype)messageWithPacket:(MIDIPacket *)packet;

/**
 Parses data into zerp or more message objects, based on message
 lengths in the MIDI protocol.

 Example: (data)[0x90, 10, 127, 0x80, 10, 0] -> messages would
 result in 2 messages being made, one a note on, another a note off.

 @param data The data to parse.

 @return Zero or more objects in an array (never returns nil).
 */
+ (NSArray *)messagesWithData:(NSData *)data;
+ (NSArray *)messagesWithPacket:(MIDIPacket *)packet;
+ (NSArray *)messagesWithPacketList:(MIDIPacketList *)list;


/** YES if same class and the data bytes equal */
- (BOOL)isEqual:(id)object;

/** Copies the bytes too */
- (id)copyWithZone:(NSZone *)zone;




/////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
/////////////////////////////////////////////////////////////////////////

/** YES when the message is zero-length or zeroed out */
@property (nonatomic, readonly, getter = isEmpty) BOOL empty;

/** The length of the data of this message in bytes */
@property (nonatomic, readonly) NSUInteger length;

/** The MIDI Channel 0-15 */
@property (nonatomic) UInt8 channel;

/** NoteOn, Pitchbend, etc */
@property (nonatomic) MFMIDIMessageType type;

/// The full first byte. For most messages its the type (msb) + channel (lsb)
@property (nonatomic) UInt8 status;

/**
 These all get/set the second byte.
 They are named conveniently for parts of common message types.

 key:            note messages
 controller:     control change messages
 programNumber:  program change messages
 data1:          generic
 */
@property (nonatomic) UInt8 key, controller, data1;

/**
 These all get/set the third byte.
 They are named conveniently for parts of common message types.

 velocity:       note messages
 value:          control change messages
 pressures:      aftertouch messages
 data2:          generic
 */
@property (nonatomic) UInt8 velocity, value, programNumber, channelPressure, keyPressure, data2;

/** 
 Used for double (14bit) precision values like Pitchbend
 */
@property (nonatomic) UInt16 doublePrecisionValue, pitchbendValue;

/// The wrapped mutable data object. You can still mutate it even though its readonly
@property (nonatomic, readonly) NSMutableData *data;

/// The mutableBytes on the NSMutableData
@property (nonatomic, readonly) UInt8 *bytes;



/////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods
/////////////////////////////////////////////////////////////////////////

/**
 Sets a single byte at a given place in the message's data buffer.
 The message will grow if it needs to.

 @param byte  The value to apply.
 @param index The index at which to
 */
- (void)setByte:(UInt8)byte atIndex:(NSUInteger)index;




/////////////////////////////////////////////////////////////////////////
#pragma mark - Subscripting
/////////////////////////////////////////////////////////////////////////

/**
 Subscripting support.

 @param number A one-byte unsigned NSNumber.
 @param idx    The index to set this byte at in the data buffer.
 */
- (void)setObject:(NSNumber *)number atIndexedSubscript:(NSUInteger)idx;


@end
