//
//  AWAREStudy.m
//  AWARE for OSX
//
//  Created by Yuuki Nishiyama on 12/5/15.
//  Copyright © 2015 Yuuki NISHIYAMA. All rights reserved.
//

#import <SCNetworkReachability.h>
#import "AppDelegate.h"
#import "AWAREStudy.h"
#import "AWAREKeys.h"
#import "AWARESensorManager.h"
#import "AWARECore.h"
#import "SSLManager.h"
#import "AWAREUtils.h"
#import "PushNotification.h"

@implementation AWAREStudy {
    NSString *mqttPassword;
    NSString *mqttUsername;
    NSString *studyId;
    NSString *mqttServer;
    NSString *webserviceServer;
    int mqttPort;
    int mqttKeepAlive;
    int mqttQos;
    bool readingState;
    
    int frequencySyncDB;
    // (0 = never, 1 = weekly, 2 = monthly, 3 = daily, 4 = always)
    cleanOldDataType frequencyCleanOldData;
    bool webserviceWifiOnly;
    
    SCNetworkReachability * reachability;
    
    bool wifiReachable;
    NSInteger networkState;
}


- (instancetype) initWithReachability: (BOOL) reachabilityState{
    self = [super init];
    if (self) {
        _getSettingIdentifier = @"set_setting_identifier";
        _addDeviceTableIdentifier = @"add_device_table_identifier";
        _makeDeviceTableIdentifier = @"make_device_table_identifier";
        
        mqttPassword = @"";
        mqttUsername = @"";
        studyId = @"";
        mqttServer = @"";
        webserviceServer = @"";
        mqttPort = 1883;
        mqttKeepAlive = 600;
        mqttQos = 2;
        readingState = YES;
        frequencySyncDB = 30; //30 min
        // (0 = never, 1 = weekly, 2 = monthly, 3 = daily, 4 = always)
        frequencyCleanOldData = cleanOldDataTypeAlways;
        webserviceWifiOnly = NO;
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString* tempUserName = [userDefaults objectForKey:KEY_MQTT_USERNAME];
        if(tempUserName != nil){
            mqttServer = [userDefaults objectForKey:KEY_MQTT_SERVER];
            mqttUsername = [userDefaults objectForKey:KEY_MQTT_USERNAME];
            mqttPassword =  [userDefaults objectForKey:KEY_MQTT_PASS];
            mqttPort =  [[userDefaults objectForKey:KEY_MQTT_PORT] intValue];
            mqttKeepAlive = [[userDefaults objectForKey:KEY_MQTT_KEEP_ALIVE] intValue];
            mqttQos = [[userDefaults objectForKey:KEY_MQTT_QOS] intValue];
            studyId = [userDefaults objectForKey:KEY_STUDY_ID];
            webserviceServer = [userDefaults objectForKey:KEY_WEBSERVICE_SERVER];
        }
        if(reachabilityState){
            reachability = [[SCNetworkReachability alloc] initWithHost:@"www.google.com"];
            [reachability observeReachability:^(SCNetworkStatus status){
                networkState = status;
                switch (status){
                    case SCNetworkStatusReachableViaWiFi:
                        wifiReachable = YES;
                        break;
                    case SCNetworkStatusReachableViaCellular:
                        wifiReachable = NO;
                        break;
                    case SCNetworkStatusNotReachable:
                        wifiReachable = NO;
                        break;
                }
            }];
        }
    }
    return self;
}



/**
 * This method downloads and sets a study configuration by using study URL. (NOTE: This URL can get from a study QRCode.)
 *
 * @param url An study URL (e.g., https://r2d2.hcii.cs.cmu.edu/aware/dashboard/index.php/webservice/index/41/4LtzPxcAIrdi)
 * @return The result of download and set a study configuration
 */
- (BOOL) setStudyInformationWithURL:(NSString*)url {
//    if (url != nil) {
//        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
//        [userDefaults setObject:url forKey:KEY_STUDY_QR_CODE];
//    }
    if(url != nil){
        [self setStudyURL:url];
        NSString * deviceId = [AWAREUtils getSystemUUID];
        return [self setStudyInformation:url withDeviceId:deviceId];
    }else{
        return NO;
    }
}

