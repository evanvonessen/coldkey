// Native Sparkle integration driver. It only updates the disposable app passed by the test.
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>

@interface UpdateDriver : NSObject <SPUUserDriver, SPUUpdaterDelegate>
@property NSString *mode;
@property NSString *feed;
@end

@implementation UpdateDriver
- (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater { return self.feed; }
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply { abort(); }
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancel {}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    NSCAssert(state.stage == SPUUserUpdateStageNotDownloaded, @"An update downloaded before approval");
    puts("OFFERED_WITHOUT_DOWNLOAD");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if ([self.mode isEqualToString:@"cancel"]) { puts("DECLINED"); reply(SPUUserUpdateChoiceDismiss); }
        else { puts("APPROVED"); reply(SPUUserUpdateChoiceInstall); }
    });
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error { abort(); }
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))ack {
    ack();
    if ([self.mode isEqualToString:@"current"]) { puts("ALREADY_CURRENT"); exit(0); }
    NSLog(@"Unexpected no-update result: %@", error); exit(1);
}
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack {
    NSLog(@"Update error: %@", error);
    ack();
    if ([self.mode hasPrefix:@"invalid"]) { puts("REJECTED_INVALID_UPDATE"); exit(0); }
    exit(1);
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancel { puts("DOWNLOAD_STARTED"); }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { puts("EXTRACTING"); }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { puts("INSTALL_APPROVED"); reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry { puts("INSTALLING"); }
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))ack { puts("INSTALLED"); ack(); exit(0); }
- (void)dismissUpdateInstallation { if ([self.mode isEqualToString:@"cancel"]) { exit(0); } }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        NSCAssert(argc == 4, @"Expected disposable host, feed URL, and mode");
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSBundle *host = [NSBundle bundleWithPath:@(argv[1])];
        NSCAssert([host.bundlePath containsString:@".build/update-validation/"], @"Refusing a non-test target");
        UpdateDriver *driver = [UpdateDriver new];
        driver.feed = @(argv[2]); driver.mode = @(argv[3]);
        SPUUpdater *updater = [[SPUUpdater alloc] initWithHostBundle:host applicationBundle:host userDriver:driver delegate:driver];
        NSCAssert(updater.updateCheckInterval == 86400, @"Expected a daily check interval");
        NSCAssert(!updater.allowsAutomaticUpdates && !updater.automaticallyDownloadsUpdates, @"Automatic installation must be disabled");
        // Exercise Sparkle's real preference persistence in an isolated defaults suite.
        updater.automaticallyChecksForUpdates = NO;
        SPUUpdater *reopened = [[SPUUpdater alloc] initWithHostBundle:host applicationBundle:host userDriver:driver delegate:driver];
        NSCAssert(!reopened.automaticallyChecksForUpdates, @"Disabled checks must survive reopening");
        updater.automaticallyChecksForUpdates = YES;
        NSCAssert(reopened.automaticallyChecksForUpdates, @"Enabled checks must be reflected");
        updater.automaticallyChecksForUpdates = NO;
        NSError *error = nil;
        if (![updater startUpdater:&error]) { NSLog(@"Start failed: %@", error); return 1; }
        [updater checkForUpdates]; // Manual checking must still work with scheduled checks disabled.
        [NSApp run];
        (void)driver; (void)updater;
    }
    return 0;
}
