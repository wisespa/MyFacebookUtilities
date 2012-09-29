//
//  FacebookUtils.m
//  vpnfire
//
//  Created by Quan Jiang on 4/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FacebookUtils.h"

@implementation FacebookUtils
static FacebookUtils *sharedInstance;

@synthesize facebook, userPermissions;

- (void)dealloc {  
    RELEASE_SAFELY(listeners);
    RELEASE_SAFELY(facebook);
    RELEASE_SAFELY(userPermissions);
    
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self != nil) {
        listeners = [[NSMutableSet alloc] init];
    }
    return self;
}

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
        sharedInstance = [[FacebookUtils alloc] init];
    }
}

+ (FacebookUtils*) sharedInstance
{
    return sharedInstance;
}

- (void) initWithAppId: (NSString*) kAppId urlSchemeSuffix: (NSString*) urlSchemeSuffix {
    // Initialize Facebook
    if (urlSchemeSuffix == nil) {
        facebook = [[Facebook alloc] initWithAppId:kAppId andDelegate:self];
    } else {
        facebook = [[Facebook alloc] initWithAppId:kAppId urlSchemeSuffix:urlSchemeSuffix andDelegate:self];    
    }

    // Check and retrieve authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:FB_ACCESS_TOKEN_KEY] && [defaults objectForKey:FB_EXPIRE_DATE_KEY]) {
        facebook.accessToken = [defaults objectForKey:FB_ACCESS_TOKEN_KEY];
        facebook.expirationDate = [defaults objectForKey:FB_EXPIRE_DATE_KEY];
    }

    // Initialize user permissions
    userPermissions = [[NSMutableDictionary alloc] initWithCapacity:1];
}

- (void) testFacebookIntegration: (NSString*) kAppId {
    // Check App ID:
    // This is really a warning for the developer, this should not
    // happen in a completed app
    if (!kAppId) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Setup Error"
                                  message:@"Missing app ID. You cannot run the app until you provide this in the code."
                                  delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil,
                                  nil];
        [alertView show];
        [alertView release];
    } else {
        // Now check that the URL scheme fb[app_id]://authorize is in the .plist and can
        // be opened, doing a simple check without local app id factored in here
        NSString *url = [NSString stringWithFormat:@"fb%@://authorize", kAppId];
        BOOL bSchemeInPlist = NO; // find out if the sceme is in the plist file.
        NSArray* aBundleURLTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
        if ([aBundleURLTypes isKindOfClass:[NSArray class]] &&
            ([aBundleURLTypes count] > 0)) {
            NSDictionary* aBundleURLTypes0 = [aBundleURLTypes objectAtIndex:0];
            if ([aBundleURLTypes0 isKindOfClass:[NSDictionary class]]) {
                NSArray* aBundleURLSchemes = [aBundleURLTypes0 objectForKey:@"CFBundleURLSchemes"];
                if ([aBundleURLSchemes isKindOfClass:[NSArray class]] &&
                    ([aBundleURLSchemes count] > 0)) {
                    NSString *scheme = [aBundleURLSchemes objectAtIndex:0];
                    if ([scheme isKindOfClass:[NSString class]] &&
                        [url hasPrefix:scheme]) {
                        bSchemeInPlist = YES;
                    }
                }
            }
        }
        // Check if the authorization callback will work
        BOOL bCanOpenUrl = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString: url]];
        if (!bSchemeInPlist || !bCanOpenUrl) {
            UIAlertView *alertView = [[UIAlertView alloc]
                                      initWithTitle:@"Setup Error"
                                      message:@"Invalid or missing URL scheme. You cannot run the app until you set up a valid URL scheme in your .plist."
                                      delegate:self
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil,
                                      nil];
            [alertView show];
            [alertView release];
        }
    }
}

#pragma mark - FBSessionDelegate Methods
- (void)storeAuthData:(NSString *)accessToken expiresAt:(NSDate *)expiresAt {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:FB_ACCESS_TOKEN_KEY];
    [defaults setObject:expiresAt forKey:FB_EXPIRE_DATE_KEY];
    [defaults synchronize];
}