/**
 * This method downloads and sets a study configuration by using study URL. (NOTE: This URL can get from a study QRCode.)
 *
 * @param url An study URL (e.g., https://r2d2.hcii.cs.cmu.edu/aware/dashboard/index.php/webservice/index/study_number/PASSWORD)
 * @param a device_id of this device
 * @return The result of download and set a study configuration
 */
- (bool) setStudyInformation:(NSString *)url withDeviceId:(NSString *) uuid {
    // __weak NSURLSession *session = nil;
    NSURLSession *session = nil;
    // Set session configuration
    NSURLSessionConfiguration *sessionConfig = nil;
    double unixtime = [[NSDate new] timeIntervalSince1970];
    _getSettingIdentifier = [NSString stringWithFormat:@"%@%f", _getSettingIdentifier, unixtime];
    
    url = [NSString stringWithFormat:@"%@?%f", url, unixtime];
    
    NSString *post = [NSString stringWithFormat:@"device_id=%@", uuid];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSURL * urlObj = [NSURL URLWithString:url];
    if(urlObj == nil){
        return NO;
    }
    [request setURL:urlObj];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:postData];

    
    if ( [AWAREUtils isForeground] ) { /// If the application in the foreground
        // NSURLSession *session = [NSURLSession sharedSession];
        session = [NSURLSession sessionWithConfiguration:[NSURLSession sharedSession].configuration
                                                              delegate:self
                                                         delegateQueue:nil];
        [[session dataTaskWithRequest: request  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            // Success
            if (response && ! error) {
                if(data != nil){
                    NSString *responseString = [[NSString alloc] initWithData: data  encoding: NSUTF8StringEncoding];
                    NSLog(@"Success: %@", responseString);
                    [self setStudySettings:data];
                }else{
                    NSLog(@"Error: Data is null");
                }
            // Error
            } else {
                // NSLog(@"Error: %@", error);
                NSLog(@"ERROR: %@ %ld", error.debugDescription , error.code);
                if (error.code == -1202) {
                    /**
                     * If the error code is -1202, this device needs .crt for SSL(secure) connection.
                     */
                    // Install CRT file for SSL
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    NSString* url = [userDefaults objectForKey:KEY_STUDY_QR_CODE];
                    SSLManager *sslManager = [[SSLManager alloc] init];
                    [sslManager installCRTWithTextOfQRCode:url];
                }
            }
            [session finishTasksAndInvalidate];
            [session invalidateAndCancel];
        }] resume];
    } else { // If the application in the background
        sessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_getSettingIdentifier];
        sessionConfig.timeoutIntervalForRequest = 60;
        sessionConfig.HTTPMaximumConnectionsPerHost = 60;
        sessionConfig.timeoutIntervalForResource = 60; //60*60*24; // 1 day
        sessionConfig.allowsCellularAccess = YES;
        sessionConfig.discretionary = YES;
        
        NSLog(@"--- This is background task ----");
        session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
        NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request];
        [dataTask resume];
    }
    return YES;
}


/* The task has received a response and no further messages will be
 * received until the completion block is called. The disposition
 * allows you to cancel a request or to turn a data task into a
 * download task. This delegate message is optional - if you do not
 * implement it, you can get the response as a property of the task.
 *
 * This method will not be called for background upload tasks (which cannot be converted to download tasks).
 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
    int responseCode = (int)[httpResponse statusCode];
    NSLog(@"%d",responseCode);
    [session finishTasksAndInvalidate];
    [session invalidateAndCancel];
    completionHandler(NSURLSessionResponseAllow);
}


/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
   didReceiveData:(NSData *)data {

    [self setStudySettings:data];
    [session finishTasksAndInvalidate];
    [session invalidateAndCancel];
}


/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error != nil) {
        NSLog(@"ERROR: %@ %ld", error.debugDescription , error.code);
        if (error.code == -1202) {
            /**
             * If the error code is -1202, this device needs .crt for SSL(secure) connection.
             */
            // Install CRT file for SSL
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSString* url = [userDefaults objectForKey:KEY_STUDY_QR_CODE];
            SSLManager *sslManager = [[SSLManager alloc] init];
            [sslManager installCRTWithTextOfQRCode:url];
        }
    }
    [session finishTasksAndInvalidate];
    [session invalidateAndCancel];
}




