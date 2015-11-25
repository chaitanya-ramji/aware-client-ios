//
//  ViewController.m
//  AWARE
//
//  Created by Yuuki Nishiyama on 11/18/15.
//  Copyright © 2015 Yuuki NISHIYAMA. All rights reserved.
//

#import "ViewController.h"
#import "AWAREStudyManager.h"
#import "GoogleLoginViewController.h"
#import "Accelerometer.h"
#import "SensorDataManager.h"


@interface ViewController (){
    NSString *KEY_CEL_TITLE;
    NSString *KEY_CEL_DESC;
    NSString *KEY_CEL_IMAGE;
    NSString *KEY_CEL_STATE;
    NSString *KEY_CEL_SENSOR_NAME;
    NSString *KEY;
    NSString *mqttServer;
    NSString * oldStudyId;
    NSString *mqttPassword;
    NSString *mqttUserName;
    NSString* studyId;
    NSNumber *mqttPort;
    NSNumber* mqttKeepAlive;
    NSNumber* mqttQos;
    NSTimer* listUpdateTimer;
    double uploadInterval;
//    IBOutlet CLLocationManager *homeLocationManager;
    NSTimer* testTimer;
//    NSFileHandle *fh;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//     testTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(test) userInfo:nil repeats:YES];
    KEY_CEL_TITLE = @"title";
    KEY_CEL_DESC = @"desc";
    KEY_CEL_IMAGE = @"image";
    KEY_CEL_STATE = @"state";
    KEY_CEL_SENSOR_NAME = @"sensorName";
    KEY = @"key";
    
    mqttServer = @"";
    oldStudyId = @"";
    mqttPassword = @"";
    mqttUserName = @"";
    studyId = @"";
    mqttPort = @1883;
    mqttKeepAlive = @600;
    mqttQos = @2;
    
    [self setNaviBarTitle];
    [self initLocationSensor];
    
    _sensorManager = [[AWARESensorManager alloc] init];
    uploadInterval = 30;
    
    [self initList];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.navigationController.navigationBar.delegate = self;
    
    [self connectMqttServer];
    
    listUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self.tableView selector:@selector(reloadData) userInfo:nil repeats:YES];
    
//    _sensorDataManager = [[SensorDataManager alloc] initWithDBPath:@"" userID:@"" ];
    
}

- (void) test {
    NSLog(@"test");
//    [_sensorDataManager addNetwork:@"hogehoge"];
    [_sensorDataManager saveAllSensorDataToDBWithBufferClean:NO];
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    NSString * path = [documentsDirectory stringByAppendingPathComponent:SENSOR_ACCELEROMETER];
//    NSLog(@"Path: %@", path);
//    NSFileManager *manager = [NSFileManager defaultManager];
//    if (![manager fileExistsAtPath:path]) { // yes
//        // 空のファイルを作成する
//        BOOL result = [manager createFileAtPath:path
//                                       contents:[NSData data]
//                                     attributes:nil];
//        if (!result) {
//            NSLog(@"ファイルの作成に失敗");
//            return;
//        }else{
//            NSLog(@"Created a file");
//        }
//    }
//    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
//    if (!fh) {
//        NSLog(@"[test sensor] Not hudled");
//    }else{
//        NSLog(@"[test sensor] Hudled");
//    }
//    [fh synchronizeFile];
//    [fh closeFile];
}