-(void)fbDidExtendToken:(NSString *)accessToken expiresAt:(NSDate *)expiresAt {
    DLog(@"token extended");
    [self storeAuthData:accessToken expiresAt:expiresAt];
}

- (void)fbDidLogin {
    [self storeAuthData:[facebook accessToken] expiresAt:[facebook expirationDate]];
    
    for(id<FBSessionDelegate> listener in listeners) {
        [listener fbDidLogin];
    }
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    for(id<FBSessionDelegate> listener in listeners) {
        [listener fbDidNotLogin: cancelled];
    }
}

- (void)fbDidLogout {
    // Remove saved authorization information if it exists and it is
    // ok to clear it (logout, session invalid, app unauthorized)
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:FB_ACCESS_TOKEN_KEY];
    [defaults removeObjectForKey:FB_EXPIRE_DATE_KEY];
    [defaults synchronize];
    
    for(id<FBSessionDelegate> listener in listeners) {
        [listener fbDidLogout];
    }
}

- (void)fbSessionInvalidated {
    [self fbDidLogout];
}

- (void) addLister: (id<FBSessionDelegate>) listener {
    if (listener != nil) {
        [listeners addObject:listener];
        DLog(@"Facebook listener added");
    }
}

- (void) removeLister: (id<FBSessionDelegate>) listener {
    if (listener != nil) {
        [listeners removeObject:listener];
        DLog(@"Facebook listener removed");
    }
}

+ (NSArray*) getDefaultActionLinks: (NSString*) link {    
    NSArray* actionLinks = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      @"Download this app",@"name",
                                                      link,@"link", nil], nil];
    
    return actionLinks;
}

+ (NSArray*) getGrantedPermissions: (NSArray*) rawData {
    if (rawData == nil || [rawData count] == 0) {
        return nil;
    }
                           
    NSMutableArray* permissions = [NSMutableArray array];
    for (NSDictionary* permissionList in rawData) {
        for (NSString* permission in [permissionList allKeys]) {
            if ([[permissionList objectForKey:permission] boolValue]) {
                [permissions addObject:permission];
            }
        }
    }
    
    return  permissions;
}

/*
 * Dialog: Feed for friend
 */
+ (void) dialogFeedFriend:(NSString*) friendID delegate: (id<FBDialogDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks {
    if (friendID == nil) {
        return;
    }
        
    NSError *e = nil;
    NSString *actionLinksStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:actionLinks options:0 error:&e] encoding:NSUTF8StringEncoding];

    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [allParams setObject:friendID forKey:@"to"];
    [allParams setObject:actionLinksStr forKey:@"actions"];
                
    
    [[sharedInstance facebook] dialog:@"feed" andParams:allParams andDelegate:delegate];
}

/*
 * Dialog: request a message to friends
 */
+ (void) dialogFriendRequest:(NSArray*) friendIDs delegate: (id<FBDialogDelegate>) delegate params: (NSDictionary *) params {
    if (friendIDs == nil || [friendIDs count] == 0) {
        return;
    }
    
    NSMutableArray* theIDs;

    if ([friendIDs count] > 50) {
        theIDs = [NSMutableArray arrayWithCapacity:50];//maximum is 50
        for(int i = 0; i < 50; i++) {
            theIDs[i] = friendIDs[i];
        }
    } else {
        theIDs = [NSMutableArray arrayWithArray:friendIDs];
    }
    
    NSError *e = nil;
    NSString *friendIdsStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:theIDs options:0 error:&e] encoding:NSUTF8StringEncoding];
    
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [allParams setObject:friendIdsStr forKey:@"to"];    
    
    [[sharedInstance facebook] dialog:@"apprequests" andParams:allParams andDelegate:delegate];
}

/*
 * Upload photo to album
 */