/**
 * This method sets downloaded study configurations.
 *
 * @param resData A response (study configurations) from the aware server
 */
- (void) setStudySettings:(NSData *) resData {
    NSArray *mqttArray = [NSJSONSerialization JSONObjectWithData:resData options:NSJSONReadingMutableContainers error:nil];
    id obj = [NSJSONSerialization JSONObjectWithData:resData options:NSJSONReadingMutableContainers error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    NSString * studyConfiguration = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    
    // compare the latest configuration string with the previous configuration string.
    NSString * previousConfig = [self removeStudyStartTimeFromConfig:[self getStudyConfigurationAsText]];
    NSString * currentConfig = [self removeStudyStartTimeFromConfig:studyConfiguration];
    if([previousConfig isEqualToString:currentConfig]){
        NSLog(@"The study configuration is same as previous configuration!");
        return ;
    }else{
        NSLog(@"The study configuration is updated!");
    }
    
    [self setStudyConfiguration:studyConfiguration];
    NSLog( @"%@", studyConfiguration );
    
    //    if(responseCode == 200){
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    webserviceWifiOnly = [userDefaults boolForKey:SETTING_SYNC_WIFI_ONLY];
    frequencySyncDB = [userDefaults doubleForKey:SETTING_SYNC_INT]/60;
    frequencyCleanOldData = [userDefaults integerForKey:SETTING_FREQUENCY_CLEAN_OLD_DATA];
    
    NSLog(@"GET Study Information");
    NSArray * array = [[mqttArray objectAtIndex:0] objectForKey:@"sensors"];
    NSArray * plugins = [[mqttArray objectAtIndex:0] objectForKey:KEY_PLUGINS];
    for (int i=0; i<[array count]; i++) {
        NSDictionary *settingElement = [array objectAtIndex:i];
        NSString *setting = [settingElement objectForKey:@"setting"];
        NSString *value = [settingElement objectForKey:@"value"];
        if([setting isEqualToString:@"mqtt_password"]){
            mqttPassword = value;
        }else if([setting isEqualToString:@"mqtt_username"]){
            mqttUsername = value;
        }else if([setting isEqualToString:@"mqtt_server"]){
            mqttServer = value;
        }else if([setting isEqualToString:@"mqtt_server"]){
            mqttServer = value;
        }else if([setting isEqualToString:@"mqtt_port"]){
            mqttPort = [value intValue];
        }else if([setting isEqualToString:@"mqtt_keep_alive"]){
            mqttKeepAlive = [value intValue];
        }else if([setting isEqualToString:@"mqtt_qos"]){
            mqttQos = [value intValue];
        }else if([setting isEqualToString:@"study_id"]){
            studyId = value;
        }else if([setting isEqualToString:@"webservice_server"]){
            webserviceServer = value;
        }else if([setting isEqualToString:@"frequency_webservice"]){
            frequencySyncDB = [value intValue];
        }else if([setting isEqualToString:@"frequency_clean_old_data"]){
            // (0 = never, 1 = weekly, 2 = monthly, 3 = daily, 4 = always)
            frequencyCleanOldData = [value integerValue];
        }else if([setting isEqualToString:@"webservice_wifi_only"]){
            webserviceWifiOnly = [value boolValue];
        }
    }
    
    NSString * oldStudyId = [userDefaults objectForKey:KEY_STUDY_ID];
    if(![oldStudyId isEqualToString:studyId]){
        NSLog(@"Add new device ID to the AWARE server.");
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString* url =  [userDefaults objectForKey:KEY_STUDY_QR_CODE];
        NSString * uuid = [AWAREUtils getSystemUUID];
        [self addNewDeviceToAwareServer:url withDeviceId:uuid];
    }else{
        NSLog(@"This device ID is already regited to the AWARE server.");
    }
    
    // save the new configuration to the local storage
    [userDefaults setObject:mqttServer forKey:KEY_MQTT_SERVER];
    [userDefaults setObject:mqttPassword forKey:KEY_MQTT_PASS];
    [userDefaults setObject:mqttUsername forKey:KEY_MQTT_USERNAME];
    [userDefaults setObject:[NSNumber numberWithInt:mqttPort] forKey:KEY_MQTT_PORT];
    [userDefaults setObject:[NSNumber numberWithInt:mqttKeepAlive] forKey:KEY_MQTT_KEEP_ALIVE];
    [userDefaults setObject:[NSNumber numberWithInt:mqttQos] forKey:KEY_MQTT_QOS];
    [userDefaults setObject:studyId forKey:KEY_STUDY_ID];
    [userDefaults setObject:webserviceServer forKey:KEY_WEBSERVICE_SERVER];
    [userDefaults setObject:array forKey:KEY_SENSORS];
    [userDefaults setObject:plugins forKey:KEY_PLUGINS];
    [userDefaults setDouble:frequencySyncDB*60 forKey:SETTING_SYNC_INT]; // save data as second
    [userDefaults setBool:webserviceWifiOnly forKey:SETTING_SYNC_WIFI_ONLY];
    [userDefaults setInteger:frequencyCleanOldData forKey:SETTING_FREQUENCY_CLEAN_OLD_DATA];
    [userDefaults synchronize];

    
    // run in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *delegate=(AppDelegate*)[UIApplication sharedApplication].delegate;
        AWARECore * core = delegate.sharedAWARECore;
        [core.sharedSensorManager stopAndRemoveAllSensors];
        [core.sharedSensorManager startAllSensorsWithStudy:self];
        [core.sharedSensorManager createAllTables];
    });
    
    readingState = YES;
}



