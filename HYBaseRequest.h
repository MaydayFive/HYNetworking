//
//  HYBaseRequest.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/2.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HYRequestValidationErrorDomain;

NS_ENUM(NSInteger)
{
    HYRequestValidationErrorInvalidStatusCode = -8,
    HYRequestValidationErrorInvalidJSONFormat = -9,
};

///  HTTP Request method.
typedef NS_ENUM(NSInteger, HYRequestMethod) {
    HYRequestMethodGET = 0,
    HYRequestMethodPOST,
    HYRequestMethodHEAD,
    HYRequestMethodPUT,
    HYRequestMethodDELETE,
    HYRequestMethodPATCH,
};

///  Request serializer type.
typedef NS_ENUM(NSInteger, HYRequestSerializerType) {
    HYRequestSerializerTypeHTTP = 0,
    HYRequestSerializerTypeJSON,
};

typedef NS_ENUM(NSInteger, HYResponseSerializerType) {
    /// NSData type
    HYResponseSerializerTypeHTTP,
    /// JSON object type
    HYResponseSerializerTypeJSON,
    /// NSXMLParser type
    HYResponseSerializerTypeXMLParser,
};

///  Request priority
typedef NS_ENUM(NSInteger, HYRequestPriority) {
    HYRequestPriorityLow = -4L,
    HYRequestPriorityDefault = 0,
    HYRequestPriorityHigh = 4,
};

@protocol AFMultipartFormData;

typedef void (^AFConstructingBlock)(id<AFMultipartFormData> formData);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress *);
//重定向
typedef NSURLRequest * _Nullable (^AFURLSessionTaskWillPerformHTTPRedirectionBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request);
    
@class HYBaseRequest;

typedef void(^HYRequestCompletionBlock)(__kindof HYBaseRequest *request);

//这是给例如chainRequest 使用的，request 完成后回调至例如chainRequest
@protocol HYRequestDelegate <NSObject>

@optional

- (void)requestFinished:(__kindof HYBaseRequest *)request;

- (void)requestFailed:(__kindof HYBaseRequest *)request;

@end

@protocol HYRequestAccessory <NSObject>

@optional

- (void)requestWillStart:(id)request;

- (void)requestWillStop:(id)request;

- (void)requestDidStop:(id)request;

@end

@protocol HYRequestDataReformer <NSObject>
@required
/*
 比如同样的一个获取电话号码的逻辑，二手房，新房，租房调用的API不同，所以它们的manager和data都会不同。
 即便如此，同一类业务逻辑（都是获取电话号码）还是应该写到一个reformer里面去的。这样后人定位业务逻辑相关代码的时候就非常方便了。
 
 代码样例：
- (id)request:(__kindof HYBaseRequest *)manager reformData:(NSDictionary *)data;
 {
 if ([request isKindOfClass:[xinfangManager class]]) {
 return [self xinfangPhoneNumberWithData:data];      //这是调用了派生后reformer子类自己实现的函数，别忘了reformer自己也是一个对象呀。
 //reformer也可以有自己的属性，当进行业务逻辑需要一些外部的辅助数据的时候，
 //外部使用者可以在使用reformer之前给reformer设置好属性，使得进行业务逻辑时，
 //reformer能够用得上必需的辅助数据。
 }
 
*/
- (id)request:(__kindof HYBaseRequest *)request reformData:(NSDictionary *)data;
//用于获取服务器返回的错误信息
@optional
- (id)request:(__kindof HYBaseRequest *)manager failedReform:(NSDictionary *)data;

@end
    
@interface HYBaseRequest : NSObject

/// from reform
@property (nonatomic, strong, readonly) id reformData;

///  The underlying NSURLSessionTask.
///
///  @warning This value is actually nil and should not be accessed before the request starts.
@property (nonatomic, strong, readonly) NSURLSessionTask *requestTask;

///  Shortcut for `requestTask.currentRequest`.
@property (nonatomic, strong, readonly) NSURLRequest *currentRequest;

///  Shortcut for `requestTask.originalRequest`.
@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;

///  Shortcut for `requestTask.response`.
@property (nonatomic, strong, readonly) NSHTTPURLResponse *response;

///  The response status code.
@property (nonatomic, readonly) NSInteger responseStatusCode;

///  The response header fields.
@property (nonatomic, strong, readonly, nullable) NSDictionary *responseHeaders;

///  The raw data representation of response. Note this value can be nil if request failed.
@property (nonatomic, strong, readonly, nullable) NSData *responseData;

///  The string representation of response. Note this value can be nil if request failed.
@property (nonatomic, strong, readonly, nullable) NSString *responseString;

///  This serialized response object. The actual type of this object is determined by
///  `YTKResponseSerializerType`. Note this value can be nil if request failed.
///
///  @discussion If `resumableDownloadPath` and DownloadTask is using, this value will
///              be the path to which file is successfully saved (NSURL), or nil if request failed.
@property (nonatomic, strong, readonly, nullable) id responseObject;

