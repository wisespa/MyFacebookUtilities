//
//  FacebookUtils.h
//  vpnfire
//
//  Created by Quan Jiang on 4/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Facebook.h"
#define  FB_ACCESS_TOKEN_KEY @"FBAccessTokenKey"
#define  FB_EXPIRE_DATE_KEY @"FBExpirationDateKey"

typedef enum {
    FACEBOOK_UPLOAD_PHOTO = 1,
    FACEBOOK_IMAGE_METADATA = 2,
    FACEBOOK_POST_FEED = 3,
    FACEBOOK_PERMISSIONS = 4,
    FACEBOOK_LOGIN = 5,
    FACEBOOK_AUTHORIZE = 6,
    FACEBOOK_USERINFO = 7,
    FACEBOOK_CREATE_ALBUM = 8,

    FACEBOOK_OP_NONE = 100
} FACEBOOK_OP;

@interface FacebookUtils : NSObject <FBSessionDelegate, FBRequestDelegate> {
    NSMutableSet* listeners;
    Facebook *facebook;
    NSMutableDictionary *userPermissions;
}

@property (nonatomic, retain) Facebook *facebook;
@property (nonatomic, retain) NSMutableDictionary *userPermissions;

+ (FacebookUtils*) sharedInstance;
- (void) initWithAppId: (NSString*) kAppId urlSchemeSuffix: (NSString*) urlSchemeSuffix;
- (void) addLister: (id<FBSessionDelegate>) listener;
- (void) removeLister: (id<FBSessionDelegate>) listener;

+ (NSArray*) getDefaultActionLinks: (NSString*) link;
+ (NSArray*) getGrantedPermissions: (NSDictionary*) rawData;

/*
 * Dialog: Feed for friend
 */
+ (void) dialogFeedFriend:(NSString*) friendID delegate: (id<FBDialogDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks;

/*
 * Upload photo to album
 */
+ (void) uploadPhotoToAlbum: (UIImage*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks;

/**
 * Upload photo data to an existing album with album id
 */
+ (void) uploadPhotoToAlbum: (UIImage*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks albumId:(NSString*) albumId;

/*
 * Upload photo data to facebook app's default album
 */
+ (void) uploadPhotoDataToAlbum: (NSData*) image delegate: (id<FBRequestDelegate>) delegate params: (NSDictionary *) params actionLinks: (NSArray*) actionLinks;

/*
 * Get current permissions
 */
+ (void) getCurrentPermissions: (id<FBRequestDelegate>) delegate;

/*
 * Get image meta data
 */
+ (void) getImageMetaData: (NSString*) imageId delegate:(id<FBRequestDelegate>) delegate;

/*
 * Helper method for posting photo
 */
+(NSURLRequest *) postRequestWithURL:(NSString *)url data: (NSData *)data   
                            fileName: (NSString*)fileName;

+(void) getUserInfo: (id<FBRequestDelegate>) delegate;

+(void) createAlbum:(id<FBRequestDelegate>) delegate name:(NSString*) name desc:(NSString*) desc location:(NSString*) location;

@end
