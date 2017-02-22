/*
 * Copyright 2010-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "AppDelegate.h"
#import "ViewController.h"

#import <AWSSNS/AWSSNS.h>
#import <AWSMobileAnalytics/AWSMobileAnalytics.h>

// Identity Pool Id
#define Cognito_Identity_Pool_Id @"ap-northeast-1:769db12c-5ce1-4f36-9ffb-530274c1891a"

// Application ARN (Development, Product)
//#define SNS_Platform_Application_Arn @"arn:aws:sns:ap-northeast-1:xxxxxxxxxxxx:app/APNS_SANDBOX/[Application Name]"
#define SNS_Platform_Application_Arn @"arn:aws:sns:ap-northeast-1:898158812957:app/APNS/ios_weather_warinig"

// Topic ARN
#define SNS_Topic_Arn @"arn:aws:sns:ap-northeast-1:898158812957:kanazawaCity"

//static NSString *const SNSPlatformApplicationArn = @"YourSNSPlatformApplicationArn";


@interface AppDelegate ()

@end

@implementation AppDelegate

AWSRegionType const Cognito_Region_Type = AWSRegionAPNortheast1;
AWSRegionType const Default_Service_Region_Type = AWSRegionAPNortheast1;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Configures the appearance
    [UINavigationBar appearance].barTintColor = [UIColor blackColor];
    [UINavigationBar appearance].titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;

    // Sets up Mobile Push Notification
    UIMutableUserNotificationAction *readAction = [UIMutableUserNotificationAction new];
    readAction.identifier = @"READ_IDENTIFIER";
    readAction.title = @"Read";
    readAction.activationMode = UIUserNotificationActivationModeForeground;
    readAction.destructive = NO;
    readAction.authenticationRequired = YES;

    UIMutableUserNotificationAction *deleteAction = [UIMutableUserNotificationAction new];
    deleteAction.identifier = @"DELETE_IDENTIFIER";
    deleteAction.title = @"Delete";
    deleteAction.activationMode = UIUserNotificationActivationModeForeground;
    deleteAction.destructive = YES;
    deleteAction.authenticationRequired = YES;

    UIMutableUserNotificationAction *ignoreAction = [UIMutableUserNotificationAction new];
    ignoreAction.identifier = @"IGNORE_IDENTIFIER";
    ignoreAction.title = @"Ignore";
    ignoreAction.activationMode = UIUserNotificationActivationModeForeground;
    ignoreAction.destructive = NO;
    ignoreAction.authenticationRequired = NO;

    UIMutableUserNotificationCategory *messageCategory = [UIMutableUserNotificationCategory new];
    messageCategory.identifier = @"MESSAGE_CATEGORY";
    [messageCategory setActions:@[readAction, deleteAction] forContext:UIUserNotificationActionContextMinimal];
    [messageCategory setActions:@[readAction, deleteAction, ignoreAction] forContext:UIUserNotificationActionContextDefault];

// プッシュ通知の有効／無効設定
//    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
//    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:[NSSet setWithArray:@[messageCategory]]];
//
//    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
//    [[UIApplication sharedApplication] registerForRemoteNotifications];

    [self registRemoteNotification:YES];

    return YES;
}

// プッシュ通知の有効／無効設定
- (void)registRemoteNotification:(BOOL)isRegist
{
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    if (isRegist) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // デバイストークンの取得
    NSString *deviceTokenString = [[[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    [self initAWSCognito];
    
    [self initAWSSns:deviceTokenString];

//    NSString *deviceTokenString = [[[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];
//
    NSLog(@"deviceTokenString: %@", deviceTokenString);
    [[NSUserDefaults standardUserDefaults] setObject:deviceTokenString forKey:@"deviceToken"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.window.rootViewController.childViewControllers.firstObject performSelectorOnMainThread:@selector(displayDeviceInfo) withObject:nil waitUntilDone:NO];
//
//    
//    AWSSNS *sns = [AWSSNS defaultSNS];
//    AWSSNSCreatePlatformEndpointInput *request = [AWSSNSCreatePlatformEndpointInput new];
//    request.token = deviceTokenString;
//    request.platformApplicationArn = SNSPlatformApplicationArn;
//    [[sns createPlatformEndpoint:request] continueWithBlock:^id(AWSTask *task) {
//        if (task.error != nil) {
//            NSLog(@"Error: %@",task.error);
//        } else {
//            AWSSNSCreateEndpointResponse *createEndPointResponse = task.result;
//            NSLog(@"endpointArn: %@",createEndPointResponse);
//            [[NSUserDefaults standardUserDefaults] setObject:createEndPointResponse.endpointArn forKey:@"endpointArn"];
//            [[NSUserDefaults standardUserDefaults] synchronize];
//            [self.window.rootViewController.childViewControllers.firstObject performSelectorOnMainThread:@selector(displayDeviceInfo) withObject:nil waitUntilDone:NO];
//
//        }
//
//        return nil;
//    }];
}

// Amazon Cognito credentials provider の初期化
- (void)initAWSCognito
{
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc] initWithRegionType:Cognito_Region_Type
                                                                                                    identityPoolId:Cognito_Identity_Pool_Id];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:Default_Service_Region_Type credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
}

- (void)initAWSSns:(NSString *)deviceTokenString
{
    AWSSNS *sns = [AWSSNS defaultSNS];
    // エンドポイントの登録
    AWSSNSCreatePlatformEndpointInput *endpointInput = [AWSSNSCreatePlatformEndpointInput new];
    endpointInput.token = deviceTokenString;
    endpointInput.platformApplicationArn = SNS_Platform_Application_Arn;
    endpointInput.customUserData = @"任意の文字列";
    [[sns createPlatformEndpoint:endpointInput] continueWithBlock:^id(AWSTask *task) {
        if (task.error != nil) {
            NSLog(@"task.error: %@", task.error);
        } else {
            AWSSNSCreateEndpointResponse *endPointResponse = task.result;
            // トピックへの登録
            AWSSNSSubscribeInput *subscribeInput = [AWSSNSSubscribeInput new];
            subscribeInput.topicArn = SNS_Topic_Arn;
            subscribeInput.protocols = @"application";
            subscribeInput.endpoint = endPointResponse.endpointArn;
            [[sns subscribe:subscribeInput] continueWithBlock:^id(AWSTask *task2) {
                NSLog(@"task2.error: %@", task2.error);
                return nil;
            }];
            //トピックの表示
            NSLog(@"endpointArn: %@",endPointResponse);
            [[NSUserDefaults standardUserDefaults] setObject:endPointResponse.endpointArn forKey:@"endpointArn"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.window.rootViewController.childViewControllers.firstObject performSelectorOnMainThread:@selector(displayDeviceInfo) withObject:nil waitUntilDone:NO];
        }
        return nil;
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Failed to register with error: %@",error);
}

//Push通知された場合の処理
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    if (application.applicationState == UIApplicationStateActive) {
        NSLog(@"Foreground");
    } else if (application.applicationState == UIApplicationStateInactive) {
        NSLog(@"Background");
    }
    NSString *notification = [NSString stringWithFormat:@"userInfo: %@",userInfo];
    NSLog(@"%@", notification);
    [[NSUserDefaults standardUserDefaults] setObject:notification forKey:@"notification"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.window.rootViewController.childViewControllers.firstObject performSelectorOnMainThread:@selector(displayPushNotification) withObject:nil waitUntilDone:NO];

}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
    
    AWSMobileAnalytics *mobileAnalytics = [AWSMobileAnalytics defaultMobileAnalytics];
    id<AWSMobileAnalyticsEventClient> eventClient = mobileAnalytics.eventClient;
    id<AWSMobileAnalyticsEvent> pushNotificationEvent = [eventClient createEventWithEventType:@"PushNotificationEvent"];

    NSString *action = @"Undefined";
    if ([identifier isEqualToString:@"READ_IDENTIFIER"]) {
        action = @"read";
        NSLog(@"User selected 'Read'");
    } else if ([identifier isEqualToString:@"DELETE_IDENTIFIER"]) {
        action = @"Deleted";
        NSLog(@"User selected `Delete`");
    } else {
        action = @"Undefined";
    }

    [pushNotificationEvent addAttribute:action forKey:@"Action"];
    [eventClient recordEvent:pushNotificationEvent];

    [self.window.rootViewController.childViewControllers.firstObject performSelectorOnMainThread:@selector(displayUserAction:)
                                                                                      withObject:action
                                                                                   waitUntilDone:NO];
    
    completionHandler();
}

@end
