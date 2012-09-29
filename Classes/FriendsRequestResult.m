/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FriendsRequestResult.h"
#import "PeopleInfo.h"

@implementation FriendsRequestResult


- (NSMutableArray*) parsePeople: (NSArray*) users
{
	DLog(@"Start parsing downloaded facebook info");
		
	NSMutableArray* newPeopleArray = [NSMutableArray array];

	if (users == nil || [users count] == 0) {
		return newPeopleArray;
	}
	
	static NSDateFormatter* dateFormatterWithYear = nil;
	if (dateFormatterWithYear == nil) {
		dateFormatterWithYear = [[NSDateFormatter alloc] init];
		[dateFormatterWithYear setDateFormat:@"MM/dd/yyyy"];
	}
	
	static NSDateFormatter* dateFormatterWithoutYear = nil;
	if (dateFormatterWithoutYear == nil) {
		dateFormatterWithoutYear = [[NSDateFormatter alloc] init];
		[dateFormatterWithoutYear setDateFormat:@"MM/dd"];
	}
		
	for (NSDictionary* friend in users){
		NSString* birthday_date = [friend objectForKey: @"birthday_date"];
		if (birthday_date == nil || (NSNull*) birthday_date == [NSNull null]) {//Must test NSNull
			continue;
		}
		
		BOOL knownBirthYear = YES;
		NSDate* birthday = [dateFormatterWithYear dateFromString: birthday_date];
		if (birthday == nil) {
			knownBirthYear = NO;
			birthday = [dateFormatterWithoutYear dateFromString: birthday_date];
		}
		
		if (birthday == nil) {//can't parse birthday
			continue;
		}
		
		NSString* first_name = [friend objectForKey:@"first_name"];
		NSString* last_name = [friend objectForKey:@"last_name"];
		NSString* pic_url = [friend objectForKey:@"pic"];
		NSString* uid = [friend objectForKey:@"uid"];
        if ([uid isKindOfClass:[NSNumber class]]) {
            uid = [(NSNumber*) uid stringValue];
        }
        
        NSString* username = [friend objectForKey:@"username"];
        
        if (first_name == nil || (NSNull*) first_name == [NSNull null] ||
            last_name == nil || (NSNull*) last_name == [NSNull null] ||
            uid == nil || (NSNull*) uid == [NSNull null]) {
            continue;
        }

		PeopleInfo* aPerson = [[[PeopleInfo alloc] init] autorelease];
		
		aPerson.type = PEOPLE_FACEBOOK_TYPE;
		aPerson.identifier = uid;
		aPerson.firstName = first_name;
		aPerson.lastName = last_name;
        aPerson.fbUserName = username;
		aPerson.knownBirthYear = knownBirthYear;
		
        // Must be the last one to set
        [aPerson setGregorianBirthday:birthday];
		
		if (pic_url != nil && (NSNull*) pic_url != [NSNull null]) {//must test NSNull
            aPerson.imageURL = pic_url;
		}
		
		DLog(@"Found facebook people with name: %@ %@, Birthday: %@", first_name, last_name, birthday_date);
		
		[newPeopleArray addObject:aPerson];//add to a collection for updating UI
	}
	
	DLog(@"Done parsing downloaded facebook info and saved to DB");

	return newPeopleArray;
}

- (id) initializeWithDelegate:(id<FriendsRequestDelegate>)delegate {
  self = [super init];
  _friendsRequestDelegate = [delegate retain];
  return self;   
}

/**
 * FBRequestDelegate
 */
- (void)request:(FBRequest*)request didLoad:(id)result{
    /** The result could be empty string */
    if (result == nil || [result isKindOfClass:[NSString class]]) {
        [_friendsRequestDelegate FriendsRequestCompleteWithFriendsInfo:nil];
        return;
    }

    NSMutableArray *friendsInfo = [self parsePeople:result];

    [_friendsRequestDelegate FriendsRequestCompleteWithFriendsInfo:friendsInfo];
}

@end
