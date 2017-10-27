//
//  HYRequest.h
//  HYNetworkDemo
//
//  Created by zheng on 2017/8/4.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import "HYBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HYRequestCacheErrorDomain;

NS_ENUM(NSInteger) {
    HYRequestCacheErrorExpired = -1,
    HYRequestCacheErrorVersionMismatch = -2,
    HYRequestCacheErrorSensitiveDataMismatch = -3,
    HYRequestCacheErrorAppVersionMismatch = -4,
    HYRequestCacheErrorInvalidCacheTime = -5,
    HYRequestCacheErrorInvalidMetadata = -6,
    HYRequestCacheErrorInvalidCacheData = -7,
};


@interface HYRequest : HYBaseRequest

@property (nonatomic) BOOL ignoreCache;

- (BOOL)isDataFromCache;


///  Manually load cache from storage.
///
///  @param error If an error occurred causing cache loading failed, an error object will be passed, otherwise NULL.
///
///  @return Whether cache is successfully loaded.
- (BOOL)loadCacheWithError:(NSError * __autoreleasing *)error;

- (void)startWithoutCache;

///  Save response data (probably from another request) to this request's cache location
- (void)saveResponseDataToCacheFile:(NSData *)data;

#pragma mark - Subclass Override

///  The max time duration that cache can stay in disk until it's considered expired.
///  Default is -1, which means response is not actually saved as cache.
- (NSInteger)cacheTimeInSeconds;

///  Version can be used to identify and invalidate local cache. Default is 0.
- (long long)cacheVersion;

///  This can be used as additional identifier that tells the cache needs updating.
///
///  @discussion The `description` string of this object will be used as an identifier to verify whether cache
///              is invalid. Using `NSArray` or `NSDictionary` as return value type is recommended. However,
///              If you intend to use your custom class type, make sure that `description` is correctly implemented.
- (nullable id)cacheSensitiveData;

///  Whether cache is asynchronously written to storage. Default is YES.
- (BOOL)writeCacheAsynchronously;

@end

NS_ASSUME_NONNULL_END
