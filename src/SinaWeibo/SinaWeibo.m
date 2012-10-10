//
//  SinaWeibo.m
//  sinaweibo_ios_sdk
//
//  Created by Wade Cheng on 4/19/12.
//  Copyright (c) 2012 SINA. All rights reserved.
//

#import "SinaWeibo.h"
#import "SinaWeiboRequest.h"
#import "SinaWeiboAuthorizeView.h"
#import "SinaWeiboConstants.h"

@interface SinaWeibo ()

@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *appSecret;
@property (nonatomic, copy) NSString *appRedirectURI;

@end

@implementation SinaWeibo

@synthesize userID;
@synthesize accessToken;
@synthesize expirationDate;
@synthesize refreshToken;
@synthesize delegate;
@synthesize appKey;
@synthesize appSecret;
@synthesize appRedirectURI;

#pragma mark - Memory management

/**
 * @description 初始化构造函数，返回构造的SinaWeibo对象
 * @param _appKey: 分配给第三方应用的appkey
 * @param _appSecrect: 分配给第三方应用的appsecrect
 * @param _appRedirectURI: 微博开放平台中授权设置的应用回调页
 * @return SinaWeibo对象
 */
- (id)initWithAppKey:(NSString *)_appKey appSecret:(NSString *)_appSecrect
      appRedirectURI:(NSString *)_appRedirectURI
         andDelegate:(id<SinaWeiboDelegate>)_delegate
{
    if ((self = [super init]))
    {
        self.appKey = _appKey;
        self.appSecret = _appSecrect;
        self.appRedirectURI = _appRedirectURI;
        self.delegate = _delegate;
        
        requests = [[NSMutableSet alloc] init];
    }
    
    return self;
}



- (void)dealloc
{
    delegate = nil;
    
    for (SinaWeiboRequest* _request in requests)
    {
        _request.sinaweibo = nil;
    }
    
    [request disconnect];
    [request release], request = nil;
    [userID release], userID = nil;
    [accessToken release], accessToken = nil;
    [expirationDate release], expirationDate = nil;
    [appKey release], appKey = nil;
    [appSecret release], appSecret = nil;
    [appRedirectURI release], appRedirectURI = nil;
    
    [super dealloc];
}

/**
 * @description 清空认证信息
 */
- (void)removeAuthData
{
    self.accessToken = nil;
    self.userID = nil;
    self.expirationDate = nil;
    
    NSHTTPCookieStorage* cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray* sinaweiboCookies = [cookies cookiesForURL:
                                [NSURL URLWithString:@"http://api.weibo.com"]];
    
    for (NSHTTPCookie* cookie in sinaweiboCookies)
    {
        [cookies deleteCookie:cookie];
    }
}

#pragma mark - Private methods

- (void)requestAccessTokenWithAuthorizationCode:(NSString *)code
{
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.appKey, @"client_id",
                            self.appSecret, @"client_secret",
                            @"authorization_code", @"grant_type",
                            self.appRedirectURI, @"redirect_uri",
                            code, @"code", nil];
    [request disconnect];
    [request release], request = nil;
    
    request = [[SinaWeiboRequest requestWithURL:kSinaWeiboWebAccessTokenURL
                                     httpMethod:@"POST"
                                         params:params
                                       delegate:self] retain];
    
    [request connect];
}

- (void)requestDidFinish:(SinaWeiboRequest *)_request
{
    [requests removeObject:_request];
    _request.sinaweibo = nil;
}

- (void)requestDidFailWithInvalidToken:(NSError *)error
{
    if ([delegate respondsToSelector:@selector(sinaweibo:accessTokenInvalidOrExpired:)])
    {
        [delegate sinaweibo:self accessTokenInvalidOrExpired:error];
    }
}

- (void)notifyTokenExpired:(id<SinaWeiboRequestDelegate>)requestDelegate
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Token expired", NSLocalizedDescriptionKey, nil];
    
    NSError *error = [NSError errorWithDomain:kSinaWeiboSDKErrorDomain
                                         code:21315
                                     userInfo:userInfo];
    
    if ([delegate respondsToSelector:@selector(sinaweibo:accessTokenInvalidOrExpired:)])
    {
        [delegate sinaweibo:self accessTokenInvalidOrExpired:error];
    }
    
    if ([requestDelegate respondsToSelector:@selector(request:didFailWithError:)]) 
	{
		[requestDelegate request:nil didFailWithError:error];
	}
}

- (void)logInDidCancel
{
    if ([delegate respondsToSelector:@selector(sinaweiboLogInDidCancel:)])
    {
        [delegate sinaweiboLogInDidCancel:self];
    }
}

- (void)logInDidFinishWithAuthInfo:(NSDictionary *)authInfo
{
    NSString *access_token = [authInfo objectForKey:@"access_token"];
    NSString *uid = [authInfo objectForKey:@"uid"];
    NSString *remind_in = [authInfo objectForKey:@"remind_in"];
    NSString *refresh_token = [authInfo objectForKey:@"refresh_token"];
    if (access_token && uid)
    {
        if (remind_in != nil)
        {
            int expVal = [remind_in intValue];
            if (expVal == 0)
            {
                self.expirationDate = [NSDate distantFuture];
            }
            else
            {
                self.expirationDate = [NSDate dateWithTimeIntervalSinceNow:expVal];
            } 
        } 
        
        self.accessToken = access_token;
        self.userID = uid;
        self.refreshToken = refresh_token;
        
        if ([delegate respondsToSelector:@selector(sinaweiboDidLogIn:)])
        {
            [delegate sinaweiboDidLogIn:self];
        }
    }
}

