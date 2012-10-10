//
//  SinaWeiboConstants.h
//  sinaweibo_ios_sdk
//
//  Created by Wade Cheng on 4/22/12.
//  Copyright (c) 2012 SINA. All rights reserved.
//

#ifndef sinaweibo_ios_sdk_SinaWeiboConstants_h
#define sinaweibo_ios_sdk_SinaWeiboConstants_h

#define kSinaWeiboSDKErrorDomain           @"SinaWeiboSDKErrorDomain"
#define kSinaWeiboSDKErrorCodeKey          @"SinaWeiboSDKErrorCodeKey"

#define kSinaWeiboSDKAPIDomain             @"https://api.weibo.com/2/"
#define kSinaWeiboSDKOAuth2APIDomain       @"https://api.weibo.com/2/oauth2/"
#define kSinaWeiboWebAuthURL               @"https://api.weibo.com/2/oauth2/authorize"
#define kSinaWeiboWebAccessTokenURL        @"https://api.weibo.com/2/oauth2/access_token"


typedef enum
{
	kSinaWeiboSDKErrorCodeParseError       = 200,
	kSinaWeiboSDKErrorCodeSSOParamsError   = 202,
} SinaWeiboSDKErrorCode;

#endif