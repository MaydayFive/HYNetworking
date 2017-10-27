//
//  HYRequestDataReformer.h
//  YTKNetworkDemo
//
//  Created by zheng on 2017/8/31.
//  Copyright © 2017年 yuantiku.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HYBaseRequest;

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
 
 if ([manager isKindOfClass:[zufangManager class]]) {
 return [self zufangPhoneNumberWithData:data];
 }
 
 if ([manager isKindOfClass:[ershoufangManager class]]) {
 return [self ershoufangPhoneNumberWithData:data];
 }
 }
 */
- (id)request:(__kindof HYBaseRequest *)request reformData:(NSDictionary *)data;
//用于获取服务器返回的错误信息
@optional
- (id)request:(__kindof HYBaseRequest *)manager failedReform:(NSDictionary *)data;

@end

@end
