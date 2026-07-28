#import <UIKit/UIKit.h>

@interface IraqiFlagView : UIView
@end

@implementation IraqiFlagView

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat stripeH = h / 3.0;

    UIColor *red    = [UIColor colorWithRed:0.80 green:0.18 blue:0.16 alpha:1.0];
    UIColor *white  = [UIColor whiteColor];
    UIColor *black  = [UIColor blackColor];
    UIColor *green  = [UIColor colorWithRed:0.00 green:0.56 blue:0.22 alpha:1.0];

    CGContextSetFillColorWithColor(ctx, red.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, w, stripeH));

    CGContextSetFillColorWithColor(ctx, white.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, stripeH, w, stripeH));

    CGContextSetFillColorWithColor(ctx, black.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, stripeH * 2, w, stripeH));

    NSString *takbir = @"\u0627\u0644\u0644\u0647 \u0623\u0643\u0628\u0631";
    UIFont *font = [UIFont boldSystemFontOfSize:stripeH * 0.42];
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: green
    };
    CGSize textSize = [takbir sizeWithAttributes:attrs];
    CGFloat textX = (w - textSize.width) / 2.0;
    CGFloat textY = stripeH + (stripeH - textSize.height) / 2.0;
    [takbir drawAtPoint:CGPointMake(textX, textY) withAttributes:attrs];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor systemBackgroundColor];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [rootVC.view addSubview:scrollView];
    
    CGFloat y = 20;
    CGFloat w = [UIScreen mainScreen].bounds.size.width - 40;
    CGFloat x = 20;
    
    IraqiFlagView *flag = [[IraqiFlagView alloc] initWithFrame:CGRectMake(x, y, w, 80)];
    flag.layer.cornerRadius = 8;
    flag.clipsToBounds = YES;
    [scrollView addSubview:flag];
    y += 100;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 40)];
    title.text = @"AhmedVPN Tether";
    title.font = [UIFont boldSystemFontOfSize:28];
    title.textColor = [UIColor labelColor];
    [scrollView addSubview:title];
    y += 50;
    
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 30)];
    subtitle.text = @"Route hotspot traffic through VPN";
    subtitle.font = [UIFont systemFontOfSize:16];
    subtitle.textColor = [UIColor secondaryLabelColor];
    [scrollView addSubview:subtitle];
    y += 50;
    
    UIView *card1 = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 120)];
    card1.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card1.layer.cornerRadius = 12;
    [scrollView addSubview:card1];
    
    UILabel *statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 24)];
    statusTitle.text = @"STATUS";
    statusTitle.font = [UIFont boldSystemFontOfSize:14];
    statusTitle.textColor = [UIColor secondaryLabelColor];
    [card1 addSubview:statusTitle];
    
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 40, w - 32, 60)];
    statusLabel.numberOfLines = 3;
    statusLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    statusLabel.textColor = [UIColor labelColor];
    statusLabel.tag = 100;
    [card1 addSubview:statusLabel];
    y += 140;
    
    UIView *card2 = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 180)];
    card2.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card2.layer.cornerRadius = 12;
    [scrollView addSubview:card2];
    
    UILabel *licTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 24)];
    licTitle.text = @"LICENSE";
    licTitle.font = [UIFont boldSystemFontOfSize:14];
    licTitle.textColor = [UIColor secondaryLabelColor];
    [card2 addSubview:licTitle];
    
    UITextField *licenseField = [[UITextField alloc] initWithFrame:CGRectMake(16, 44, w - 32, 44)];
    licenseField.placeholder = @"VPNT-XXXX-XXXX-XXXX";
    licenseField.borderStyle = UITextBorderStyleRoundedRect;
    licenseField.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
    licenseField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    licenseField.autocorrectionType = UITextAutocorrectionTypeNo;
    licenseField.tag = 200;
    [card2 addSubview:licenseField];
    
    UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    activateBtn.frame = CGRectMake(16, 100, w - 32, 44);
    [activateBtn setTitle:@"Activate License" forState:UIControlStateNormal];
    activateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    activateBtn.backgroundColor = [UIColor systemBlueColor];
    [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activateBtn.layer.cornerRadius = 10;
    activateBtn.tag = 300;
    [activateBtn addTarget:self action:@selector(activateLicense) forControlEvents:UIControlEventTouchUpInside];
    [card2 addSubview:activateBtn];
    
    UILabel *licStatus = [[UILabel alloc] initWithFrame:CGRectMake(16, 152, w - 32, 20)];
    licStatus.font = [UIFont systemFontOfSize:13];
    licStatus.textColor = [UIColor secondaryLabelColor];
    licStatus.tag = 400;
    [card2 addSubview:licStatus];
    y += 200;
    
    UIView *card3 = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 100)];
    card3.backgroundColor = [UIColor systemIndigoColor];
    card3.layer.cornerRadius = 12;
    [scrollView addSubview:card3];
    
    UILabel *buyTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 24)];
    buyTitle.text = @"SUPPORT THE DEVELOPER";
    buyTitle.font = [UIFont boldSystemFontOfSize:14];
    buyTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    [card3 addSubview:buyTitle];
    
    UILabel *buyDesc = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, w - 32, 20)];
    buyDesc.text = @"Get a license key to support future updates";
    buyDesc.font = [UIFont systemFontOfSize:13];
    buyDesc.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    [card3 addSubview:buyDesc];
    
    UIButton *buyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    buyBtn.frame = CGRectMake(16, 62, w - 32, 30);
    [buyBtn setTitle:@"Buy License  ->" forState:UIControlStateNormal];
    buyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [buyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    buyBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    buyBtn.layer.cornerRadius = 8;
    [buyBtn addTarget:self action:@selector(openStore) forControlEvents:UIControlEventTouchUpInside];
    [card3 addSubview:buyBtn];
    y += 120;
    
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake(x, y, w, 44);
    [refreshBtn setTitle:@"Refresh Status" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    refreshBtn.tag = 500;
    [refreshBtn addTarget:self action:@selector(refreshStatus) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:refreshBtn];
    y += 60;
    
    scrollView.contentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, y);
    self.window.rootViewController = rootVC;
    [self.window makeKeyAndVisible];
    
    [self refreshStatus];
    return YES;
}

