//
//  HYRequest.m
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/4.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYRequest.h"
#import "HYNetworkConfig.h"
#import "HYNetworkPrivate.h"

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_QoS_Available 1140.11
#else
#define NSFoundationVersionNumber_With_QoS_Available NSFoundationVersionNumber_iOS_8_0
#endif

NSString *const HYRequestCacheErrorDomain = @"com.hycmcc.request.caching";

static dispatch_queue_t hyrequest_cache_writing_queue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr = DISPATCH_QUEUE_SERIAL;
        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_With_QoS_Available) {
            attr = dispatch_queue_attr_make_with_qos_class(attr, QOS_CLASS_BACKGROUND, 0);
        }
        queue = dispatch_queue_create("com.hycmcc.request.caching", attr);
    });
    return queue;
}

@interface HYCacheMetadata : NSObject<NSSecureCoding>

@property (nonatomic, assign) long long version;
@property (nonatomic, strong) NSString *sensitiveDataString;
@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSString *appVersionString;

@end

@implementation HYCacheMetadata

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.version) forKey:NSStringFromSelector(@selector(version))];
    [aCoder encodeObject:self.sensitiveDataString forKey:NSStringFromSelector(@selector(sensitiveDataString))];
    [aCoder encodeObject:@(self.stringEncoding) forKey:NSStringFromSelector(@selector(stringEncoding))];
    [aCoder encodeObject:self.creationDate forKey:NSStringFromSelector(@selector(creationDate))];
    [aCoder encodeObject:self.appVersionString forKey:NSStringFromSelector(@selector(appVersionString))];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (!self)
    {
        return nil;
    }
    
    self.version = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(version))] integerValue];
    self.sensitiveDataString = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(sensitiveDataString))];
    self.stringEncoding = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(stringEncoding))] integerValue];
    self.creationDate = [aDecoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(creationDate))];
    self.appVersionString = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(appVersionString))];
    
    return self;
}

@end

@interface HYRequest()

@property (nonatomic, strong) NSData *cacheData;
@property (nonatomic, strong) NSString *cacheString;
@property (nonatomic, strong) id cacheJSON;
@property (nonatomic, strong) NSXMLParser *cacheXML;

@property (nonatomic, strong) HYCacheMetadata *cacheMetadata;
@property (nonatomic, assign) BOOL dataFromCache;

@end

@implementation HYRequest

- (void)start
{
    if (self.ignoreCache)
    {
        [self startWithoutCache];
        return;
    }
    
    //The exist file at the path will be removed before the request starts
    if (self.resumableDownloadPath)
    {
        [self startWithoutCache];
        return;
    }
    
    if (![self loadCacheWithError:nil])
    {
        [self startWithoutCache];
        return;
    }
    
    _dataFromCache = YES;
    
    //从缓存获取数据
    dispatch_async(dispatch_get_main_queue(), ^{
        [self requestCompletePreprocessor];
        [self requestCompleteFilter];
        HYRequest *strongSelf = self;
        [strongSelf.delegate requestFinished:strongSelf];
        if (strongSelf.successCompletionBlock)
        {
            strongSelf.successCompletionBlock(strongSelf);
        }
        [strongSelf clearCompletionBlock];
    });
}

- (void)startWithoutCache
{
    [self clearCacheVariables];
    [super start];
}

#pragma mark - Network Request Delegate
- (void)requestCompletePreprocessor
{
    [super requestCompletePreprocessor];
    
    if (self.writeCacheAsynchronously)
    {
        dispatch_async(hyrequest_cache_writing_queue(), ^{
            [self saveResponseDataToCacheFile:[super responseData]];
        });
    }
    else
    {
        [self saveResponseDataToCacheFile:[super responseData]];
    }
    
    if (self.reformer && ![self.responseJSONObject isKindOfClass:[NSURL class]])
    {
        if ([self.reformer respondsToSelector:@selector(request:reformData:)])
        {
            self.reformData = [self.reformer request:self reformData:(NSDictionary *)[super responseData]];
        }
    }
}