/**
 * This method sets downloaded study configurations.
 *
 * @param resData A response (study configurations) from the aware server
 */
- (bool) addNewDeviceToAwareServer:(NSString *)url withDeviceId:(NSString *) uuid {
    NSLog(@"Create an aware_device table on the aware server");
    [self createTable:url withDeviceId:uuid];
    
    // preparing for insert device information
    url = [NSString stringWithFormat:@"%@/aware_device/insert", url];
    NSNumber * unixtime = [AWAREUtils getUnixTimestamp:[NSDate new]];
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString* machine =  [NSString stringWithCString:systemInfo.machine  encoding:NSUTF8StringEncoding]; // ok
    NSString* nodeName = [NSString stringWithCString:systemInfo.nodename encoding:NSUTF8StringEncoding]; // ok
    NSString* release =  [NSString stringWithCString:systemInfo.release  encoding:NSUTF8StringEncoding]; // ok
    NSString* systemName = [NSString stringWithCString:systemInfo.sysname encoding:NSUTF8StringEncoding];// ok
    NSString* version = [NSString stringWithCString:systemInfo.version encoding:NSUTF8StringEncoding];
    NSString *name = [self getDeviceName]; //[[UIDevice currentDevice] name];//ok
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];//ok
    NSString *localizeModel = [[UIDevice currentDevice] localizedModel];//
    NSString *model = [[UIDevice currentDevice] model]; //ok
    NSString *manufacturer = @"Apple";//ok
    
    
    //    [[UIDevice currentDevice] platformType]   // ex: UIDevice4GiPhone
    //    [[UIDevice currentDevice] platformString] // ex: @"iPhone 4G"