- (void)logInDidFailWithErrorInfo:(NSDictionary *)errorInfo
{
    NSString *error_code = [errorInfo objectForKey:@"error_code"];
    if ([error_code isEqualToString:@"21330"])
    {
        [self logInDidCancel];
    }
    else
    {
        if ([delegate respondsToSelector:@selector(sinaweibo:logInDidFailWithError:)])
        {
            NSString *error_description = [errorInfo objectForKey:@"error_description"];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      errorInfo, @"error",
                                      error_description, NSLocalizedDescriptionKey, nil];
            NSError *error = [NSError errorWithDomain:kSinaWeiboSDKErrorDomain 
                                                 code:[error_code intValue]
                                             userInfo:userInfo];
            [delegate sinaweibo:self logInDidFailWithError:error];
        }
        
    }
}

#pragma mark - Validation

/**
 * @description 判断是否登录
 * @return YES为已登录；NO为未登录
 */
- (BOOL)isLoggedIn
{
    return userID && accessToken && expirationDate;
}

/**
 * @description 判断登录是否过期
 * @return YES为已过期；NO为未为期
 */
- (BOOL)isAuthorizeExpired
{
    NSDate *now = [NSDate date];
    return ([now compare:expirationDate] == NSOrderedDescending);
}


/**
 * @description 判断登录是否有效，当已登录并且登录未过期时为有效状态
 * @return YES为有效；NO为无效
 */
- (BOOL)isAuthValid
{
    return ([self isLoggedIn] && ![self isAuthorizeExpired]);
}

#pragma mark - LogIn / LogOut

/**
 * @description 登录入口，当初始化SinaWeibo对象完成后直接调用此方法完成登录
 */
- (void)logIn
{
    if ([self isAuthValid])
    {
        if ([delegate respondsToSelector:@selector(sinaweiboDidLogIn:)])
        {
            [delegate sinaweiboDidLogIn:self];
        }
    }
    else
    {
        [self removeAuthData];
        // open authorize view
            
        NSDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                self.appKey, @"client_id",
                                @"code", @"response_type",
                                self.appRedirectURI, @"redirect_uri", 
                                @"mobile", @"display", nil];
            
        SinaWeiboAuthorizeView *authorizeView = \
        [[SinaWeiboAuthorizeView alloc] initWithAuthParams:params
                                                    delegate:self];
        [authorizeView show];
        [authorizeView release];
    }
}

/**
 * @description 退出方法，需要退出时直接调用此方法
 */
- (void)logOut
{
    [self removeAuthData];
    
    if ([delegate respondsToSelector:@selector(sinaweiboDidLogOut:)])
    {
        [delegate sinaweiboDidLogOut:self];
    }
}

#pragma mark - Send request with token

/**
 * @description 微博API的请求接口，方法中自动完成token信息的拼接
 * @param url: 请求的接口
 * @param params: 请求的参数，如发微博所带的文字内容等
 * @param httpMethod: http类型，GET或POST
 * @param _delegate: 处理请求结果的回调的对象，SinaweiboRequestDelegate类
 * @return 完成实际请求操作的SinaWeiboRequest对象
 */

- (SinaWeiboRequest *)requestWithURL:(NSString *)url
                             params:(NSMutableDictionary *)params
                         httpMethod:(NSString *)httpMethod
                           delegate:(id<SinaWeiboRequestDelegate>)_delegate
{
    if (params == nil)
    {
        params = [NSMutableDictionary dictionary];
    }
    
    if ([self isAuthValid])
    {
        [params setValue:self.accessToken forKey:@"access_token"];
        NSString *fullURL = [kSinaWeiboSDKAPIDomain stringByAppendingString:url];
        
        SinaWeiboRequest *_request = [SinaWeiboRequest requestWithURL:fullURL
                                                           httpMethod:httpMethod
                                                               params:params
                                                             delegate:_delegate];
        _request.sinaweibo = self;
        [requests addObject:_request];
        [_request connect];
        return _request;
    }
    else
    {
        //notify token expired in next runloop
        [self performSelectorOnMainThread:@selector(notifyTokenExpired:)
                               withObject:_delegate
                            waitUntilDone:NO];
        
        return nil;
    }
}

#pragma mark - SinaWeiboAuthorizeView Delegate

- (void)authorizeView:(SinaWeiboAuthorizeView *)authView didRecieveAuthorizationCode:(NSString *)code
{
    [self requestAccessTokenWithAuthorizationCode:code];
}

- (void)authorizeView:(SinaWeiboAuthorizeView *)authView didFailWithErrorInfo:(NSDictionary *)errorInfo
{
    [self logInDidFailWithErrorInfo:errorInfo];
}

- (void)authorizeViewDidCancel:(SinaWeiboAuthorizeView *)authView
{
    [self logInDidCancel];
}

#pragma mark - SinaWeiboRequest Delegate

- (void)request:(SinaWeiboRequest *)_request didFailWithError:(NSError *)error
{
    if (_request == request)
    {
        if ([delegate respondsToSelector:@selector(sinaweibo:logInDidFailWithError:)])
        {
            [delegate sinaweibo:self logInDidFailWithError:error];
        }
        
        [request release], request = nil;
    }
}

- (void)request:(SinaWeiboRequest *)_request didFinishLoadingWithResult:(id)result
{
    if (_request == request)
    {
        NSLog(@"access token result = %@", result);
        
        [self logInDidFinishWithAuthInfo:result];
        [request release], request = nil;
    }
}


@end

BOOL SinaWeiboIsDeviceIPad()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        return YES;
    }
#endif
    return NO;
}