- (void)saveResponseDataToCacheFile:(NSData *)data
{
    if([self cacheTimeInSeconds] > 0 && ![self isDataFromCache])
    {
        if (data != nil)
        {
            @try {
                // New data will always overwrite old data.
                [data writeToFile:[self cacheFilePath] atomically:YES];
                
                HYCacheMetadata *metadata = [[HYCacheMetadata alloc] init];
                metadata.version = [self cacheVersion];
                metadata.sensitiveDataString = ((NSObject *)[self cacheSensitiveData]).description;
                metadata.stringEncoding = [HYNetworkUtils stringEncodingWithRequest:self];
                metadata.creationDate = [NSDate date];
                metadata.appVersionString = [HYNetworkUtils appVersionString];
                [NSKeyedArchiver archiveRootObject:metadata toFile:[self cacheMetadataFilePath]];
            } @catch (NSException *exception) {
                NSLog(@"Save cache failed, reason = %@", exception.reason);
            }
        }
    }
}

- (void)clearCacheVariables
{
    _cacheData = nil;
    _cacheXML = nil;
    _cacheJSON = nil;
    _cacheString = nil;
    _cacheMetadata = nil;
    _dataFromCache = NO;
}

- (BOOL)loadCacheWithError:(NSError *_Nullable __autoreleasing *)error
{
    if ([self cacheTimeInSeconds] < 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorInvalidCacheTime userInfo:@{ NSLocalizedDescriptionKey:@"Invalid cache time"}];
        }
        return NO;
    }
    
    // Try load metadata.
    if (![self loadCacheMetadata])
    {
        if (error)
        {
            *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorInvalidMetadata userInfo:@{ NSLocalizedDescriptionKey:@"Invalid metadata. Cache may not exist"}];
        }
        return NO;
    }
    
    // Check if cache is still valid.
    if (![self validateCacheWithError:error])
    {
        return NO;
    }
    
    return YES;
}


- (BOOL)validateCacheWithError:(NSError *_Nullable __autoreleasing *)error
{
    //Date
    NSDate *creationDate = self.cacheMetadata.creationDate;
    NSTimeInterval duration = -[creationDate timeIntervalSinceNow];
    if (duration < 0 || duration > [self cacheTimeInSeconds])
    {
        if (error) {
            *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorExpired userInfo:@{ NSLocalizedDescriptionKey:@"Cache expired"}];
        }
        return NO;
    }
    
    // Version
    long long cacheVersionFileContent = self.cacheMetadata.version;
    if (cacheVersionFileContent != [self cacheVersion]) {
        if (error) {
            *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"Cache version mismatch"}];
        }
        return NO;
    }
    
    // Sensitive data
    NSString *sensitiveDataString = self.cacheMetadata.sensitiveDataString;
    NSString *currentSensitiveDataString = ((NSObject *)[self cacheSensitiveData]).description;
    if (sensitiveDataString || currentSensitiveDataString)
    {
        if (sensitiveDataString.length != currentSensitiveDataString.length || [sensitiveDataString isEqualToString:currentSensitiveDataString])
        {
            if (error)
            {
                *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorSensitiveDataMismatch userInfo:@{ NSLocalizedDescriptionKey:@"Cache sensitive data mismatch"}];
            }
            return NO;
        }
    }
    
    //App version
    NSString *appVersionString = self.cacheMetadata.appVersionString;
    NSString *currentAppVersionString = @"";
    if (appVersionString || currentAppVersionString)
    {
        if (appVersionString.length != currentAppVersionString.length || ![appVersionString isEqualToString:currentAppVersionString])
        {
            if (error)
            {
                *error = [NSError errorWithDomain:HYRequestCacheErrorDomain code:HYRequestCacheErrorAppVersionMismatch userInfo:@{ NSLocalizedDescriptionKey:@"App version mismatch"}];
            }
            return NO;
        }
    }
    return YES;
    
}