- (void) initLocationSensor{
    if (nil == _homeLocationManager){
        _homeLocationManager = [[CLLocationManager alloc] init];
        _homeLocationManager.delegate = self;
        //    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
        _homeLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _homeLocationManager.pausesLocationUpdatesAutomatically = NO;
        _homeLocationManager.allowsBackgroundLocationUpdates = YES; //This variable is an important method for background sensing
        _homeLocationManager.activityType = CLActivityTypeOther;
        if ([_homeLocationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [_homeLocationManager requestAlwaysAuthorization];
        }
        // Set a movement threshold for new events.
        _homeLocationManager.distanceFilter = 150; // meters
        [_homeLocationManager startUpdatingLocation];
        //    [_locationManager startMonitoringVisits]; // This method calls didVisit.
        [_homeLocationManager startUpdatingHeading];
        //    _location = [[CLLocation alloc] init];
    }
}

- (void) setNaviBarTitle {
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    NSString *email = [defaults objectForKey:@"GOOGLE_EMAIL"];
//    NSString *name = [defaults objectForKey:@"GOOGLE_NAME"];
//    NSLog(@"name:%@", name);
//    if (![name isEqualToString:@""]) {
//        [self.navigationController.navigationBar.topItem setTitle:name];
//    }else{
//        [self.navigationController.navigationBar.topItem setTitle:@"AWARE"];
//    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) initList {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    _sensors = [[NSMutableArray alloc] init];
    // devices
    NSString *deviceId = [userDefaults objectForKey:KEY_MQTT_USERNAME];
    NSString *awareStudyId = [userDefaults objectForKey:KEY_STUDY_ID];
    NSString *mqttServerName = [userDefaults objectForKey:KEY_MQTT_SERVER];
    [userDefaults synchronize];
    NSString *email = [userDefaults objectForKey:@"GOOGLE_EMAIL"];
    NSString *name = [userDefaults objectForKey:@"GOOGLE_NAME"];
    NSString *accountInfo = [NSString stringWithFormat:@"%@ (%@)", name, email];
    if(name == nil) accountInfo = @"";
    if(deviceId == nil) deviceId = @"";
    if(awareStudyId == nil) awareStudyId = @"";
    if(mqttServerName == nil) mqttServerName = @"";
    
    [_sensors addObject:[self getCelContent:@"AWARE Device ID" desc:deviceId image:@"" key:@""]];
    [_sensors addObject:[self getCelContent:@"Google Account" desc:accountInfo image:@"" key:@""]];
    [_sensors addObject:[self getCelContent:@"AWARE Study" desc:awareStudyId image:@"" key:@""]]; //ic_action_study
    [_sensors addObject:[self getCelContent:@"MQTT Server" desc:mqttServerName image:@"" key:@""]]; //ic_action_mqtt
    
    // sensor
    [_sensors addObject:[self getCelContent:@"Sensors" desc:@"" image:@"" key:@""]];
    [_sensors addObject:[self getCelContent:@"Accelerometer" desc:@"Acceleration, including the force of gravity(m/s^2)" image:@"ic_action_accelerometer" key:SENSOR_ACCELEROMETER]];
    [_sensors addObject:[self getCelContent:@"Barometer" desc:@"Atomospheric air pressure (mbar/hPa)" image:@"ic_action_barometer" key:SENSOR_BAROMETER]];
    [_sensors addObject:[self getCelContent:@"Battery" desc:@"Battery and power event" image:@"ic_action_battery" key:SENSOR_BATTERY]];
    [_sensors addObject:[self getCelContent:@"Bluetooth" desc:@"Bluetooth sensing" image:@"ic_action_bluetooth" key:SENSOR_BLUETOOTH]];
    [_sensors addObject:[self getCelContent:@"Gyroscope" desc:@"Rate of rotation of device (rad/s)" image:@"ic_action_gyroscope" key:SENSOR_GYROSCOPE]];
    [_sensors addObject:[self getCelContent:@"Gravity" desc:@"Gravity provides a three dimensional vector indicating the direction and magnitude of gravity (in m/s²)" image:@"ic_action_gravity" key:SENSOR_GRAVITY]];
    [_sensors addObject:[self getCelContent:@"Linear Accelerometer" desc:@"The linear accelerometer measures the acceleration applied to the sensor built-in into the device, excluding the force of gravity, in m/s" image:@"ic_action_linear_acceleration" key:SENSOR_LINEAR_ACCELEROMETER]];
    [_sensors addObject:[self getCelContent:@"Locations" desc:@"User's estimated location by GPS and network triangulation" image:@"ic_action_locations" key:SENSOR_LOCATIONS]];
    [_sensors addObject:[self getCelContent:@"Magnetometer" desc:@"Geomagnetic field strength around the device (uT)" image:@"ic_action_magnetometer" key:SENSOR_MAGNETOMETER]];
    [_sensors addObject:[self getCelContent:@"Mobile ESM/EMA" desc:@"Mobile questionnaries" image:@"ic_action_esm" key:SENSOR_ESMS]];
    [_sensors addObject:[self getCelContent:@"Network" desc:@"Network usage and traffic" image:@"ic_action_network" key:SENSOR_NETWORK]];
//    [_sensors addObject:[self getCelContent:@"Processor" desc:@"CPU workload for user, system and idle(%)" image:@"ic_action_processor" key:SENSOR_PROCESSOR]];
//    [_sensors addObject:[self getCelContent:@"Telephony" desc:@"Mobile operator and specifications, cell tower and neighbor scanning" image:@"ic_action_telephony" key:SENSOR_TELEPHONY]];
    [_sensors addObject:[self getCelContent:@"WiFi" desc:@"Wi-Fi sensing" image:@"ic_action_wifi" key:SENSOR_WIFI]];

    // android specific sensors
    //[_sensors addObject:[self getCelContent:@"Gravity" desc:@"Force of gravity as a 3D vector with direction and magnitude of gravity (m^2)" image:@"ic_action_gravity"]];
    //[_sensors addObject:[self getCelContent:@"Light" desc:@"Ambient Light (lux)" image:@"ic_action_light"]];
    //[_sensors addObject:[self getCelContent:@"Proximity" desc:@"" image:@"ic_action_proximity"]];
    //[_sensors addObject:[self getCelContent:@"Temperature" desc:@"" image:@"ic_action_temperature"]];
    
    // iOS specific sensors
//    [_sensors addObject:[self getCelContent:@"Screen (iOS)" desc:@"Screen events (on/off, locked/unlocked)" image:@"ic_action_screen" key:SENSOR_SCREEN]];
//    [_sensors addObject:[self getCelContent:@"Direction (iOS)" desc:@"Device's direction (0-360)" image:@"safari_copyrighted" key:SENSOR_DIRECTION]];
//    [_sensors addObject:[self getCelContent:@"Rotation (iOS)" desc:@"Orientation of the device" image:@"ic_action_rotation" key:SENSOR_ROTATION]];
}


- (NSMutableDictionary *) getCelContent:(NSString *)title
                                   desc:(NSString *)desc
                                  image:(NSString *)image
                                    key:(NSString *)key{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:title forKey:KEY_CEL_TITLE];
    [dic setObject:desc forKey:KEY_CEL_DESC];
    [dic setObject:image forKey:KEY_CEL_IMAGE];
    [dic setObject:key forKey:KEY_CEL_SENSOR_NAME];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *sensors = [userDefaults objectForKey:KEY_SENSORS];
    // [NOTE] If this sensor is "active", addNewSensorWithSensorName method return TRUE value.
    bool state = [_sensorManager addNewSensorWithSensorName:key settings:sensors uploadInterval:uploadInterval];
    if (state) {
        [dic setObject:@"true" forKey:KEY_CEL_STATE];
    }
    return dic;
}


