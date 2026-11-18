// Loaded into /usr/bin/perl (Apple-signed), which is allowed to use MediaRemote.
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

extern void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t, void (^)(CFDictionaryRef));
extern Boolean MRMediaRemoteSendCommand(uint32_t, CFDictionaryRef);

static void str(CFDictionaryRef d, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFStringRef v = d ? CFDictionaryGetValue(d, k) : NULL;
    char buf[1024] = "";
    if (v && CFGetTypeID(v) == CFStringGetTypeID()) CFStringGetCString(v, buf, sizeof buf, kCFStringEncodingUTF8);
    printf("%s\n", buf);
    CFRelease(k);
}

__attribute__((constructor)) static void go(void) {
    const char *cmd = getenv("NP_CMD");
    if (cmd) {
        MRMediaRemoteSendCommand(atoi(cmd), NULL);
        usleep(300000);
        exit(0);
    }
    dispatch_queue_t q = dispatch_get_global_queue(0, 0);
    MRMediaRemoteGetNowPlayingInfo(q, ^(CFDictionaryRef d) {
      {
        double rate = 0;
        CFNumberRef r = d ? CFDictionaryGetValue(d, CFSTR("kMRMediaRemoteNowPlayingInfoPlaybackRate")) : NULL;
        if (r && CFGetTypeID(r) == CFNumberGetTypeID()) CFNumberGetValue(r, kCFNumberDoubleType, &rate);
        int playing = rate > 0;
        str(d, "kMRMediaRemoteNowPlayingInfoTitle");
        str(d, "kMRMediaRemoteNowPlayingInfoArtist");
        printf("%d\n", playing);
        const char *path = getenv("NP_ART");
        CFDataRef art = d ? CFDictionaryGetValue(d, CFSTR("kMRMediaRemoteNowPlayingInfoArtworkData")) : NULL;
        if (path && art && CFGetTypeID(art) == CFDataGetTypeID()) {
            FILE *f = fopen(path, "wb");
            if (f) { fwrite(CFDataGetBytePtr(art), 1, CFDataGetLength(art), f); fclose(f); }
            printf("art\n");
        }
        fflush(stdout);
        exit(0);
      }
    });
}
