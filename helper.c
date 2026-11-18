// Loaded into /usr/bin/perl (Apple-signed), which is allowed to use MediaRemote.
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>

extern void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t, void (^)(CFDictionaryRef));

static void str(CFDictionaryRef d, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFStringRef v = d ? CFDictionaryGetValue(d, k) : NULL;
    char buf[1024] = "";
    if (v && CFGetTypeID(v) == CFStringGetTypeID()) CFStringGetCString(v, buf, sizeof buf, kCFStringEncodingUTF8);
    printf("%s\n", buf);
    CFRelease(k);
}

__attribute__((constructor)) static void go(void) {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(0, 0), ^(CFDictionaryRef d) {
        str(d, "kMRMediaRemoteNowPlayingInfoTitle");
        str(d, "kMRMediaRemoteNowPlayingInfoArtist");
        const char *path = getenv("NP_ART");
        CFDataRef art = d ? CFDictionaryGetValue(d, CFSTR("kMRMediaRemoteNowPlayingInfoArtworkData")) : NULL;
        if (path && art && CFGetTypeID(art) == CFDataGetTypeID()) {
            FILE *f = fopen(path, "wb");
            if (f) { fwrite(CFDataGetBytePtr(art), 1, CFDataGetLength(art), f); fclose(f); }
            printf("art\n");
        }
        fflush(stdout);
        exit(0);
    });
}
