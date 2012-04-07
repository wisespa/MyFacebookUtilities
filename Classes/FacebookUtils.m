//
//  FacebookUtils.m
//  vpnfire
//
//  Created by Quan Jiang on 4/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FacebookUtils.h"
#import "SBJSON.h"

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
    NSLog(@"token extended");
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
        NSLog(@"Facebook listener added");
    }
}

- (void) removeLister: (id<FBSessionDelegate>) listener {
    if (listener != nil) {
        [listeners removeObject:listener];
        NSLog(@"Facebook listener removed");
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
    
    SBJSON *jsonWriter = [[SBJSON new] autorelease];
                               
    NSString *actionLinksStr = [jsonWriter stringWithObject:actionLinks];
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [allParams setObject:friendID forKey:@"to"];
    [allParams setObject:actionLinksStr forKey:@"actions"];
                
    
    [[sharedInstance facebook] dialog:@"feed" andParams:allParams andDelegate:delegate];
}

/*
 * Upload photo to album
 */
+ (void) uploadPhotoToAlbum: (UIImage*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks {
    SBJSON *jsonWriter = [[SBJSON new] autorelease];
    
    NSString *actionLinksStr = [jsonWriter stringWithObject:actionLinks];
    // The "to" parameter targets the post to a friend
    NSMutableDictionary *allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [allParams setObject:image forKey:@"picture"];
    [allParams setObject:actionLinksStr forKey:@"actions"];

    [[sharedInstance facebook] requestWithGraphPath:@"me/photos"
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


@end