#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface VPNTetherPrefsListController : PSListController
@end

@implementation VPNTetherPrefsListController

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reloadSpecifiers];
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return [[NSUserDefaults standardUserDefaults] objectForKey:[specifier propertyForKey:@"key"] ?: @"vpntether_enabled"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier propertyForKey:@"key"]];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                          CFSTR("com.alhamadany.ahmed.vpntether/prefsChanged"),
                                          NULL, NULL, true);
}

- (void)respring {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/bin/killall", "killall", "-HUP", "SpringBoard", NULL);
    } else {
        waitpid(pid, NULL, 0);
    }
}

@end
