#import "CCHMain.h"
#import "JRSwizzle.h"
#import "objc/runtime.h"
#import <Cocoa/Cocoa.h>

#define NSColorFromARGB(rgbValue) \
[NSColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
                green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
                 blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
                alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0]

// shared parsed config
static NSDictionary<NSString *, NSDictionary *> *colors;

// FSEvent callback for config file
void config_changed(ConstFSEventStreamRef streamRef,
                void *clientCallBackInfo,
                size_t numEvents,
                void *eventPaths,
                const FSEventStreamEventFlags eventFlags[],
                const FSEventStreamEventId eventIds[]) {
    [CCHMain loadColors];
}

@implementation NSTextStorage (CCH)

- (void)xc_fixAttributesInRange:(NSRange)aRange {
    [self xc_fixAttributesInRange:aRange];

    // very hacky way to check whether this is an console indeed and not some arbietrary text storage
    if (![self.layoutManagers.firstObject.className isEqualToString:@"DVTLayoutManager"]) {
        return;
    }

    // get the font and strip it of possibly previosly set traits
    NSFont *font = [[NSFontManager sharedFontManager] convertFont:self.font toNotHaveTrait:NSFontBoldTrait | NSFontItalicTrait];

    // string and iteration range
    NSString *aString = [self attributedSubstringFromRange:aRange].string;

    // lookup each pattern
    [colors enumerateKeysAndObjectsUsingBlock:^(NSString *target, NSDictionary *_attrs, BOOL *stop) {
        NSRange range = [aString rangeOfString:target];
        NSRange remainingRange = NSMakeRange(0, aString.length);
        // iterate for every occasion of pattern

        while (range.location != NSNotFound) {
            NSRange lineRange = [aString lineRangeForRange:range];
            NSRange realRange = NSMakeRange(aRange.location + lineRange.location, lineRange.length);
            NSMutableDictionary *attrs = [_attrs mutableCopy];

            // turn b's and i's into NSFont
            NSString *fontAttribute = attrs[@"font_modifier"];
            if ([fontAttribute isEqualToString:@"b"]) {
                attrs[NSFontAttributeName] = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontBoldTrait];
            } else if ([fontAttribute isEqualToString:@"i"]) {
                attrs[NSFontAttributeName] = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSFontItalicTrait];
            }

            // remove custom key
            [attrs removeObjectForKey:@"font_modifier"];

            [self addAttributes:attrs range:realRange];
            
            remainingRange = NSMakeRange(range.location + range.length, aString.length - range.location - range.length);
            range = [aString rangeOfString:target options:0 range:remainingRange];
        }
    }];
}

@end

@implementation CCHMain

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didFinishLoading)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    });
}

+ (void)didFinishLoading {
    // setup FSEventStream to dynamically reload config file
    CFStringRef path = (__bridge CFStringRef)[self configPath];
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&path, 1, NULL);
    
    FSEventStreamRef stream = FSEventStreamCreate(NULL,
                                                  &config_changed,
                                                  NULL,
                                                  pathsToWatch,
                                                  kFSEventStreamEventIdSinceNow,
                                                  3.0,
                                                  kFSEventStreamCreateFlagFileEvents);
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);

    // load config file
    [self loadColors];
    
    // swizzle
    [NSTextStorage jr_swizzleMethod:@selector(fixAttributesInRange:) withMethod:@selector(xc_fixAttributesInRange:) error:nil];
}

+ (void)loadColors {
    NSDictionary<NSString *, NSString *> *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[self configPath]]
                                                                                                 options:NSJSONReadingAllowFragments
                                                                                                   error:nil];
    if (!json) {
        return;
    }

    NSMutableDictionary *result = [NSMutableDictionary new];
    [json enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL * _Nonnull stop) {
        NSArray<NSString *> *components = [obj componentsSeparatedByString:@":"];
        
        NSMutableDictionary *attrs = [NSMutableDictionary new];
        
        // parse bg color
        if (components.count > 0) {
            unsigned bg = 0;
            NSScanner *scanner = [NSScanner scannerWithString:components[0]];
            [scanner scanHexInt:&bg];
            if (bg) {
                attrs[NSBackgroundColorAttributeName] = NSColorFromARGB(bg);
            }
        }
        
        // parse fg color
        if (components.count > 1) {
            unsigned fg = 0;
            NSScanner *scanner = [NSScanner scannerWithString:components[1]];
            [scanner scanHexInt:&fg];
            if (fg) {
                attrs[NSForegroundColorAttributeName] = NSColorFromARGB(fg);
            }
        }
        
        // parse font_modifier
        if (components.count > 2) {
            if ([components[2] isEqualToString:@"i"]) {
                attrs[@"font_modifier"] = @"i";
            } else if ([components[2] isEqualToString:@"b"]) {
                attrs[@"font_modifier"] = @"b";
            }
        }

        result[key] = attrs;
    }];
    colors = [result copy];
}

+ (NSString *)configPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@".xccolors.json"];
}

@end