- (BOOL)loadCacheMetadata
{
    NSString *path = [self cacheMetadataFilePath];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:nil])
    {
        @try {
            _cacheMetadata = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            return YES;
        } @catch (NSException *exception) {
            NSLog(@"Load cache metadata failed, reason = %@", exception.reason);
            return NO;
        }
    }
    return NO;
}

#pragma mark - Subclass Override

- (NSInteger)cacheTimeInSeconds
{
    return -1;
}

- (long long)cacheVersion
{
    return 0;
}

- (id)cacheSensitiveData
{
    return nil;
}

- (BOOL)writeCacheAsynchronously {
    return YES;
}

#pragma mark -

- (BOOL)isDataFromCache
{
    return _dataFromCache;
}

- (NSData *)responseData
{
    if (_cacheData)
    {
        return _cacheData;
    }
    return [super responseData];
}

- (NSString *)responseString
{
    if (_cacheString)
    {
        return _cacheString;
    }
    return [super responseString];
}

- (id)responseJSONObject
{
    if (_cacheJSON)
    {
        return _cacheJSON;
    }
    return [super responseJSONObject];
}

- (id)responseObject {
    if (_cacheJSON) {
        return _cacheJSON;
    }
    if (_cacheXML) {
        return _cacheXML;
    }
    if (_cacheData) {
        return _cacheData;
    }
    return [super responseObject];
}


- (void)createDirectoryIfNeeded:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir])
    {
        [self createBaseDirectoryAtPath:path];
    }
    else
    {
        if (!isDir)
        {
            NSError *error = nil;
            [fileManager removeItemAtPath:path error:&error];
            [self createBaseDirectoryAtPath:path];
        }
    }
}

- (void)createBaseDirectoryAtPath:(NSString *)path
{
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES
                                               attributes:nil error:&error];
    if (error)
    {
        NSLog(@"create cache directory failed, error = %@", error);
    }
    else
    {
        [HYNetworkUtils addDoNotBackupAttribute:path];
    }
}

- (NSString *)cacheBasePath
{
    NSString *pathOfLibrary = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path = [pathOfLibrary stringByAppendingPathComponent:@"LazyRequestCache"];
    
    // Filter cache base path
    NSArray<id<HYCacheDirPathFilterProtocol>> *filters = [[HYNetworkConfig sharedConfig] cacheDirPathFilters];
    if (filters.count > 0)
    {
        for (id<HYCacheDirPathFilterProtocol> f in filters)
        {
            path = [f filterCacheDirPath:path withRequest:self];
        }
    }
    
    [self createDirectoryIfNeeded:path];
    return path;
}

- (NSString *)cacheFileName
{
    NSString *requestUrl = [self requestUrl];
//    NSString *baseUrl = [HYNetworkConfig sharedConfig].baseUrl;
    //防止子类重写的baseUrl方法返回值变化时，缓存未失效。场景：测试环境和生产环境切换
    NSString *baseUrl = ([self baseUrl].length > 0) ? [self baseUrl] : [HYNetworkConfig sharedConfig].baseUrl;
    id argument = [self cacheFileNameFilterForRequestArgument:[self requestArgument]];
    NSString *requestInfo = [NSString stringWithFormat:@"Method:%ld Host:%@ Url:%@ Argument:%@",
                             (long)[self requestMethod], baseUrl, requestUrl, argument];
    NSString *cacheFileName = [HYNetworkUtils md5StringFromString:requestInfo];
    return cacheFileName;
}

- (NSString *)cacheFilePath
{
    NSString *cacheFileName = [self cacheFileName];
    NSString *path = [self cacheBasePath];
    path = [path stringByAppendingPathComponent:cacheFileName];
    return path;
}

- (NSString *)cacheMetadataFilePath
{
    NSString *cacheMetadataFileName = [NSString stringWithFormat:@"%@.metadata", [self cacheFileName]];
    NSString *path = [self cacheBasePath];
    path = [path stringByAppendingPathComponent:cacheMetadataFileName];
    return path;
}


@end
