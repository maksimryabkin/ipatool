//go:build darwin && cgo

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@interface IPAToolCKSigningSession : NSObject
- (instancetype)initWithStoreClient:(id)storeClient;
- (void)openSessionWithCompletionHandler:(void (^)(void))completionHandler;
- (NSData *)signData:(NSData *)data error:(NSError **)error;
- (void)closeSession;
- (BOOL)isSessionOpen;
@end

static void *commerceKitHandle;
static char commerceKitLoadError[512];

static void loadCommerceKit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        commerceKitHandle = dlopen(
            "/System/Library/PrivateFrameworks/CommerceKit.framework/CommerceKit",
            RTLD_LAZY | RTLD_LOCAL
        );

        if (commerceKitHandle == NULL) {
            const char *message = dlerror();
            snprintf(
                commerceKitLoadError,
                sizeof(commerceKitLoadError),
                "%s",
                message != NULL ? message : "failed to load CommerceKit"
            );
        }
    });
}

static void setErrorMessage(char **destination, const char *message) {
    if (destination == NULL) {
        return;
    }

    *destination = strdup(message != NULL ? message : "unknown CommerceKit error");
}

static void setNSErrorMessage(char **destination, NSError *error, const char *fallback) {
    const char *message = error.localizedDescription.UTF8String;
    setErrorMessage(destination, message != NULL ? message : fallback);
}

int ipatool_mescal_sign(
    const unsigned char *input,
    size_t inputLength,
    unsigned char **output,
    size_t *outputLength,
    char **errorMessage
) {
    if (output == NULL || outputLength == NULL) {
        setErrorMessage(errorMessage, "invalid SAP signing output parameters");
        return 2;
    }

    *output = NULL;
    *outputLength = 0;
    if (errorMessage != NULL) {
        *errorMessage = NULL;
    }

    @autoreleasepool {
        loadCommerceKit();
        if (commerceKitHandle == NULL) {
            setErrorMessage(errorMessage, commerceKitLoadError);
            return 1;
        }

        Class signingSessionClass = NSClassFromString(@"CKSigningSession");
        if (signingSessionClass == Nil) {
            setErrorMessage(errorMessage, "CKSigningSession is missing from CommerceKit");
            return 1;
        }

        IPAToolCKSigningSession *session = [(id)[signingSessionClass alloc] initWithStoreClient:nil];
        if (session == nil) {
            setErrorMessage(errorMessage, "CommerceKit could not create a SAP signing session");
            return 2;
        }

        dispatch_semaphore_t opened = dispatch_semaphore_create(0);
        [session openSessionWithCompletionHandler:^{
            dispatch_semaphore_signal(opened);
        }];

        long waitResult = dispatch_semaphore_wait(
            opened,
            dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)
        );
        if (waitResult != 0) {
            [session closeSession];
            [session release];
            setErrorMessage(errorMessage, "timed out opening the Apple SAP signing session");
            return 2;
        }

        if ([session respondsToSelector:@selector(isSessionOpen)] && ![session isSessionOpen]) {
            [session closeSession];
            [session release];
            setErrorMessage(errorMessage, "Apple SAP signing session did not open");
            return 2;
        }

        NSData *data = [NSData dataWithBytes:input length:inputLength];
        NSError *signingError = nil;
        NSData *signature = [session signData:data error:&signingError];
        [session closeSession];

        if (signature == nil) {
            setNSErrorMessage(errorMessage, signingError, "CommerceKit could not sign the Apple action");
            [session release];
            return 2;
        }

        NSUInteger signatureLength = signature.length;
        unsigned char *signatureCopy = malloc(signatureLength);
        if (signatureCopy == NULL) {
            [session release];
            setErrorMessage(errorMessage, "failed to allocate memory for the SAP signature");
            return 2;
        }

        [signature getBytes:signatureCopy length:signatureLength];
        [session release];

        *output = signatureCopy;
        *outputLength = signatureLength;
        return 0;
    }
}
