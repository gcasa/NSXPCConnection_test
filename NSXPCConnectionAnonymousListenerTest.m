#import <Foundation/Foundation.h>

@protocol XPCEchoing
- (void)uppercaseString:(NSString *)string withReply:(void (^)(NSString *response))reply;
@end

@interface XPCEchoService : NSObject <XPCEchoing>
@end

@implementation XPCEchoService

- (void)uppercaseString:(NSString *)string withReply:(void (^)(NSString *response))reply {
    reply([string uppercaseString]);
}

@end

@interface XPCListenerDelegate : NSObject <NSXPCListenerDelegate>
@property (nonatomic, strong) XPCEchoService *service;
@end

@implementation XPCListenerDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _service = [XPCEchoService new];
    }
    return self;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCEchoing)];
    newConnection.exportedObject = self.service;
    [newConnection resume];
    return YES;
}

@end

static int RunNSXPCConnectionTest(void) {
    __block NSString *response = nil;
    __block NSError *proxyError = nil;
    __block BOOL completed = NO;

    XPCListenerDelegate *delegate = [XPCListenerDelegate new];
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = delegate;
    [listener resume];

    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithListenerEndpoint:listener.endpoint];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCEchoing)];
    [connection resume];

    id<XPCEchoing> proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        proxyError = error;
        completed = YES;
    }];

    [proxy uppercaseString:@"hello from objc" withReply:^(NSString *result) {
        response = result;
        completed = YES;
    }];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while (!completed && [deadline timeIntervalSinceNow] > 0.0) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
    }

    [connection invalidate];

    if (!completed) {
        fprintf(stderr, "Timed out waiting for NSXPCConnection reply.\n");
        return 1;
    }

    if (proxyError != nil) {
        fprintf(stderr, "NSXPCConnection proxy error: %s\n", proxyError.localizedDescription.UTF8String);
        return 1;
    }

    if (![response isEqualToString:@"HELLO FROM OBJC"]) {
        fprintf(stderr, "Unexpected reply. Expected HELLO FROM OBJC, got %s\n", response.UTF8String ?: "(null)");
        return 1;
    }

    printf("NSXPCConnection test passed: %s\n", response.UTF8String);
    return 0;
}

int main(void) {
    @autoreleasepool {
        return RunNSXPCConnectionTest();
    }
}