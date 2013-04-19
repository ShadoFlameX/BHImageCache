//
//  BHImageCache.m
//  ImageCache
//
//  Created by Bryan Hansen on 1/19/13.
//  Copyright (c) 2013 skeuo. All rights reserved.
//

#import "BHImageCache.h"

static NSString * const ImageCacheFolder = @"BHImageCache";
static NSString * const ImageCacheInfoFilename = @"bhcacheInfo.plist";

static NSString * const ImageCacheItemFilenameKey = @"filename";
static NSString * const ImageCacheItemExpiresKey = @"expires";

@interface BHImageCache () {
    dispatch_queue_t cacheQueue;
}

@property (nonatomic, strong) NSDateFormatter *expiresDateFormatter;
@property NSMutableDictionary *imageCacheInfo;

- (NSURL *)cacheImagesFolderURL;

@end

@implementation BHImageCache

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
        [self setup];
    }
    
    return self;
}


#pragma mark - Download

- (UIImage *)imageWithURL:(NSURL *)imageURL scale:(CGFloat)scale operationQueue:(NSOperationQueue *)queue completionBlock:(void (^)(UIImage *image, NSError *error))completionBlock
{
    NSAssert(queue, @"Invalid operation queue queue");

    if (!imageURL) {
        NSError *urlError = [NSError errorWithDomain:@"com.skeuo.BHImageCache" code:-1000 userInfo:nil];
        NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
            completionBlock(nil, urlError);
        }];
        [queue addOperation:blockOperation];
        return nil;
    }

    NSString *URLString = [imageURL absoluteString];
    NSString *pathString = URLString;

    __block NSString *cachedFilename = nil;
    BOOL shouldReload;
    UIImage *cachedImage = [self cachedImageWithURL:imageURL scale:scale cachedFilename:&cachedFilename shouldReload:&shouldReload];
        
    if (shouldReload) {
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
            
            UIImage *image = [UIImage imageWithData:data scale:scale];
            
            if (!image) {
                NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                NSError *dataError = [NSError errorWithDomain:@"BHImageCache" code:2 userInfo:@{NSLocalizedDescriptionKey : @"Could not convert data into image."}];
                    completionBlock(nil, dataError);
                }];
                [queue addOperation:blockOperation];
                return;
            }
            
            if (!cachedFilename.length) {
                NSString *fileType = [[pathString pathExtension] lowercaseString];
                cachedFilename = [[[BHImageCache class] UUID] stringByAppendingPathExtension:fileType];
            }
            
            NSURL *fileURL = [[self cacheImagesFolderURL] URLByAppendingPathComponent:cachedFilename];
            BOOL success = [data writeToURL:fileURL atomically:NO];
            NSAssert(success, @"Failed to write image data.");
            
            if (success) {
                NSMutableDictionary *cacheItem = [NSMutableDictionary dictionaryWithCapacity:2];
                NSString *expiration = ((NSHTTPURLResponse *)response).allHeaderFields[@"Expires"];
                if (expiration.length) {
                    NSDate *expirationDate = [self.expiresDateFormatter dateFromString:expiration];
                    if (expirationDate) {
                        cacheItem[ImageCacheItemExpiresKey] = expirationDate;
                    }
                }
                
                cacheItem[ImageCacheItemFilenameKey] = cachedFilename;

                dispatch_sync(cacheQueue, ^(){
                    self.imageCacheInfo[URLString] = cacheItem;
                    BOOL success = [self.imageCacheInfo writeToURL:[self cacheInfoFileURL] atomically:YES];
                    if (!success) NSLog(@"BHImageCache: Failed to write cache info file");
                });
            }
            
            NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
                completionBlock(image, nil);
            }];
            [queue addOperation:blockOperation];
        }];
    }
    
    return cachedImage;
}


#pragma mark - Image Cache

- (UIImage *)cachedImageWithURL:(NSURL *)imageURL scale:(CGFloat)scale
{
    BOOL shouldReload;
    return [self cachedImageWithURL:imageURL scale:scale cachedFilename:nil shouldReload:&shouldReload];
}

- (UIImage *)cachedImageWithURL:(NSURL *)imageURL scale:(CGFloat)scale cachedFilename:(NSString **)filename shouldReload:(BOOL *)shouldReload
{
    NSString *URLString = [imageURL absoluteString];

    UIImage *cachedImage = nil;
    __block NSString *cachedFilename = nil;

    *shouldReload = YES;

    __block NSDictionary *itemInfo = nil;
    dispatch_sync(cacheQueue, ^(){
        itemInfo = self.imageCacheInfo[URLString];
    });

    if (itemInfo) {
        NSDate *expirationDate = (NSDate *)itemInfo[ImageCacheItemExpiresKey];
        if (expirationDate) {
            NSTimeInterval interval = [expirationDate timeIntervalSinceNow];
            if (interval < 0) {
                // do not use the cache if the image has expired
                return nil;
                
            } else if (interval < 60 * 60 * 24 * 365) {
                // Only use the cache if the expiration date is reasonable
                *shouldReload = NO;
            }
        }

        cachedFilename = itemInfo[ImageCacheItemFilenameKey];
        NSURL *url = [self.cacheImagesFolderURL URLByAppendingPathComponent:cachedFilename];
        NSData *cachedImageData = [NSData dataWithContentsOfURL:url];
        cachedImage = [UIImage imageWithData:cachedImageData scale:scale];
    }

    return cachedImage;
}

- (BOOL)clearCache
{
    BOOL success = YES;
    if ([[self cacheImagesFolderURL] checkResourceIsReachableAndReturnError:nil]) {
        NSError *error = nil;
        success = [[NSFileManager defaultManager] removeItemAtURL:[self cacheImagesFolderURL] error:&error];
        NSAssert(success, @"Could Not Remove Cache: %@",error);
    }
    
    [self setup];
    
    return success;
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

- (void)setup
{
    cacheQueue = dispatch_queue_create("com.skeuo.BHImageCache ", NULL);

    self.expiresDateFormatter = [[NSDateFormatter alloc] init];
    self.expiresDateFormatter.dateFormat = @"EEE', 'dd' 'MMM' 'yyyy' 'HH':'mm':'ss' 'zzz";

    self.imageCacheInfo = [NSMutableDictionary dictionaryWithContentsOfURL:[self cacheInfoFileURL]];
    if (!self.imageCacheInfo) self.imageCacheInfo = [NSMutableDictionary dictionary];
    
    NSURL *folderURL = [self cacheImagesFolderURL];
    BOOL result = [folderURL checkResourceIsReachableAndReturnError:nil];
    if (!result) {
        NSError *dirError = nil;
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:NO attributes:nil error:&dirError];
        if (!success) NSLog(@"BHImageCache: Could not create cache folder %@",dirError);
    }
}

+ (NSString *)UUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *string = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return string;
}

@end