//    @property(nonatomic,readonly,strong) NSString    *name;              // e.g. "My iPhone"
//    @property(nonatomic,readonly,strong) NSString    *model;             // e.g. @"iPhone", @"iPod touch"
//    @property(nonatomic,readonly,strong) NSString    *localizedModel;    // localized version of model
//    @property(nonatomic,readonly,strong) NSString    *systemName;        // e.g. @"iOS"
//    @property(nonatomic,readonly,strong) NSString    *systemVersion;     // e.g. @"4.0"
    
    NSMutableDictionary *jsonQuery = [[NSMutableDictionary alloc] init];
    [jsonQuery setValue:uuid            forKey:@"device_id"];
    [jsonQuery setValue:unixtime        forKey:@"timestamp"];
    [jsonQuery setValue:manufacturer    forKey:@"board"];
    [jsonQuery setValue:model           forKey:@"brand"];
    [jsonQuery setValue:[AWAREUtils deviceName] forKey:@"device"];
    [jsonQuery setValue:version         forKey:@"build_id"];
    [jsonQuery setValue:machine         forKey:@"hardware"];
    [jsonQuery setValue:manufacturer    forKey:@"manufacturer"];
    [jsonQuery setValue:model           forKey:@"model"];
    [jsonQuery setValue:[AWAREUtils deviceName]    forKey:@"product"];
    [jsonQuery setValue:version         forKey:@"serial"];
    [jsonQuery setValue:release         forKey:@"release"];
    [jsonQuery setValue:localizeModel        forKey:@"release_type"];
    [jsonQuery setValue:systemVersion   forKey:@"sdk"];
    [jsonQuery setValue:name            forKey:@"label"];
    
    NSMutableArray *a = [[NSMutableArray alloc] init];
    [a addObject:jsonQuery];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:a
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    NSString *jsonString = @"";
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"%@",jsonString);
    }
    NSString *post = [NSString stringWithFormat:@"data=%@&device_id=%@", jsonString,uuid];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    //[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    // NSURLConnection * connection = [NSURLConnection connectionWithRequest:request delegate:self];
    // [connection start];
    
    // NSURLSessionConfiguration *sessionConfig = nil;
    // _getSettingIdentifier = [NSString stringWithFormat:@"%@%@", _getSettingIdentifier, unixtime];
    url = [NSString stringWithFormat:@"%@?%@", url, unixtime];
    

    NSURL * urlObj = [NSURL URLWithString:url];
    if(urlObj == nil){
        return NO;
    }
    [request setURL:urlObj];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:postData];
    
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSession sharedSession].configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    [[session dataTaskWithRequest: request  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil) {
            NSLog(@"Error: %@", error.debugDescription);
        }
        if( data != nil ){
            NSLog(@"Success: %@", [[NSString alloc] initWithData: data  encoding: NSUTF8StringEncoding]);
        }
        [session finishTasksAndInvalidate];
        [session invalidateAndCancel];
        
    }] resume];
    
     return true;
}



/**
 * Create an aware_device table with an url and an uuid
 * @param url An url for create aware_device table on aware database
 * @param uuid An uuid for create aware_device table on aware database
 * @return A result of creating a table of the aware_deivce table
 */
- (bool) createTable:(NSString *)url withDeviceId:(NSString *) uuid{
        // preparing for insert device information
        url = [NSString stringWithFormat:@"%@/aware_device/create_table", url];
    NSString *query = [[NSString alloc] init];
    query = @"_id integer primary key autoincrement,"
    "timestamp real default 0,"
    "device_id text default '',"
    
    "board text default '',"
    "brand text default '',"
    "device text default '',"
    "build_id text default '',"
    "hardware text default '',"
    "manufacturer text default '',"
    "model text default '',"
    "product text default '',"
    "serial text default '',"
    "release text default '',"
    "release_type text default '',"
    "sdk test default ''," // version
    "label text default '',"
    "UNIQUE (device_id)";
  
    NSString *post = [NSString stringWithFormat:@"device_id=%@&fields=%@", uuid, query];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];

    NSNumber * unixtime = [AWAREUtils getUnixTimestamp:[NSDate new]];
    url = [NSString stringWithFormat:@"%@?%@", url, unixtime];
    
    NSURL * urlObj = [NSURL URLWithString:url];
    if(urlObj == nil){
        return NO;
    }
    [request setURL:urlObj];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:postData];
    
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSession sharedSession].configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    [[session dataTaskWithRequest: request  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        // Success
        if (error != nil) {
            NSLog(@"Error: %@", error.debugDescription);
        }
        if( data != nil ){
            NSLog(@"Success: %@", [[NSString alloc] initWithData: data  encoding: NSUTF8StringEncoding]);
        }
        [session finishTasksAndInvalidate];
        [session invalidateAndCancel];
    }] resume];
    
    // NSURLConnection * connection = [NSURLConnection connectionWithRequest:request delegate:self];
    // [connection start];
    
    return YES;
    
    /*
    // NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    // NSError *error = nil;
    // NSHTTPURLResponse *response = nil;
    
    NSData *resData = [NSURLConnection sendSynchronousRequest:request
                                            returningResponse:&response error:&error];
    NSString * resultDate = [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
    NSLog(@"==> %@", resultDate);
    int responseCode = (int)[response statusCode];
    if(responseCode == 200){
        NSLog(@"UPLOADED SENSOR DATA TO A SERVER");
        return YES;
    }else{
        NSLog(@"ERROR");
        return NO;
    }
    return NO;
     */
}


