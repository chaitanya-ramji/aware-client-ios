//
//  linearAccelerometer.m
//  AWARE
//
//  Created by Yuuki Nishiyama on 11/21/15.
//  Copyright © 2015 Yuuki NISHIYAMA. All rights reserved.
//


/**
 * [CoreMotion API]
 * https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/motion_event_basics/motion_event_basics.html
 *
 * [CMDeviceMotion API]
 * https://developer.apple.com/library/ios/documentation/CoreMotion/Reference/CMDeviceMotion_Class/index.html#//apple_ref/occ/cl/CMDeviceMotion
 */


#import "LinearAccelerometer.h"

@implementation LinearAccelerometer {
    CMMotionManager* motionManager;
    NSTimer * uploadTimer;
}


- (instancetype)initWithSensorName:(NSString *)sensorName{
    self = [super initWithSensorName:sensorName];
    if (self) {
        [super setSensorName:sensorName];
        motionManager = [[CMMotionManager alloc] init];
    }
    return self;
}

- (void) createTable{
    NSString *query = [[NSString alloc] init];
    query = @"_id integer primary key autoincrement,"
    "timestamp real default 0,"
    "device_id text default '',"
    "double_values_0 real default 0,"
    "double_values_1 real default 0,"
    "double_values_2 real default 0,"
    "accuracy integer default 0,"
    "label text default '',"
    "UNIQUE (timestamp,device_id)";
    [super createTable:query];
}


//- (BOOL)startSensor:(double)interval withUploadInterval:(double)upInterval{
- (BOOL)startSensor:(double)upInterval withSettings:(NSArray *)settings{
    NSLog(@"[%@] Create Table", [self getSensorName]);
    [self createTable];
    
    NSLog(@"[%@] Start Linear Acc Sensor", [self getSensorName]);
    double interval = 0.1f;
    [self startWriteAbleTimer];
    
    double frequency = [self getSensorSetting:settings withKey:@"frequency_linear_accelerometer"];
    if(frequency != -1){
        NSLog(@"Linear Accelerometer's frequency is %f !!", frequency);
        double iOSfrequency = [self convertMotionSensorFrequecyFromAndroid:frequency];
        interval = iOSfrequency;
    }
    
    uploadTimer = [NSTimer scheduledTimerWithTimeInterval:upInterval target:self selector:@selector(syncAwareDB) userInfo:nil repeats:YES];
    /** motion */
    if( motionManager.deviceMotionAvailable ){
        motionManager.deviceMotionUpdateInterval = interval;
        [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue new]
                                           withHandler:^(CMDeviceMotion *motion, NSError *error){
                                               // Save sensor data to the local database.
                                               NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
                                               NSNumber* unixtime = [NSNumber numberWithDouble:timeStamp];
                                               NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
                                               [dic setObject:unixtime forKey:@"timestamp"];
                                               [dic setObject:[self getDeviceId] forKey:@"device_id"];
                                               [dic setObject:[NSNumber numberWithDouble:motion.userAcceleration.x] forKey:@"double_values_0"]; //double
                                               [dic setObject:[NSNumber numberWithDouble:motion.userAcceleration.y]  forKey:@"double_values_1"]; //double
                                               [dic setObject:[NSNumber numberWithDouble:motion.userAcceleration.z]  forKey:@"double_values_2"]; //double
                                               [dic setObject:@0 forKey:@"accuracy"];//int
                                               [dic setObject:@"" forKey:@"label"]; //text
                                               [self setLatestValue:[NSString stringWithFormat:@"%f, %f, %f",motion.userAcceleration.x, motion.userAcceleration.y,motion.userAcceleration.z]];
                                               [self saveData:dic toLocalFile:SENSOR_LINEAR_ACCELEROMETER];
                                           }];
    }
    return YES;
}



//    deviceMotion.magneticField.field.x; done
//    deviceMotion.magneticField.field.y; done
//    deviceMotion.magneticField.field.z; done
//    deviceMotion.magneticField.accuracy;

//    deviceMotion.gravity.x;
//    deviceMotion.gravity.y;
//    deviceMotion.gravity.z;
//    deviceMotion.attitude.pitch;
//    deviceMotion.attitude.roll;
//    deviceMotion.attitude.yaw;
//    deviceMotion.rotationRate.x;
//    deviceMotion.rotationRate.y;
//    deviceMotion.rotationRate.z;

//    deviceMotion.timestamp;
//    deviceMotion.userAcceleration.x;
//    deviceMotion.userAcceleration.y;
//    deviceMotion.userAcceleration.z;


- (BOOL)stopSensor{
    [uploadTimer invalidate];
    [motionManager stopDeviceMotionUpdates];
    [self stopWriteableTimer];
    return YES;
}

//- (void)uploadSensorData{
//    [self syncAwareDB];
////    NSString * jsonStr = [self getData:SENSOR_LINEAR_ACCELEROMETER withJsonArrayFormat:YES];
////    [self insertSensorData:jsonStr withDeviceId:[self getDeviceId] url:[self getInsertUrl:SENSOR_LINEAR_ACCELEROMETER]];
//}


@end