- (void)refreshStatus {
    UIViewController *vc = self.window.rootViewController;
    UILabel *statusLabel = (UILabel *)[vc.view viewWithTag:100];
    UILabel *licStatus = (UILabel *)[vc.view viewWithTag:400];
    
    NSMutableString *status = [NSMutableString string];
    
    // Read status from file written by daemon (running as root)
    FILE *fp = fopen("/var/log/vpntether/status", "r");
    if (fp) {
        char line[256];
        while (fgets(line, sizeof(line), fp)) {
            line[strcspn(line, "\n")] = 0;
            if (strlen(line) > 0) {
                [status appendFormat:@"%s\n", line];
            }
        }
        fclose(fp);
    } else {
        [status appendString:@"Daemon: Not running\n"];
        [status appendString:@"VPN: Not active\n"];
        [status appendString:@"Clients: 0\n"];
    }
    
    statusLabel.text = status;
    
    FILE *lp = popen("/var/jb/usr/bin/cat /var/db/vpntether_license 2>/dev/null", "r");
    char lic[64] = "";
    fgets(lic, sizeof(lic), lp);
    pclose(lp);
    if (strlen(lic) > 1) {
        lic[strcspn(lic, "\n")] = 0;
        NSString *key = [NSString stringWithUTF8String:lic];
        licStatus.text = [NSString stringWithFormat:@"Active: %@", key];
        licStatus.textColor = [UIColor systemGreenColor];
    } else {
        licStatus.text = @"No license - buy one to activate";
        licStatus.textColor = [UIColor systemOrangeColor];
    }
}

- (void)activateLicense {
    UIViewController *vc = self.window.rootViewController;
    UITextField *field = (UITextField *)[vc.view viewWithTag:200];
    UILabel *licStatus = (UILabel *)[vc.view viewWithTag:400];
    
    NSString *key = field.text;
    if (key.length == 0) {
        licStatus.text = @"Please enter a license key";
        licStatus.textColor = [UIColor systemRedColor];
        return;
    }
    
    // Write request file — daemon (running as root) will activate
    NSString *reqFile = @"/var/log/vpntether/activate_request";
    NSString *resFile = @"/var/log/vpntether/activate_result";
    
    // Clear old result
    [[NSFileManager defaultManager] removeItemAtPath:resFile error:nil];
    
    // Write the key
    [key writeToFile:reqFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    licStatus.text = @"Activating...";
    licStatus.textColor = [UIColor systemOrangeColor];
    
    // Poll for result (max 3 seconds)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *result = [NSString stringWithContentsOfFile:resFile encoding:NSUTF8StringEncoding error:nil];
        if (result && result.length > 1) {
            result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([result rangeOfString:@"success" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                licStatus.text = @"License activated!";
                licStatus.textColor = [UIColor systemGreenColor];
            } else {
                licStatus.text = result;
                licStatus.textColor = [UIColor systemRedColor];
            }
            [[NSFileManager defaultManager] removeItemAtPath:reqFile error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:resFile error:nil];
            [self refreshStatus];
        } else {
            // Retry once more
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *result2 = [NSString stringWithContentsOfFile:resFile encoding:NSUTF8StringEncoding error:nil];
                if (result2 && result2.length > 1) {
                    result2 = [result2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if ([result2 rangeOfString:@"success" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        licStatus.text = @"License activated!";
                        licStatus.textColor = [UIColor systemGreenColor];
                    } else {
                        licStatus.text = result2;
                        licStatus.textColor = [UIColor systemRedColor];
                    }
                } else {
                    licStatus.text = @"Daemon not running. Install via Sileo first.";
                    licStatus.textColor = [UIColor systemRedColor];
                }
                [[NSFileManager defaultManager] removeItemAtPath:reqFile error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:resFile error:nil];
                [self refreshStatus];
            });
        }
    });
}

- (void)openStore {
    NSURL *url = [NSURL URLWithString:@"https://chariz.com/buy/ahmedsvpntether"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
