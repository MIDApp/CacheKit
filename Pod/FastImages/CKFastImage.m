//
//  CKFastImage.m
//  FastImageCacheDemo
//
//  Created by David Beck on 7/24/15.
//  Copyright (c) 2015 Path. All rights reserved.
//

#import "CKFastImage.h"



static void CKFastImageRelease(void *info, const void *data, size_t size) {
	if (info) {
		CFRelease(info);
	}
}


@implementation CKFastImage

@synthesize image = _image;

- (CGSize)pixelSize {
	return CGSizeMake(_size.width * _scale, _size.height * _scale);
}

- (CGBitmapInfo)bitmapInfo {
	CGBitmapInfo info;
	switch (_style) {
		case CKFastImageStyle32BitBGRA:
			info = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
			break;
		case CKFastImageStyle32BitBGR:
			info = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
			break;
		case CKFastImageStyle16BitBGR:
			info = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder16Host;
			break;
		case CKFastImageStyle8BitGrayscale:
			info = (CGBitmapInfo)kCGImageAlphaNone;
			break;
	}
	return info;
}

- (NSInteger)bytesPerPixel {
	NSInteger bytesPerPixel;
	switch (_style) {
		case CKFastImageStyle32BitBGRA:
		case CKFastImageStyle32BitBGR:
			bytesPerPixel = 4;
			break;
		case CKFastImageStyle16BitBGR:
			bytesPerPixel = 2;
			break;
		case CKFastImageStyle8BitGrayscale:
			bytesPerPixel = 1;
			break;
	}
	return bytesPerPixel;
}

- (NSInteger)bitsPerComponent {
	NSInteger bitsPerComponent;
	switch (_style) {
		case CKFastImageStyle32BitBGRA:
		case CKFastImageStyle32BitBGR:
		case CKFastImageStyle8BitGrayscale:
			bitsPerComponent = 8;
			break;
		case CKFastImageStyle16BitBGR:
			bitsPerComponent = 5;
			break;
	}
	return bitsPerComponent;
}

- (BOOL)isGrayscale {
	BOOL isGrayscale;
	switch (_style) {
		case CKFastImageStyle32BitBGRA:
		case CKFastImageStyle32BitBGR:
		case CKFastImageStyle16BitBGR:
			isGrayscale = NO;
			break;
		case CKFastImageStyle8BitGrayscale:
			isGrayscale = YES;
			break;
	}
	return isGrayscale;
}

- (NSInteger)imageRowLength {
	NSInteger alignment = 64; // magic number the cpu/gpu likes
	NSInteger bytesPerRow = [self pixelSize].width * [self bytesPerPixel];
	return ((bytesPerRow + (alignment - 1)) / alignment) * alignment;
}

- (UIImage *)image {
	if (_image == nil) {
		_image = [self _decodeImage];
	}
	
	return _image;
}


#pragma mark - Initialization

- (void)dealloc
{
	free((void *)_bytes);
}

- (instancetype)init
{
	return [self initWithBytesNoCopy:NULL length:0 size:CGSizeZero scale:1.0 style:CKFastImageStyle32BitBGRA];
}

- (instancetype)initWithImage:(UIImage *)image
{
	BOOL hasAlpha = CGImageGetAlphaInfo(image.CGImage) != kCGImageAlphaNone;
	CKFastImageStyle style = hasAlpha ? CKFastImageStyle32BitBGRA : CKFastImageStyle32BitBGR;
	
	return [self initWithSize:image.size scale:image.scale style:style drawing:^(CGContextRef context) {
		[image drawAtPoint:CGPointZero];
	}];
}

- (instancetype)initWithSize:(CGSize)size scale:(CGFloat)scale style:(CKFastImageStyle)style drawing:(void(^)(CGContextRef context))drawing {
	_size = size;
	_scale = scale;
	_style = style;
	
	
	CGBitmapInfo bitmapInfo = [self bitmapInfo];
	CGColorSpaceRef colorSpace = [self isGrayscale] ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
	NSInteger bitsPerComponent = [self bitsPerComponent];
	NSInteger imageRowLength = [self imageRowLength];
	
	
	NSUInteger length = imageRowLength * [self pixelSize].height;
	void *bytes = malloc(length);
	
	
	CGContextRef context = CGBitmapContextCreate(bytes, [self pixelSize].width, [self pixelSize].height, bitsPerComponent, imageRowLength, colorSpace, bitmapInfo);
	
	CGContextTranslateCTM(context, 0, [self pixelSize].height);
	CGContextScaleCTM(context, _scale, -_scale);
	
	// Call drawing block to allow client to draw into the context
	UIGraphicsPushContext(context);
	drawing(context);
	UIGraphicsPopContext();
	
	CGImageRef imageRef = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	
	
	self = [self initWithBytesNoCopy:bytes length:length size:size scale:scale style:style];
	if (self != nil) {
		_image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
	}
	
	CGImageRelease(imageRef);
	
	return self;
}

- (instancetype)initWithBytesNoCopy:(const void *)data length:(NSUInteger)length size:(CGSize)size scale:(CGFloat)scale style:(CKFastImageStyle)style
{
	self = [super init];
	if (self) {
		_size = size;
		_scale = scale;
		_style = style;
		_bytes = data;
		_length = length;
	}
	return self;
}


#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self) {
		const void *bytes = [coder decodeBytesForKey:@"bytes" returnedLength:&_length];
		_bytes = malloc(_length);
		memcpy((void *)_bytes, bytes, _length);
		
		_scale = [coder decodeDoubleForKey:@"scale"];
		_size = CGSizeMake([coder decodeDoubleForKey:@"size.x"], [coder decodeDoubleForKey:@"size.y"]);
		_style = [coder decodeInt32ForKey:@"style"];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeBytes:_bytes length:_length forKey:@"bytes"];
	
	[coder encodeDouble:_scale forKey:@"scale"];
	[coder encodeDouble:_size.width forKey:@"size.x"];
	[coder encodeDouble:_size.height forKey:@"size.y"];
	[coder encodeInt32:_style forKey:@"style"];
}

- (UIImage *)_decodeImage {
	if (_length == 0) {
		return nil;
	}
	
	UIImage *image = nil;
	
	
	CGDataProviderRef dataProvider = CGDataProviderCreateWithData((void *)CFBridgingRetain(self), _bytes, _length, CKFastImageRelease);
	
	CGBitmapInfo bitmapInfo = [self bitmapInfo];
	CGColorSpaceRef colorSpace = [self isGrayscale] ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
	NSInteger bitsPerComponent = [self bitsPerComponent];
	NSInteger imageRowLength = [self imageRowLength];
	NSInteger bytesPerPixel = [self bytesPerPixel];
	NSInteger bitsPerPixel = bytesPerPixel * 8;
	
	CGImageRef imageRef = CGImageCreate([self pixelSize].width, [self pixelSize].height, bitsPerComponent, bitsPerPixel, imageRowLength, colorSpace, bitmapInfo, dataProvider, NULL, false, (CGColorRenderingIntent)0);
	CGDataProviderRelease(dataProvider);
	CGColorSpaceRelease(colorSpace);
	
	if (imageRef != NULL) {
		image = [[UIImage alloc] initWithCGImage:imageRef scale:_scale orientation:UIImageOrientationUp];
		CGImageRelease(imageRef);
	} else {
		NSLog(@"-[CKFastImage decodeImage] failed to decode image.");
	}
	
	return image;
}

@end