-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_sensors count];
}



//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return 60;//[AwardTableViewCell rowHeight];
//}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    @autoreleasepool {
        static NSString *MyIdentifier = @"MyReuseIdentifier";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle  reuseIdentifier:MyIdentifier];
        }
        NSDictionary *item = (NSDictionary *)[_sensors objectAtIndex:indexPath.row];
        cell.textLabel.text = [item objectForKey:KEY_CEL_TITLE];
        cell.detailTextLabel.text = [item objectForKey:KEY_CEL_DESC];
//        [cell.detailTextLabel setNumberOfLines:2];
        NSString * imageName = [item objectForKey:KEY_CEL_IMAGE];
        UIImage *theImage= nil;
        if (![imageName isEqualToString:@""]) {
             theImage = [UIImage imageNamed:imageName];
        }
        NSString *stateStr = [item objectForKey:KEY_CEL_STATE];
        cell.imageView.image = theImage;
        
        //update latest sensor data
        NSString *sensorKey = [item objectForKey:KEY_CEL_SENSOR_NAME];
        NSString* latestSensorData = [_sensorManager getLatestSensorData:sensorKey];
        if(![latestSensorData isEqualToString:@""]){
            [cell.detailTextLabel setText:latestSensorData];
        }
    //    NSLog(@"-> %@",latestSensorData);
        
        if ([stateStr isEqualToString:@"true"]) {
            theImage = [theImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            UIImageView *aImageView = [[UIImageView alloc] initWithImage:theImage];
            aImageView.tintColor = UIColor.redColor;
            cell.imageView.image = theImage;
        }
        return cell;
    }
}


