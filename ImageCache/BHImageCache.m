//
//  BHImageCache.m
//  ImageCache
//
//  Created by Bryan Hansen on 1/19/13.
//  Copyright (c) 2013 skeuo. All rights reserved.
//

#import "BHImageCache.h"

static NSString * const ImageCacheFolder = @"ImageCache";
static NSString * const ImageCacheInfoFilename = @"cacheInfo.plist";
static NSArray *SupportedFileTypes = nil;

@interface BHImageCache () {
    dispatch_queue_t fileWriteQueue;
}

@property NSMutableDictionary *imageCacheInfo;

- (NSURL *)cacheImagesFolderURL;

@end

@implementation BHImageCache

+ (void)initialize
{
    SupportedFileTypes = @[@"jpg", @"png"];
}

+ (BHImageCache *)sharedCache
{
    static BHImageCache *_sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedCache = [[self alloc] init];
    });
    
    return _sharedCache;
}


#pragma mark - Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        fileWriteQueue = dispatch_queue_create("com.skeuo.imagecache.filewritequeue", NULL);

        self.imageCacheInfo = [NSMutableDictionary dictionaryWithContentsOfURL:[self cacheInfoFileURL]];
        if (!self.imageCacheInfo) self.imageCacheInfo = [NSMutableDictionary dictionary];
                
        NSURL *folderURL = [self cacheImagesFolderURL];
        NSError *error = nil;
        [folderURL checkResourceIsReachableAndReturnError:&error];
        if (error) {
            NSError *dirError = nil;
            BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:NO attributes:nil error:&dirError];
            NSAssert(success, @"Could not create cache fodler",dirError);
        }
        
        NSLog(@"Cache folder: %@",folderURL);
    }
    
    return self;
}


#pragma mark - Download

- (UIImage *)imageWithURL:(NSURL *)imageURL operationQueue:(NSOperationQueue *)queue completionBlock:(void (^)(UIImage *image, NSError *error))completionBlock
{
    NSString *URLString = [imageURL absoluteString];
    
    NSString *fileType = [[URLString pathExtension] lowercaseString];
    if (![SupportedFileTypes containsObject:fileType]) {
        NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
            NSError *error = [NSError errorWithDomain:@"BHImageCache" code:1 userInfo:@{NSLocalizedDescriptionKey : @"Invalid image file type."}];
            completionBlock(nil, error);
        }];
        [queue addOperation:blockOperation];
        return nil;
    }
    
    UIImage *cachedImage = nil;
    __block NSString *cachedFilename = nil;
    
    if (self.imageCacheInfo[URLString]) {
        NSURL *url = [self.cacheImagesFolderURL URLByAppendingPathComponent:self.imageCacheInfo[URLString]];
        NSData *cachedImageData = [NSData dataWithContentsOfURL:url];
        cachedImage = [UIImage imageWithData:cachedImageData];
        cachedFilename = self.imageCacheInfo[URLString];
    }
    
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:imageURL];
                
        NSOperationQueue *downloadQueue = [[NSOperationQueue alloc] init];
        
        [NSURLConnection sendAsynchronousRequest:request queue:downloadQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            if (error) {
                NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                    completionBlock(nil, error);
                }];
                [queue addOperation:blockOperation];
                return;
            }
                        
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
                if (statusCode >= 400) {
                    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                    NSError *serverError = [NSError errorWithDomain:@"BHImageCache" code:statusCode userInfo:@{NSLocalizedDescriptionKey : @"Server Error"}];
                        completionBlock(nil, serverError);
                    }];
                    [queue addOperation:blockOperation];
                    return;
                }
            }
            
            UIImage *image = [UIImage imageWithData:data];
            
            if (!image) {
                NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                NSError *dataError = [NSError errorWithDomain:@"BHImageCache" code:2 userInfo:@{NSLocalizedDescriptionKey : @"Could not convert data into image."}];
                    completionBlock(nil, dataError);
                }];
                [queue addOperation:blockOperation];
                return;
            }
            
            if (!cachedFilename.length) {
                cachedFilename = [[[BHImageCache class] UUID] stringByAppendingPathExtension:fileType];
            }
            
            dispatch_async(fileWriteQueue, ^{
                NSURL *fileURL = [[self cacheImagesFolderURL] URLByAppendingPathComponent:cachedFilename];
                BOOL success = [data writeToURL:fileURL atomically:NO];
                NSAssert(success, @"Failed to write image data.");
                
                if (success) {
                    self.imageCacheInfo[URLString] = cachedFilename;
                    BOOL success = [self.imageCacheInfo writeToURL:[self cacheInfoFileURL] atomically:NO];
                    NSAssert(success, @"Failed to write cache info file");
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                        completionBlock(image, nil);
                    }];
                    [queue addOperation:blockOperation];
                });
            });
        }];
    }
    
    return cachedImage;
}


#pragma mark - Private

- (NSURL *)cacheInfoFileURL
{    
    NSURL *fileURL = [[self cacheImagesFolderURL] URLByAppendingPathComponent:ImageCacheInfoFilename];
    return fileURL;
}

- (NSURL *)cacheImagesFolderURL
{
    NSArray *URLs = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    
    NSAssert(URLs.count, @"No cache URLs available");
    
    NSURL *folderURL = [URLs[0] URLByAppendingPathComponent:ImageCacheFolder];
    
    return folderURL;
}

+ (NSString *)UUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

@end
