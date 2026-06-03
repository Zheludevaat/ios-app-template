#import "AppDelegate.h"
#import "RootViewController.h"
#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Enable background audio for TTS playback
    NSError *audioError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];
    if (audioError) {
        NSLog(@"Audio session error: %@", audioError);
    }
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[RootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
