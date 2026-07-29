#import <UIKit/UIKit.h>

static NSString *runCmd(NSString *bin, NSArray *args) {
    int pipefd[2];
    pipe(pipefd);
    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        int n = (int)args.count + 1;
        char **argv = malloc((n + 1) * sizeof(char *));
        argv[0] = (char *)[bin UTF8String];
        for (int i = 0; i < args.count; i++) argv[i+1] = (char *)[args[i] UTF8String];
        argv[n] = NULL;
        char *env[] = {"PATH=/var/jb/usr/bin:/usr/bin:/bin", NULL};
        execve(argv[0], argv, env);
        free(argv);
        _exit(1);
    }
    close(pipefd[1]);
    NSMutableString *out = [NSMutableString new];
    char buf[256];
    ssize_t n;
    while ((n = read(pipefd[0], buf, sizeof(buf)-1)) > 0) {
        buf[n] = 0;
        [out appendFormat:@"%s", buf];
    }
    close(pipefd[0]);
    waitpid(pid, NULL, 0);
    return [[out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

static NSString *managerPath(void) {
    return @"/var/jb/usr/libexec/vpntether/vpntether_manager";
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIViewController *vc;
@property (strong, nonatomic) UILabel *licStatusLabel;
@property (strong, nonatomic) UITextField *keyField;
@property (strong, nonatomic) UIButton *activateBtn;
@property (strong, nonatomic) UILabel *resultLabel;
@property (strong, nonatomic) UILabel *vpnLabel;
@property (strong, nonatomic) UILabel *hsLabel;
@property (strong, nonatomic) UILabel *relayLabel;
@property (strong, nonatomic) UILabel *clientLabel;
@end

@implementation AppDelegate

- (void)refreshStatus {
    NSString *status = runCmd(@"/var/jb/usr/libexec/vpntether/vpntether_status", @[]);
    NSMutableDictionary *kv = [NSMutableDictionary new];
    for (NSString *line in [status componentsSeparatedByString:@"\n"]) {
        NSArray *parts = [line componentsSeparatedByString:@"="];
        if (parts.count == 2) kv[parts[0]] = parts[1];
    }
    int vpnOn = [kv[@"VPN"] intValue];
    int hsOn = [kv[@"HOTSPOT"] intValue];
    int relayOn = [kv[@"RELAY"] intValue];
    int licOn = [kv[@"LICENSE"] intValue];

    UIColor *green = [UIColor colorWithRed:0.09 green:0.64 blue:0.29 alpha:1];
    UIColor *red = [UIColor colorWithRed:0.80 green:0.07 blue:0.15 alpha:1];
    UIColor *orange = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1];

    self.vpnLabel.text = [NSString stringWithFormat:@"VPN: %@", vpnOn ? @"ACTIVE" : @"INACTIVE"];
    self.vpnLabel.textColor = vpnOn ? green : red;

    self.hsLabel.text = [NSString stringWithFormat:@"Hotspot: %@", hsOn ? @"ACTIVE" : @"INACTIVE"];
    self.hsLabel.textColor = hsOn ? green : red;

    self.relayLabel.text = [NSString stringWithFormat:@"Relay: %@", relayOn ? @"RUNNING" : @"STOPPED"];
    self.relayLabel.textColor = relayOn ? green : red;

    self.licStatusLabel.text = [NSString stringWithFormat:@"License: %@", licOn ? @"ACTIVATED" : @"NOT ACTIVATED"];
    self.licStatusLabel.textColor = licOn ? green : orange;

    int clients = 0;
    FILE *f = fopen("/var/db/vpntether_clients", "r");
    if (f) { char buf[16]; if (fgets(buf, sizeof(buf), f)) clients = atoi(buf); fclose(f); }
    self.clientLabel.text = [NSString stringWithFormat:@"Clients: %d", clients];

    self.keyField.hidden = licOn;
    self.activateBtn.hidden = licOn;
    self.resultLabel.hidden = licOn;

    [self performSelector:@selector(refreshStatus) withObject:nil afterDelay:5.0];
}

- (void)activateLicense {
    NSString *key = self.keyField.text;
    if (key.length < 10) {
        self.resultLabel.text = @"Enter a valid license key";
        self.resultLabel.textColor = [UIColor redColor];
        return;
    }
    self.activateBtn.enabled = NO;
    [self.activateBtn setTitle:@"Activating..." forState:UIControlStateNormal];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result = runCmd(managerPath(), @[@"activate", key]);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.activateBtn.enabled = YES;
            [self.activateBtn setTitle:@"Activate License" forState:UIControlStateNormal];
            if ([result containsString:@"activated"] || [result containsString:@"ACTIVATED"]) {
                self.resultLabel.text = @"License activated!";
                self.resultLabel.textColor = [UIColor colorWithRed:0.09 green:0.64 blue:0.29 alpha:1];
                [self refreshStatus];
            } else {
                self.resultLabel.text = result;
                self.resultLabel.textColor = [UIColor redColor];
            }
        });
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.vc = [[UIViewController alloc] init];
    self.window.rootViewController = self.vc;
    UIView *view = self.vc.view;
    view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];

    CGFloat w = view.bounds.size.width;
    CGFloat y = 40;

    // Flag banner
    UIImageView *flagView = [[UIImageView alloc] initWithFrame:CGRectMake(20, y, w - 40, 48)];
    flagView.image = [UIImage imageNamed:@"flag.png"];
    flagView.contentMode = UIViewContentModeScaleAspectFill;
    flagView.clipsToBounds = YES;
    flagView.layer.cornerRadius = 6;
    flagView.layer.borderWidth = 0.5;
    flagView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    [view addSubview:flagView];
    y += 60;

    // Header row: icon + title
    UIView *headerRow = [[UIView alloc] initWithFrame:CGRectMake(20, y, w - 40, 50)];
    [view addSubview:headerRow];

    UIImageView *appIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    appIcon.image = [UIImage imageNamed:@"AppIcon.png"];
    appIcon.contentMode = UIViewContentModeScaleAspectFill;
    appIcon.layer.cornerRadius = 12;
    appIcon.clipsToBounds = YES;
    appIcon.layer.borderWidth = 0.5;
    appIcon.layer.borderColor = [UIColor lightGrayColor].CGColor;
    [headerRow addSubview:appIcon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(62, 2, headerRow.frame.size.width - 62, 30)];
    title.text = @"ahmeds-vpntether";
    title.font = [UIFont boldSystemFontOfSize:22];
    [headerRow addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(62, 30, headerRow.frame.size.width - 62, 16)];
    subtitle.text = @"Hotspot VPN Relay";
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = [UIColor grayColor];
    [headerRow addSubview:subtitle];
    y += 60;

    // Status card
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 180)];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 14;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = 8;
    [view addSubview:card];

    CGFloat cx = 20;
    CGFloat cy = 16;
    CGFloat cw = card.frame.size.width - 40;
    CGFloat lh = 24;

    UILabel *statusTitle = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, 22)];
    statusTitle.text = @"Status";
    statusTitle.font = [UIFont boldSystemFontOfSize:16];
    statusTitle.textColor = [UIColor darkGrayColor];
    [card addSubview:statusTitle];
    cy += 30;

    self.vpnLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, lh)];
    self.vpnLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:self.vpnLabel];
    cy += lh;

    self.hsLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, lh)];
    self.hsLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:self.hsLabel];
    cy += lh;

    self.relayLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, lh)];
    self.relayLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:self.relayLabel];
    cy += lh;

    self.licStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, lh)];
    self.licStatusLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:self.licStatusLabel];
    cy += lh;

    self.clientLabel = [[UILabel alloc] initWithFrame:CGRectMake(cx, cy, cw, lh)];
    self.clientLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:self.clientLabel];
    y += 194;

    // Refresh button
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake(w / 2 - 60, y, 120, 32);
    [refreshBtn setTitle:@"↻ Refresh" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    refreshBtn.backgroundColor = [UIColor colorWithRed:0.09 green:0.64 blue:0.29 alpha:1];
    [refreshBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refreshBtn.layer.cornerRadius = 16;
    [refreshBtn addTarget:self action:@selector(forceRefresh) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:refreshBtn];
    y += 44;

    // License activation UI
    self.keyField = [[UITextField alloc] initWithFrame:CGRectMake(20, y, w - 40, 36)];
    self.keyField.placeholder = @"Paste license key here";
    self.keyField.borderStyle = UITextBorderStyleRoundedRect;
    self.keyField.font = [UIFont systemFontOfSize:14];
    self.keyField.textAlignment = NSTextAlignmentCenter;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    [view addSubview:self.keyField];
    y += 42;

    self.activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateBtn.frame = CGRectMake(40, y, w - 80, 40);
    [self.activateBtn setTitle:@"Activate License" forState:UIControlStateNormal];
    self.activateBtn.backgroundColor = [UIColor colorWithRed:0.09 green:0.64 blue:0.29 alpha:1];
    [self.activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.activateBtn.layer.cornerRadius = 20;
    [self.activateBtn addTarget:self action:@selector(activateLicense) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:self.activateBtn];
    y += 46;

    self.resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 20)];
    self.resultLabel.textAlignment = NSTextAlignmentCenter;
    self.resultLabel.font = [UIFont systemFontOfSize:13];
    self.resultLabel.hidden = YES;
    [view addSubview:self.resultLabel];

    // WhatsApp button
    UIButton *wa = [UIButton buttonWithType:UIButtonTypeSystem];
    wa.frame = CGRectMake(40, view.bounds.size.height - 90, w - 80, 44);
    [wa setTitle:@"  Contact on WhatsApp" forState:UIControlStateNormal];
    wa.backgroundColor = [UIColor colorWithRed:0.09 green:0.64 blue:0.29 alpha:1];
    [wa setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    wa.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    wa.layer.cornerRadius = 22;
    [wa addTarget:self action:@selector(openWA) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:wa];

    [self.window makeKeyAndVisible];
    [self refreshStatus];
    return YES;
}

- (void)forceRefresh {
    [self refreshStatus];
}

- (void)openWA {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"whatsapp://send?phone=9647810306046"] options:@{} completionHandler:nil];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