///  If you use `YTKResponseSerializerTypeJSON`, this is a convenience (and sematic) getter
///  for the response object. Otherwise this value is nil.
@property (nonatomic, strong, readonly, nullable) id responseJSONObject;

///  This error can be either serialization error or network error. If nothing wrong happens
///  this value will be nil.
@property (nonatomic, strong, readonly, nullable) NSError *error;

///  Return cancelled state of request task.
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;

///  Executing state of request task.
@property (nonatomic, readonly, getter=isExecuting) BOOL executing;

#pragma mark - Request reformer

@property (nonatomic, strong, nullable) id<HYRequestDataReformer> reformer;

#pragma mark - Request Configuration

@property (nonatomic) NSInteger tag;

@property (nonatomic, strong, nullable) NSDictionary *userInfo;

@property (nonatomic, weak, nullable) id<HYRequestDelegate> delegate;

@property (nonatomic, copy, nullable) HYRequestCompletionBlock successCompletionBlock;

@property (nonatomic, copy, nullable) HYRequestCompletionBlock failureCompletionBlock;

///  This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
///  this array will be automatically created. Default is nil.
@property (nonatomic, strong, nullable) NSMutableArray<id<HYRequestAccessory>> *requestAccessories;

///  This can be use to construct HTTP body when needed in POST request. Default is nil.
@property (nonatomic, copy, nullable) AFConstructingBlock constructingBodyBlock;

@property (nonatomic, strong, nullable) NSString *resumableDownloadPath;


//request.resumableDownloadProgressBlock = ^(NSProgress *progress) {
//    NSLog(@"Downloading: %lld / %lld", progress.completedUnitCount, progress.totalUnitCount);
//};

@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock resumableDownloadProgressBlock;

@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock uploadProgressBlock;

//重定向block
@property (nonatomic, copy, nullable) AFURLSessionTaskWillPerformHTTPRedirectionBlock taskWillPerformHTTPRedirection;

@property (nonatomic) HYRequestPriority requestPriority;

- (void)setCompletionBlockWithSuccess:(nullable HYRequestCompletionBlock)success
                              failure:(nullable HYRequestCompletionBlock)failure;

///  Nil out both success and failure callback blocks.
- (void)clearCompletionBlock;

///  Convenience method to add request accessory. See also `requestAccessories`.
- (void)addAccessory:(id<HYRequestAccessory>)accessory;

#pragma mark - Request Action
///=============================================================================
/// @name Request Action
///=============================================================================

///  Append self to request queue and start the request.
- (void)start;

///  Remove self from request queue and cancel the request.
- (void)stop;

///  Convenience method to start the request with block callbacks.
- (void)startWithCompletionBlockWithSuccess:(nullable HYRequestCompletionBlock)success
                                    failure:(nullable HYRequestCompletionBlock)failure;

#pragma mark - Subclass Override
///  Called on background thread after request succeded but before switching to main thread. Note if
///  cache is loaded, this method WILL be called on the main thread, just like `requestCompleteFilter`.
- (void)requestCompletePreprocessor;

///  Called on the main thread after request succeeded.
- (void)requestCompleteFilter;

///  Called on background thread after request succeded but before switching to main thread. See also
///  `requestCompletePreprocessor`.
- (void)requestFailedPreprocessor;

///  Called on the main thread when request failed.
- (void)requestFailedFilter;

///  The baseURL of request. This should only contain the host part of URL, e.g., http://www.example.com.
///  See also `requestUrl`
- (NSString *)baseUrl;

- (NSString *)requestUrl;

- (NSString *)cdnUrl;

- (NSTimeInterval)requestTimeoutInterval;

///  Additional request argument.
- (nullable id)requestArgument;

///  Override this method to filter requests with certain arguments when caching.
- (id)cacheFileNameFilterForRequestArgument:(id)argument;

- (HYRequestMethod)requestMethod;

///  Request serializer type.
- (HYRequestSerializerType)requestSerializerType;

- (HYResponseSerializerType)responseSerializerType;

///  Username and password used for HTTP authorization. Should be formed as @[@"Username", @"Password"].
- (nullable NSArray<NSString *> *)requestAuthorizationHeaderFieldArray;

///  Additional HTTP request header field.
- (nullable NSDictionary<NSString *, NSString *> *)requestHeaderFieldValueDictionary;

///  Use this to build custom request. If this method return non-nil value, `requestUrl`, `requestTimeoutInterval`,
///  `requestArgument`, `allowsCellularAccess`, `requestMethod` and `requestSerializerType` will all be ignored.
- (nullable NSURLRequest *)buildCustomUrlRequest;

///  Should use CDN when sending request.
- (BOOL)useCDN;

///  Whether the request is allowed to use the cellular radio (if present). Default is YES.
- (BOOL)allowsCellularAccess;

- (nullable id)jsonValidator;

- (BOOL)statusCodeValidator;

@end

NS_ASSUME_NONNULL_END