/**
 * Refresh a study configuration. When the method is called, the method access to 
 * the aware sernver and download configurations from the server by using -setStudyInformationWithURL.
 * If this device does not join a study, this method can not refresh the study 
 * and return a NO (false) as a BOOL value.
 *
 * NOTE: The response of this method is not synchronized in the background!!
 *
 * @return a refresh query is sent(YES) or not sent(NO) as a BOOL value
 */
- (BOOL) refreshStudy {
//    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
//    NSString *url = [userDefaults objectForKey:KEY_STUDY_QR_CODE];
    NSString * url = [self getStudyURL];
    if (url != nil) {
        [self setStudyInformationWithURL:url];
        return YES;
    }
    return NO;
}

//- (BOOL)refreshStudyWithSensorManager:(AWARESensorManager *)manager{
//    sensorManager = manager;
//    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
//    NSString *url = [userDefaults objectForKey:KEY_STUDY_QR_CODE];
//    if (url != nil) {
//        [self setStudyInformationWithURL:url];
//        return YES;
//    }
//    return NO;
//}


///////////////////////////////////////////////////////////////////////
// Getter
////////////////////////////////////////////////////////////////////////

- (void) setDeviceName:(NSString *) deviceName {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:deviceName forKey:KEY_AWARE_DEVICE_NAME];
    [userDefaults synchronize];
}

- (void) setStudyURL:(NSString *) studyURL {
    if( studyURL != nil ){
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:studyURL forKey:KEY_STUDY_QR_CODE];
        [userDefaults synchronize];
    }
}

- (NSString *) getDeviceName {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *name = [[UIDevice currentDevice] name];
    if ([userDefaults objectForKey:KEY_AWARE_DEVICE_NAME] != nil) {
        name = [userDefaults objectForKey:KEY_AWARE_DEVICE_NAME];
    }
    return name;
}

/**
 * Get a device id from a local storage.
 * @return a device id of this device
 */
- (NSString *)getDeviceId {
    if ([mqttUsername isEqualToString:@""] || mqttUsername == nil) {
        return [AWAREUtils getSystemUUID];
    }
    return mqttUsername;
}

///  MQTT Information ///
/**
 * Get an address of MQTT server (e.g,. "api.awareframework.com")
 * @return an address of mqtt server
 */
- (NSString* ) getMqttServer {
    return mqttServer;
}


/**
 * Get an user name of MQTT. Actually, this value is same as a 
 * device_id(c09e93dc-5067-4f9b-b639-9cbc232eb6f8) of this device.
 *
 * @return a device_id of this device
 */
- (NSString* ) getMqttUserName{ return mqttUsername; }


/**
 * Get a password of MQTT server
 * @return a password of MQTT server as a NSString value
 */
- (NSString* ) getMqttPassowrd{ return mqttPassword; }


/**
 * Get a port of MQTT server
 * @return a port of MQTT server a NSNumber
 */
- (NSNumber* ) getMqttPort{ return [NSNumber numberWithInt:mqttPort]; }


/**
 * Get a time of MQTT Keep Alive
 * @return a time of MQTT Keep Alive as NSNumber
 */
- (NSNumber* ) getMqttKeepAlive{ return [NSNumber numberWithInt:mqttKeepAlive]; }


/**
 * Get a MQTT QOS as NSNumber
 * @return a value of MQTT QOS
 */
- (NSNumber* ) getMqttQos{ return [NSNumber numberWithInt:mqttQos]; }


/**
 * Get a study_id (e.g., 24)
 * @return a study id
 */
- (NSString* ) getStudyId{ return studyId; }


/**
 * Get an aware server name (e.g., api.awareframework.com )
 * @return an name of an aware server
 */
