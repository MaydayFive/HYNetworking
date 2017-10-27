//
//  HYNetworkPrivate.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/9.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HYRequest.h"
#import "HYBaseRequest.h"
#import "HYNetworkConfig.h"

NS_ASSUME_NONNULL_BEGIN

@class AFHTTPSessionManager;

@interface HYNetworkUtils : NSObject

+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator;

+ (NSString *)md5StringFromString:(NSString *)string;

+ (NSString *)appVersionString;

//path不要设置备份
+ (void)addDoNotBackupAttribute:(NSString *)path;

//返回request加密方式
+ (NSStringEncoding)stringEncodingWithRequest:(HYBaseRequest *)request;

//是否是针对可恢复的数据
+ (BOOL)validateResumeData:(NSData *)data;

@end

@interface HYRequest (Getter)

- (NSString *)cacheBasePath;

@end

@interface HYBaseRequest (Setter)
//给子类用的，父类是
@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) NSData *responseData;
@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) NSString *responseString;
@property (nonatomic, strong, readwrite, nullable) NSError *error;

@property (nonatomic, strong, readwrite, nullable) id reformData;

@end

@interface HYNetworkPrivate : NSObject



@end

NS_ASSUME_NONNULL_END
