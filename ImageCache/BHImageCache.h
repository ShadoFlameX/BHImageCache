//
//  BHImageCache.h
//  ImageCache
//
//  Created by Bryan Hansen on 1/19/13.
//  Copyright (c) 2013 skeuo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BHImageCache : NSObject

+ (BHImageCache *)sharedCache;

- (UIImage *)imageWithURL:(NSURL *)imageURL scale:(CGFloat)scale operationQueue:(NSOperationQueue *)queue completionBlock:(void (^)(UIImage *image, NSError *error))completionBlock;
- (UIImage *)cachedImageWithURL:(NSURL *)imageURL scale:(CGFloat)scale;

- (BOOL)clearCache;

@end