- (NSString* ) getWebserviceServer{ return webserviceServer; }


- (NSString *)getStudyURL{
    //objectForKey:KEY_STUDY_QR_CODE
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString * studyURL = [userDefaults objectForKey:KEY_STUDY_QR_CODE];
    if(studyURL != nil){
        return studyURL;
    }else{
        return @"";
    }
}

/**
 * Get sensor settings from a local storage as a NSArray object
 * @return a sensor settings as a NSArray object
 */
- (NSArray *) getSensors {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults objectForKey:KEY_SENSORS];
}

/**
 * Get plugin settings from a local storage as a NSArray object
 * @return a plugin settings as a NSArray object
 */
- (NSArray *) getPlugins{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults objectForKey:KEY_PLUGINS];
}

/**
 * Get a study configuration as text
 * @return a study configuration as a NSString
 */
- (NSString *) getStudyConfigurationAsText {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString * studyConfigurationText = @"";
    studyConfigurationText = [userDefaults objectForKey:@"key_aware_study_configuration_json_text"];
    if (studyConfigurationText == nil) {
        studyConfigurationText = @"";
    }
    return studyConfigurationText;
}


/**
 * Set a study configuration as text
 */
- (void) setStudyConfiguration:(NSString* ) configuration {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if(configuration !=nil){
        [userDefaults setObject:configuration forKey:@"key_aware_study_configuration_json_text"];
    }
}


/**
 * Clean all AWARE study configuration from a local storage (NSUserDefaults)
 * @return a result of a cleaning operation
 */
- (BOOL) clearAllSetting {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:KEY_MQTT_SERVER];
    [userDefaults removeObjectForKey:KEY_MQTT_USERNAME];
    [userDefaults removeObjectForKey:KEY_MQTT_PASS];
    [userDefaults removeObjectForKey:KEY_MQTT_PORT];
    [userDefaults removeObjectForKey:KEY_MQTT_KEEP_ALIVE];
    [userDefaults removeObjectForKey:KEY_MQTT_QOS];
    [userDefaults removeObjectForKey:KEY_STUDY_ID];
    [userDefaults removeObjectForKey:KEY_WEBSERVICE_SERVER];
    [userDefaults removeObjectForKey:KEY_SENSORS];
    [userDefaults removeObjectForKey:KEY_PLUGINS];
    [userDefaults removeObjectForKey:KEY_STUDY_QR_CODE];
    [userDefaults removeObjectForKey:@"key_aware_study_configuration_json_text"];
    [userDefaults synchronize];
    mqttPassword = @"";
    mqttUsername = @"";
    studyId = @"";
    mqttServer = @"";
    webserviceServer = @"";
    mqttPort = 1883;
    mqttKeepAlive = 600;
    mqttQos = 2;
    
    
    
    
    return YES;
}


- (void) refreshAllSetting{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    mqttServer = [userDefaults objectForKey:KEY_MQTT_SERVER];
    mqttUsername = [userDefaults objectForKey:KEY_MQTT_USERNAME];
    mqttPassword =  [userDefaults objectForKey:KEY_MQTT_PASS];
    mqttPort =  [[userDefaults objectForKey:KEY_MQTT_PORT] intValue];
    mqttKeepAlive = [[userDefaults objectForKey:KEY_MQTT_KEEP_ALIVE] intValue];
    mqttQos = [[userDefaults objectForKey:KEY_MQTT_QOS] intValue];
    studyId = [userDefaults objectForKey:KEY_STUDY_ID];
    webserviceServer = [userDefaults objectForKey:KEY_WEBSERVICE_SERVER];
}

/**
 * Get a Wi-Fi network reachable as a boolean
 * @return a Wi-Fi network reachable as a boolean
 */
- (bool) isWifiReachable { return wifiReachable; }


/**
 * Get a network condition as text
 * @return a network reachability as a text
 */
- (NSString *) getNetworkReachabilityAsText{
    NSString * reachabilityText = @"";
    switch (networkState){
        case SCNetworkStatusReachableViaWiFi:
            reachabilityText = @"wifi";
            break;
        case SCNetworkStatusReachableViaCellular:
            reachabilityText = @"cellular";
            break;
        case SCNetworkStatusNotReachable:
            reachabilityText = @"no";
            break;
        default:
            reachabilityText = @"unknown";
            break;
    }
    return reachabilityText;
}