+ (void) uploadPhotoToAlbum: (UIImage*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks albumId:(NSString*) albumId{
    if (!albumId) {
        return;
    }
    
    NSError *e = nil;
    NSString *actionLinksStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:actionLinks options:0 error:&e] encoding:NSUTF8StringEncoding];
    
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc]initWithDictionary:params];//no autorelease, facebook SDK will release it
    [allParams setObject:image forKey:@"picture"];
    [allParams setObject:actionLinksStr forKey:@"actions"];
    
    [[sharedInstance facebook] requestWithGraphPath:[NSString stringWithFormat:@"%@/photos", albumId]
                                          andParams:allParams
                                      andHttpMethod:@"POST"
                                        andDelegate:delegate];
}

/*
 * Upload photo to album
 */
+ (void) uploadPhotoToAlbum: (UIImage*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks {
    NSError *e = nil;
    NSString *actionLinksStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:actionLinks options:0 error:&e] encoding:NSUTF8StringEncoding];
    
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc]initWithDictionary:params];//no autorelease, facebook SDK will release it
    [allParams setObject:image forKey:@"picture"];
    [allParams setObject:actionLinksStr forKey:@"actions"];

    [[sharedInstance facebook] requestWithGraphPath:@"me/photos"
                                                          andParams:allParams
                                                      andHttpMethod:@"POST"
                                                        andDelegate:delegate];
}

/*
 * Upload photo to album
 */
+ (void) uploadPhotoDataToAlbum: (NSData*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks {
    NSError *e = nil;
    NSString *actionLinksStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:actionLinks options:0 error:&e] encoding:NSUTF8StringEncoding];
    
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc]initWithDictionary:params];//no autorelease, facebook SDK will release it
    [allParams setObject:image forKey:@"picture"];
    [allParams setObject:actionLinksStr forKey:@"actions"];
    
    [[sharedInstance facebook] requestWithGraphPath:@"me/photos"
                                          andParams:allParams
                                      andHttpMethod:@"POST"
                                        andDelegate:delegate];
}

+(void) createAlbum:(id<FBRequestDelegate>) delegate name:(NSString*) name desc:(NSString*) desc location:(NSString*) location
{    
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc] init];//no autorelease, facebook SDK will release it
    [allParams setObject:name forKey:@"name"];
    if (desc != nil) {
        [allParams setObject:desc forKey:@"message"];
    }
    if (location != nil) {
        [allParams setObject:location forKey:@"location"];
    }

    [[sharedInstance facebook] requestWithGraphPath:@"me/albums"
                                          andParams:allParams
                                      andHttpMethod:@"POST"
                                        andDelegate:delegate];
}

/*
 * Get current permissions
 */
+ (void) getCurrentPermissions: (id<FBRequestDelegate>) delegate {    
    [[sharedInstance facebook] requestWithGraphPath:@"me/permissions"
                                        andDelegate:delegate];
}

/*
 * Get image meta data
 */
+ (void) getImageMetaData: (NSString*) imageId delegate:(id<FBRequestDelegate>) delegate {    
    [[sharedInstance facebook] requestWithGraphPath:imageId
                                        andDelegate:delegate];
}


/*
 * Helper method for posting photo.
 */
+(NSURLRequest *) postRequestWithURL:(NSString *)url data: (NSData *)data   
                            fileName: (NSString*)fileName
{
    NSMutableURLRequest *urlRequest = [[[NSMutableURLRequest alloc] init] autorelease];
    [urlRequest setURL:[NSURL URLWithString:url]];
    
    [urlRequest setHTTPMethod:@"POST"];
    
    NSString *myboundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",myboundary];
    [urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *postData = [NSMutableData data];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"source\"; filename=\"%@\"\r\n", fileName]dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[NSData dataWithData:data]];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [urlRequest setHTTPBody:postData];
    return urlRequest;
}

+(void) getUserInfo: (id<FBRequestDelegate>) delegate {
    [[sharedInstance facebook] requestWithGraphPath:@"me"
                                        andDelegate:delegate];
}
@end
