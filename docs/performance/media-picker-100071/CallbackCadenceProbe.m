#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <sys/resource.h>
#import <fcntl.h>
#import <unistd.h>
#include <math.h>
#include <stdio.h>

// Temporary simulator diagnostic. No constructor, frame-rate override, or per-frame I/O.
typedef struct { double timestamp, targetTimestamp, callbackTime; } TGTimingRow;
typedef struct { double cpuSeconds; int64_t residentBytes; } TGProcessStats;

static TGProcessStats TGReadProcessStats(void) {
    struct rusage usage = {0};
    double cpu = -1.0;
    if (getrusage(RUSAGE_SELF, &usage) == 0) {
        cpu = usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6
            + usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;
    }
    mach_task_basic_info_data_t info = {0};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    int64_t rss = task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
        (task_info_t)&info, &count) == KERN_SUCCESS ? (int64_t)info.resident_size : -1;
    return (TGProcessStats){cpu, rss};
}

@interface TGCallbackCadenceProbe : NSObject {
@public
    TGTimingRow *rows;
    size_t count, capacity, overflow;
    double started, requestedDuration;
    TGProcessStats before;
    NSString *outputPath;
    CADisplayLink *link;
}
- (void)tick:(CADisplayLink *)displayLink;
- (void)finish;
@end

static TGCallbackCadenceProbe *TGActiveProbe;

@implementation TGCallbackCadenceProbe
- (void)tick:(CADisplayLink *)displayLink {
    if (count < capacity) {
        rows[count++] = (TGTimingRow){displayLink.timestamp, displayLink.targetTimestamp,
                                    CACurrentMediaTime()};
    } else {
        overflow++;
    }
}

- (void)finish {
    if (TGActiveProbe != self) return;
    if (started == 0) {
        TGActiveProbe = nil;
        free(rows);
        rows = NULL;
        return;
    }
    [link invalidate];
    link = nil;
    double ended = CACurrentMediaTime();
    TGProcessStats after = TGReadProcessStats();
    TGActiveProbe = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int fd = open(self->outputPath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
        FILE *file = fd >= 0 ? fdopen(fd, "w") : NULL;
        BOOL written = file != NULL;
        if (file) {
            written = fprintf(file, "timestamp,target_timestamp,callback_time\n") > 0;
            for (size_t i = 0; i < self->count && written; i++) {
                TGTimingRow row = self->rows[i];
                written = fprintf(file, "%.9f,%.9f,%.9f\n", row.timestamp,
                                  row.targetTimestamp, row.callbackTime) > 0;
            }
            if (fclose(file) != 0) written = NO;
        } else if (fd >= 0) {
            close(fd);
        }
        double wall = ended - self->started;
        double cpu = self->before.cpuSeconds >= 0 && after.cpuSeconds >= 0
            ? after.cpuSeconds - self->before.cpuSeconds : -1;
        NSDictionary *summary = @{
            @"metric": @"CADisplayLink callback cadence; not rendered FPS",
            @"frame_rate_policy": @"default; no preferredFrameRateRange override",
            @"requested_duration_seconds": @(self->requestedDuration),
            @"observed_wall_seconds": @(wall),
            @"callbacks": @(self->count), @"buffer_overflow": @(self->overflow),
            @"cpu_process_seconds": cpu >= 0 ? @(cpu) : [NSNull null],
            @"cpu_process_percent_one_core_100": cpu >= 0 && wall > 0 ? @(100 * cpu / wall) : [NSNull null],
            @"rss_start_bytes": self->before.residentBytes >= 0 ? @(self->before.residentBytes) : [NSNull null],
            @"rss_end_bytes": after.residentBytes >= 0 ? @(after.residentBytes) : [NSNull null],
            @"csv_written": @(written),
            @"limits": @"CPU covers all process work plus probe overhead. RSS is two snapshots, not peak. File I/O occurs after the measurement."
        };
        NSData *json = [NSJSONSerialization dataWithJSONObject:summary options:NSJSONWritingPrettyPrinted error:nil];
        [json writeToFile:[self->outputPath stringByAppendingString:@".summary.json"]
                 options:NSDataWritingWithoutOverwriting error:nil];
        free(self->rows);
        self->rows = NULL;
    });
}
@end

// Call on the main thread. 1=queued for next main-runloop; -1=busy, -2=not main thread,
// -3=invalid duration/path, -4=output already exists, -5=allocation failed.
__attribute__((visibility("default")))
int TGWarpTimingStart(double duration, const char *path) {
    if (![NSThread isMainThread]) return -2;
    if (TGActiveProbe) return -1;
    if (!isfinite(duration) || duration < 0.5 || duration > 120 || !path || path[0] != '/') return -3;
    NSString *destination = [NSString stringWithUTF8String:path];
    if (!destination) return -3;
    if ([[NSFileManager defaultManager] fileExistsAtPath:destination]
        || [[NSFileManager defaultManager] fileExistsAtPath:[destination stringByAppendingString:@".summary.json"]]) return -4;
    BOOL directory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:destination.stringByDeletingLastPathComponent
                                           isDirectory:&directory] || !directory) return -3;
    TGCallbackCadenceProbe *probe = [TGCallbackCadenceProbe new];
    // ponytail: bounded to 120 s and 240 callbacks/s; overflow is reported, never reallocates per frame.
    probe->capacity = (size_t)ceil(duration * 240) + 240;
    probe->rows = calloc(probe->capacity, sizeof(TGTimingRow));
    if (!probe->rows) return -5;
    probe->outputPath = destination;
    probe->requestedDuration = duration;
    TGActiveProbe = probe;
    // Begin after LLDB's expression returns and the main thread resumes.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (TGActiveProbe != probe) return;
        probe->before = TGReadProcessStats();
        probe->started = CACurrentMediaTime();
        probe->link = [CADisplayLink displayLinkWithTarget:probe selector:@selector(tick:)];
        [probe->link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [probe finish]; });
    });
    return 1;
}

__attribute__((visibility("default")))
int TGWarpTimingStop(void) {
    if (![NSThread isMainThread]) return -2;
    [TGActiveProbe finish];
    return 0;
}