- (NSInteger)getMaxFetchSize{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger fetchSize = [userDefaults integerForKey:KEY_MAX_FETCH_SIZE_NORMAL_SENSOR];
    if (fetchSize < 0){
        fetchSize = 10000;
        [userDefaults setInteger:fetchSize forKey:KEY_MAX_FETCH_SIZE_NORMAL_SENSOR];
    }
    return fetchSize;
}


///////////////////////////////////////
// Checker
///////////////////////////////////////


- (BOOL) isFirstAccess:(NSString*) url withDeviceId:(NSString *) uuid {
    // check latest record
    // https://api.awareframework.com/index.php/webservice/index/STUDYID/APIKEY/accelerometer/latest
    NSString * latestDataURL = [NSString stringWithFormat:@"%@/aware_device/latest", url];
    NSLog(@"%@", latestDataURL);
    
    NSString *post = [NSString stringWithFormat:@"device_id=%@", uuid];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:latestDataURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    //[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    NSData *resData = [NSURLConnection sendSynchronousRequest:request
                                            returningResponse:&response error:&error];
    int responseCode = (int)[response statusCode];
    if(responseCode == 200){
        NSString* resultString = [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
        //        NSLog(@"UPLOADED SENSOR DATA TO A SERVER");
        NSLog(@"Result: %@", resultString);
        if ([resultString isEqualToString:@"[]"]) {
            return YES;
        }
        return NO;
    }else{
        NSLog(@"ERROR");
        return NO;
    }
}


- (BOOL) isAvailable {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * sensors = [userDefaults objectForKey:KEY_SENSORS];
    if(sensors){
        return YES;
    }else{
        return NO;
    }
}

- (NSString *) removeStudyStartTimeFromConfig:(NSString*) configStr {
    if (configStr == nil) return @"";
    NSError *error = nil;
    NSString* pattern = @"(\\{\"setting\":\"study_start\",\"value\":\"\\d{4,}\"\\},)";
//    NSString* pattern = @"setting";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (error == nil){
        NSArray *matches = [regex matchesInString:configStr options:0 range:NSMakeRange(0, configStr.length)];
        for (NSTextCheckingResult *match in matches){
            NSMutableString* str = [[NSMutableString alloc] initWithString:configStr];
            [str deleteCharactersInRange:match.range];
            configStr = str;
        }
    }
    return configStr;
}

- (cleanOldDataType) getCleanOldDataType{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults integerForKey:SETTING_FREQUENCY_CLEAN_OLD_DATA];
}


//////////////////////////////////////////////////////
-  (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                              NSURLCredential * _Nullable credential)) completionHandler{
    // http://stackoverflow.com/questions/19507207/how-do-i-accept-a-self-signed-ssl-certificate-using-ios-7s-nsurlsession-and-its
    
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        
        NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
        SecTrustRef trust = [protectionSpace serverTrust];
        NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
        
        // NSArray *certs = [[NSArray alloc] initWithObjects:(id)[[self class] sslCertificate], nil];
        // int err = SecTrustSetAnchorCertificates(trust, (CFArrayRef)certs);
        // SecTrustResultType trustResult = 0;
        // if (err == noErr) {
        //    err = SecTrustEvaluate(trust, &trustResult);
        // }
        
        // if ([challenge.protectionSpace.host isEqualToString:@"aware.ht.sfc.keio.ac.jp"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else if ([challenge.protectionSpace.host isEqualToString:@"r2d2.hcii.cs.cmu.edu"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else if ([challenge.protectionSpace.host isEqualToString:@"api.awareframework.com"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // }
        
        completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
    }
}

//////////////////////////////////////////////////////////


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    
    if(response != nil){
        NSLog(@"%@", response.debugDescription);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    
    if(data != nil){
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] );
    }
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    if(error != nil){
        NSLog(@"%@", error.debugDescription);
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    //if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    //    if ([trustedHosts containsObject:challenge.protectionSpace.host])
    //        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}


@end
