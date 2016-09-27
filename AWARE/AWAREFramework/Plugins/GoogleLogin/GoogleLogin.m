//
//  GoogleLogin.m
//  AWARE
//
//  Created by Yuuki Nishiyama on 1/6/16.
//  Copyright © 2016 Yuuki NISHIYAMA. All rights reserved.
//

#import "GoogleLogin.h"
#import "AWAREKeys.h"
#import "AWAREUtils.h"
#import "TCQMaker.h"

@implementation GoogleLogin {
    NSString* KEY_GOOGLE_NAME;
    NSString* KEY_GOOGLE_EMAIL;
    NSString* KEY_GOOGLE_BLOB_PICTURE;
    NSString* KEY_GOOGLE_PHONENUMBER;
    NSString* KEY_GOOGLE_USER_ID;
    
    BOOL encryptionName;
    BOOL encryptionEmail;
    BOOL encryptionUserId;
}

- (instancetype)initWithAwareStudy:(AWAREStudy *)study dbType:(AwareDBType)dbType{
    self = [super initWithAwareStudy:study
                          sensorName:SENSOR_PLUGIN_GOOGLE_LOGIN
                        dbEntityName:nil
                              dbType:AwareDBTypeTextFile];
    if (self) {
        KEY_GOOGLE_USER_ID = @"user_id";
        KEY_GOOGLE_NAME = @"name";
        KEY_GOOGLE_EMAIL = @"email";
        KEY_GOOGLE_BLOB_PICTURE = @"blob_picture";
        KEY_GOOGLE_PHONENUMBER = @"phonenumber";
        encryptionName = NO;
        encryptionEmail = NO;
        encryptionUserId = NO;
        [self allowsCellularAccess];
        [self allowsDateUploadWithoutBatteryCharging];
    }
    return self;
}

- (void) createTable {
    // Send a table create query
    NSLog(@"[%@] Crate table.", [self getSensorName]);
    
    TCQMaker * tcqMaker = [[TCQMaker alloc] init];
    [tcqMaker addColumn:KEY_GOOGLE_USER_ID type:TCQTypeText default:@"''"];
    [tcqMaker addColumn:KEY_GOOGLE_NAME type:TCQTypeText default:@"''"];
    [tcqMaker addColumn:KEY_GOOGLE_EMAIL type:TCQTypeText default:@"''"];
    
    // [query appendFormat:@"%@ text default '',", KEY_GOOGLE_USER_ID];
    // [query appendFormat:@"%@ text default ''", KEY_GOOGLE_EMAIL];
    // [query appendFormat:@"%@ text default '',", KEY_GOOGLE_PHONENUMBER];
    // [query appendFormat:@"%@ blob ", KEY_GOOGLE_BLOB_PICTURE];
    // [query appendString:@"UNIQUE (timestamp,device_id)"];
    
    [super createTable:[tcqMaker getDefaudltTableCreateQuery]];
}

- (BOOL)startSensorWithSettings:(NSArray *)settings{
    
    encryptionName = [self getBoolFromSettings:settings withKey:@"encryption_name_sha1"];
    encryptionEmail = [self getBoolFromSettings:settings withKey:@"encryption_email_sha1"];
    encryptionUserId = [self getBoolFromSettings:settings withKey:@"encryption_user_id_sha1"];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:encryptionName    forKey:@"encryption_name_sha1"];
    [defaults setBool:encryptionEmail   forKey:@"encryption_email_sha1"];
    [defaults setBool:encryptionUserId  forKey:@"encryption_user_id_sha1"];
    
    BOOL success = [self saveStoredGoogleAccount];
    if(!success){
        NSLog(@"[%@] Google account information is empty", [self getSensorName]);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Google account is required!"
                                                        message:@"Please login to Google account from Google Login row."
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
    }
    return YES;
}

- (BOOL)stopSensor {
    return YES;
}

//////////////////////////////////////////////////////

- (void) setGoogleAccountWithUserId:(NSString *)userId
                               name:(NSString* )name
                              email:(NSString *)email {
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userId  forKey:@"GOOGLE_ID"];
    [defaults setObject:name    forKey:@"GOOGLE_NAME"];
    [defaults setObject:email   forKey:@"GOOGLE_EMAIL"];
    [defaults synchronize];
    
    [self saveStoredGoogleAccount];
}


- (BOOL) saveStoredGoogleAccount {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString * userId = [defaults objectForKey:@"GOOGLE_ID"];
    NSString * name = [defaults objectForKey:@"GOOGLE_NAME"];
    NSString * email = [defaults objectForKey:@"GOOGLE_EMAIL"];
    
    encryptionName   = [defaults boolForKey:@"encryption_name_sha1"];
    encryptionEmail  = [defaults boolForKey:@"encryption_email_sha1"];
    encryptionUserId = [defaults boolForKey:@"encryption_user_id_sha1"];
    
    if(email == nil || userId == nil || name == nil){
        return NO;
    }
    
    if(email != nil && encryptionEmail) {
        email = [AWAREUtils sha1:email];
    }
    
    if(name != nil && encryptionName){
        name = [AWAREUtils sha1:name];
    }
    
    if(userId != nil && encryptionUserId){
        userId = [AWAREUtils sha1:userId];
    }
    
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSNumber * unixtime = [AWAREUtils getUnixTimestamp:[NSDate new]];
    [dict setObject:unixtime           forKey:@"timestamp"];
    [dict setObject:[self getDeviceId] forKey:@"device_id"];
    [dict setObject:userId             forKey:KEY_GOOGLE_USER_ID];
    [dict setObject:name               forKey:KEY_GOOGLE_NAME];
    [dict setObject:email              forKey:KEY_GOOGLE_EMAIL];
    //[dic setObject:[NSNull null]      forKey:KEY_GOOGLE_BLOB_PICTURE];
    [self saveData:dict];
    [self setLatestData:dict];
    [self performSelector:@selector(syncAwareDB) withObject:0 afterDelay:3];
    return YES;
}


- (void)saveDummyData{
    
    NSString * email = @"dummy_email";
    NSString * userId = @"dummy_user_id";
    NSString * name = @"dummy_name";
    
    if(email != nil && encryptionEmail) {
        email = [AWAREUtils sha1:email];
    }
    
    if(name != nil && encryptionName){
        name = [AWAREUtils sha1:name];
    }
    
    if(userId != nil && encryptionUserId){
        userId = [AWAREUtils sha1:userId];
    }
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    NSNumber * unixtime = [AWAREUtils getUnixTimestamp:[NSDate new]];
    [dic setObject:unixtime           forKey:@"timestamp"];
    [dic setObject:[self getDeviceId] forKey:@"device_id"];
    [dic setObject:userId             forKey:KEY_GOOGLE_USER_ID];
    [dic setObject:name               forKey:KEY_GOOGLE_NAME];
    [dic setObject:email              forKey:KEY_GOOGLE_EMAIL];
    [self saveData:dic];
}

//////////////////////////////////////////////////////

-(BOOL) getBoolFromSettings:(NSArray *)settings withKey:(NSString * )key{
    
    if (settings == nil) return NO;
    
    for (NSDictionary * setting in settings) {
        if ([[setting objectForKey:@"setting"] isEqualToString:key]) {
            BOOL value = [[setting objectForKey:@"value"] boolValue];
            return value;
        }
    }
    return NO;
}


@end
