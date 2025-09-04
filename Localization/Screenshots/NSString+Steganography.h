//
// --------------------------------------------------------------------------
// NSString+Steganography.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "DisableSwiftBridging.h"
#import "MFDataClass.h"

MFDataClassInterface2(MFDataClassBase, FoundSecretMessage,
    readwrite, strong, nonnull, NSString *, secretMessage,
    readwrite, assign,        , NSRange,    rangeInString
)

NS_ASSUME_NONNULL_BEGIN /// [Sep 2025] I haven't checked if these are actually  all nonnull but it kinda looks like it? This code is only used for buildscripts anyways, so it shouldn't matter.

@interface NSAttributedString (MFSteganography)

/// Interface

- (MF_SWIFT_UNBRIDGED(NSAttributedString *))attributedStringByAppendingStringAsSecretMessage:(MF_SWIFT_UNBRIDGED(NSString *))message NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSArray<FoundSecretMessage *> *))secretMessages NS_REFINED_FOR_SWIFT;

@end

@interface NSString (MFSteganography)

/// Interface

- (MF_SWIFT_UNBRIDGED(NSString *))stringByAppendingStringAsSecretMessage:(MF_SWIFT_UNBRIDGED(NSString *))message NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))encodedAsSecretMessage NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSArray<FoundSecretMessage *> *))secretMessages NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))withoutSecretMessages NS_REFINED_FOR_SWIFT;

/// Internal

- (NSString *)decodedAsSecretMessage;

+ (NSString *)stringWithBinaryArray:(NSArray<NSArray<NSNumber *> *> *)characters;
- (NSArray<NSArray<NSNumber *> *> *)binaryArray;

+ (NSString *)stringWithUTF32Characters:(NSArray<NSNumber *> *)characters;
- (NSArray<NSNumber *> *)UTF32Characters;
- (NSString *)UTF32CharacterDescription;

@end

NS_ASSUME_NONNULL_END
