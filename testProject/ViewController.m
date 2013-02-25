//
//  ViewController.m
//  testProject
//
//  Created by 黄 嘉恒 on 2/20/13.
//  Copyright (c) 2013 黄 嘉恒. All rights reserved.
//

#import "ViewController.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <netinet/in.h> 
#import <ifaddrs.h> 
#import <sys/socket.h>

@interface ViewController ()<NSURLConnectionDelegate>
@property (nonatomic,strong)NSMutableData *responseData;
@property (nonatomic,strong)NSURLConnection *getCookieConnection;
@property (nonatomic,strong)NSURLConnection *loginConnection;
@property (nonatomic,strong)NSURLConnection *logoutConnection;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic,strong)NSHTTPURLResponse *response;
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UISwitch *saveSwitch;

@end

@implementation ViewController

- (IBAction)login {
    NSString *username = self.usernameField.text;
    if (username.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"错误" message:@"用户名不能为空！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    
    NSString *password = self.passwordField.text;
    if (password.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"错误" message:@"密码不能为空！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    
    if ([self.saveSwitch isOn])
    {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:username forKey:@"myUsername"];
        [userDefaults setObject:password forKey:@"myPassword"];
        [userDefaults synchronize];
    }
    else
    {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:@"" forKey:@"myUsername"];
        [userDefaults setObject:@"" forKey:@"myPassword"];
        [userDefaults synchronize];
    }
    
    NSURL *myURL = [NSURL URLWithString:@"https://wlan.whu.edu.cn/portal/login"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:myURL
                                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                timeoutInterval:60];
    request.HTTPMethod = @"POST";
    NSString *POSTBody = [NSString stringWithFormat:@"username=%@&password=%@",username,password];
    request.HTTPBody = [POSTBody dataUsingEncoding:NSUTF8StringEncoding];
    self.loginConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (IBAction)loadCookie {
    [self list];
    [self clearCookies];
    NSURL *myURL = [NSURL URLWithString:@"https://wlan.whu.edu.cn/portal?cmd=login&switchip=&mac=&ip=10.115.3.113&essid=WHU-WLAN&url="];//replace 10.115.3.113 with local IP
    NSMutableURLRequest *request = [NSURLRequest requestWithURL:myURL
                                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                timeoutInterval:60];
    self.getCookieConnection= [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (IBAction)logout {
    NSURL *myURL = [NSURL URLWithString:@"https://wlan.whu.edu.cn/portal/logOff"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:myURL
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60];
    request.HTTPMethod = @"GET";
    self.logoutConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = (NSHTTPURLResponse *)response;
    self.responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"%@",error.description);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.webView loadData:self.responseData MIMEType:[self.response MIMEType] textEncodingName:@"NSUTF8StringEncoding" baseURL:nil];
}

- (void)clearCookies{
    NSURL *myURL = [NSURL URLWithString:@"https://wlan.whu.edu.cn/"];
    NSHTTPCookieStorage *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *WLANCookies = [cookies cookiesForURL:myURL];
    for (NSHTTPCookie *cookie in WLANCookies) {
        [cookies deleteCookie:cookie];
    }
}

//ignore Certification Error
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSArray *trustedHosts = @[@"wlan.whu.edu.cn"];
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        if ([trustedHosts containsObject:challenge.protectionSpace.host])
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

//get local IP(unfinished)
- (void)list
{    
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    struct ifaddrs*	addrs;
    BOOL success = (getifaddrs(&addrs) == 0);
    if (success)
    {
        const struct ifaddrs* cursor = addrs;
        while (cursor != NULL)
        {
            NSMutableString* ip;
            if (cursor->ifa_addr->sa_family == AF_INET)
            {
                const struct sockaddr_in* dlAddr = (const struct sockaddr_in*) cursor->ifa_addr;
                const uint8_t* base = (const uint8_t*)&dlAddr->sin_addr;
                ip = [NSMutableString new];
                for (int i = 0; i < 4; i++)
                {
                    if (i != 0)
                        [ip appendFormat:@"."];
                    [ip appendFormat:@"%d", base[i]];
                }
                [result setObject:(NSString*)ip forKey:[NSString stringWithFormat:@"%s", cursor->ifa_name]];
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
	NSLog(@"IP addresses: %@", result);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];
}

//get WLAN SSID(does no work!)
- (void)fetchSSIDInfo {
    /*
    CFArrayRef arrayRef = CNCopySupportedInterfaces();
    NSArray *interfaces = (__bridge NSArray *)arrayRef;
    NSLog(@"interfaces -> %@", interfaces);
    
    for (NSString *interfaceName in interfaces) {
        CFDictionaryRef dictRef = CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName);
        if (dictRef != NULL) {
            NSDictionary *networkInfo = (__bridge NSDictionary *)dictRef;
            NSLog(@"network info -> %@", networkInfo);
            CFRelease(dictRef);
        }
    }
    CFRelease(arrayRef);
    */
    CFArrayRef myArray = CNCopySupportedInterfaces();
    const void* currentSSID;
    if(myArray!=nil){
        CFDictionaryRef myDict = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(myArray, 0));
        if(myDict!=nil)currentSSID=CFDictionaryGetValue(myDict, @"SSID");
        else currentSSID=@"<<NONE1>>";
        CFDictionaryRef aDict = CNCopyCurrentNetworkInfo(kCNNetworkInfoKeySSID);
        int i = CFDictionaryGetCount(aDict);
        NSLog(@"%i",i);
    } else currentSSID=@"<<NONE2>>";
    NSLog(@"%@",currentSSID);
}

- (IBAction)dismissKeyboard:(id)sender;
{
    [self.usernameField resignFirstResponder];
    [self.passwordField resignFirstResponder];
}

- (IBAction)closeDoneEdit:(id)sender
{
    [sender resignFirstResponder];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 10000) {    // it's the Error alert
        if (buttonIndex == 0) {     // and they clicked OK.
            
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
        
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *myUsername = [userDefaultes stringForKey:@"myUsername"];
    self.usernameField.text = myUsername;
    NSString *myPassword = [userDefaultes stringForKey:@"myPassword"];
    self.passwordField.text = myPassword;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void)viewDidUnload {
    [self setSaveSwitch:nil];
    [super viewDidUnload];
}
@end