-(BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item
{
    NSLog(@"Back button got pressed!");
    [self.navigationController popToRootViewControllerAnimated:YES];
    //update sensor list !
    [_sensorManager stopAllSensors];
    NSLog(@"remove all sensors");
    [self initList];
    [self.tableView reloadData];
    [self connectMqttServer];
    //if you return NO, the back button press is cancelled
    [self setNaviBarTitle];
    return YES;
}

- (bool) connectMqttServer {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    // if Study ID is new, AWARE adds new Device ID to the AWARE server.
    mqttServer = [userDefaults objectForKey:KEY_MQTT_SERVER];
    oldStudyId = [userDefaults objectForKey:KEY_STUDY_ID];
    mqttPassword = [userDefaults objectForKey:KEY_MQTT_PASS];
    mqttUserName = [userDefaults objectForKey:KEY_MQTT_USERNAME];
    mqttPort = [userDefaults objectForKey:KEY_MQTT_PORT];
    mqttKeepAlive = [userDefaults objectForKey:KEY_MQTT_KEEP_ALIVE];
    mqttQos = [userDefaults objectForKey:KEY_MQTT_QOS];
    studyId = [userDefaults objectForKey:KEY_STUDY_ID];
//    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
//    NSNumber* unixtime = [NSNumber numberWithDouble:timeStamp];
    if (mqttPassword == nil) {
        NSLog(@"An AWARE study is not registed! Please read QR code");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"AWARE Study"
                                                        message:@"You have not registed an AWARE study yet. Please read a QR code for AWARE study."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    if ([self.client connected]) {
        [self.client disconnectWithCompletionHandler:^(NSUInteger code) {
            NSLog(@"disconnected!");
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/%@/broadcasts",studyId,mqttUserName] withCompletionHandler:^{
                //
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/%@/esm", studyId,mqttUserName] withCompletionHandler:^{
                //                         NSLog(grantedQos.description);
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/%@/configuration",studyId,mqttUserName]  withCompletionHandler:^ {
                //                         NSLog(grantedQos.description);
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/%@/#",studyId,mqttUserName] withCompletionHandler:^ {
                //                         NSLog(grantedQos.description);
            }];
            
            
            //Device specific subscribes
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/esm", mqttUserName] withCompletionHandler:^{
                //                         NSLog(grantedQos.description);
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/broadcasts", mqttUserName] withCompletionHandler:^{
                //                         NSLog(grantedQos.description);
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/configuration", mqttUserName] withCompletionHandler:^ {
                //                         NSLog(grantedQos.description);
            }];
            [self.client unsubscribe:[NSString stringWithFormat:@"%@/#", mqttUserName] withCompletionHandler:^{
                //                         NSLog(grantedQos.description);
            }];
            //                                 [self uploadSensorData];

        }];
    }
    
    self.client = [[MQTTClient alloc] initWithClientId:mqttUserName cleanSession:YES];
    [self.client setPort:[mqttPort intValue]];
    [self.client setKeepAlive:[mqttKeepAlive intValue]];
    [self.client setPassword:mqttPassword];
    [self.client setUsername:mqttUserName];
    // define the handler that will be called when MQTT messages are received by the client
    [self.client setMessageHandler:^(MQTTMessage *message) {
        NSString *text = message.payloadString;
        NSLog(@"Received messages %@", text);
        NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary * dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        NSArray *array = [dic objectForKey:@"sensors"];
        [userDefaults setObject:array forKey:KEY_SENSORS];
        [userDefaults synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Refreh sensors
            [_sensorManager stopAllSensors];
            [self initList];
            [self.tableView reloadData];
            [self sendLocalNotificationForMessage:@"AWARE study is updated via MQTT." soundFlag:NO];
        });
//        NSLog(@"%@", dic);
    }];
    

    

    [self.client connectToHost:mqttServer
             completionHandler:^(MQTTConnectionReturnCode code) {
                 if (code == ConnectionAccepted) {
                     NSLog(@"Connected to the MQTT server!");
                     // when the client is connected, send a MQTT message
                     //Study specific subscribes
                     [self.client subscribe:[NSString stringWithFormat:@"%@/%@/broadcasts",studyId,mqttUserName] withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/%@/esm", studyId,mqttUserName] withQos:[mqttQos intValue]  completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/%@/configuration",studyId,mqttUserName]  withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/%@/#",studyId,mqttUserName] withQos:[mqttQos intValue]  completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];


                     //Device specific subscribes
                     [self.client subscribe:[NSString stringWithFormat:@"%@/esm", mqttUserName] withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/broadcasts", mqttUserName] withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/configuration", mqttUserName] withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     [self.client subscribe:[NSString stringWithFormat:@"%@/#", mqttUserName] withQos:[mqttQos intValue] completionHandler:^(NSArray *grantedQos) {
//                         NSLog(grantedQos.description);
                     }];
                     //                                 [self uploadSensorData];
                 }
             }];
    return YES;
}


/**
 Local push notification method
 @param message text message for notification
 @param sound type of sound for notification
 */
- (void)sendLocalNotificationForMessage:(NSString *)message soundFlag:(BOOL)soundFlag {
    UILocalNotification *localNotification = [UILocalNotification new];
    localNotification.alertBody = message;
    //    localNotification.fireDate = [NSDate date];
    localNotification.repeatInterval = 0;
    if(soundFlag) {
        localNotification.soundName = UILocalNotificationDefaultSoundName;
    }
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

//- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//    if (newHeading.headingAccuracy < 0)
//        return;
//    //    CLLocationDirection  theHeading = ((newHeading.trueHeading > 0) ?
//    //                                       newHeading.trueHeading : newHeading.magneticHeading);
//    //    [sdManager addSensorDataMagx:newHeading.x magy:newHeading.y magz:newHeading.z];
//    //    [sdManager addHeading: theHeading];
//}

//- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
//    for (CLLocation* location in locations) {
//        [self saveLocation:location];
//    }
//}


@end
