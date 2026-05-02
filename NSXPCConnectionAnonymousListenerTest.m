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
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    XPCListenerDelegate *delegate = [XPCListenerDelegate new];
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = delegate;
    [listener resume];

    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithListenerEndpoint:listener.endpoint];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCEchoing)];
    [connection resume];

    id<XPCEchoing> proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        proxyError = error;
        dispatch_semaphore_signal(semaphore);
    }];

    [proxy uppercaseString:@"hello from objc" withReply:^(NSString *result) {
        response = result;
        dispatch_semaphore_signal(semaphore);
    }];

    long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    [connection invalidate];

    if (waitResult != 0) {
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