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

- (UIImage *)imageWithURL:(NSURL *)imageURL operationQueue:(NSOperationQueue *)queue completionBlock:(void (^)(UIImage *image, NSError *error))completionBlock;

@end
