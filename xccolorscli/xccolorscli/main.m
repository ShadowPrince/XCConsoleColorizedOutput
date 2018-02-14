#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#define NSColorFromARGB(rgbValue) \
[NSColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0]

// shared parsed config
static NSDictionary<NSString *, NSDictionary *> *colors;

@interface XCColorsCLI: NSObject
@end

@implementation XCColorsCLI

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

+ (NSAttributedString *)highlight:(NSString *)aString {
    NSFont *font = [[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"PragmataPro" size:12.f]
                                                      toHaveTrait:NSFontMonoSpaceTrait];
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:aString];
    [string addAttributes:@{
                            NSFontAttributeName: font,
                            NSForegroundColorAttributeName: NSColorFromARGB(0xFF708284),
                            NSBackgroundColorAttributeName: NSColorFromARGB(0xFF042029),
                            }
                    range:NSMakeRange(0, string.length)];

    // lookup each pattern
    [colors enumerateKeysAndObjectsUsingBlock:^(NSString *target, NSDictionary *_attrs, BOOL *stop) {
        NSRange range = [aString rangeOfString:target];
        NSRange remainingRange = NSMakeRange(0, aString.length);
        // iterate for every occasion of pattern
        
        while (range.location != NSNotFound) {
            NSRange lineRange = [aString lineRangeForRange:range];
            NSRange realRange = NSMakeRange(lineRange.location, lineRange.length);
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
            
            [string addAttributes:attrs range:realRange];

            remainingRange = NSMakeRange(range.location + range.length, aString.length - range.location - range.length);
            range = [aString rangeOfString:target options:0 range:remainingRange];
        }
    }];
    
    return string;
}

+ (void)process:(NSString *)path output:(NSString *)outputpath {
    NSString *input = [self load:path];
    [self output:[self highlight:input] to:outputpath];
}

+ (NSString *)load:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
                    
    if ([path hasSuffix:@"rtf"]) {
        return [[NSAttributedString alloc] initWithData:data
                                                options:@{NSOpenDocumentTextDocumentType: NSRTFTextDocumentType}
                                     documentAttributes:nil
                                                  error:nil].string;
    } else {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
}

+ (void)output:(NSAttributedString *)string to:(NSString *)path {
    NSData *data = [string dataFromRange:NSMakeRange(0, string.length)
                      documentAttributes:@{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType, }
                                   error:nil];
    
    [data writeToFile:path atomically:NO];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [XCColorsCLI loadColors];
        
        NSString *from = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        NSString *to = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
        [XCColorsCLI process:from output:to];
    }
    return 0;
}
