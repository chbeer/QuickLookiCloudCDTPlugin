
#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#include "ZipArchive.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

void AppendNSManagedObjectToHTMLString(NSString *entityName, NSString *primaryKey, NSDictionary *obj, NSMutableString *string) ;


typedef struct {
    BOOL bold, italic, underline, monospace;
    CGFloat fontSize;
} CBNSAttributedStringAttributes;

@interface NSAttributedString (Helper) 
+ (NSAttributedString*) attributedStringWithString:(NSString*)temp attributes:(CBNSAttributedStringAttributes)attributes;
@end



/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    
    @try {

        ZipArchive *zip = [[ZipArchive alloc] init];
    
        if (![zip UnzipOpenFile:[(__bridge NSURL*)url path]]) 
        return noErr;
    
        NSData *data = [zip dataForUnzipFileName:@"contents"];
        if (!data) return noErr;
        
        
        NSDictionary *cdtDictionary =  (__bridge_transfer NSDictionary*)CFPropertyListCreateFromXMLData(kCFAllocatorDefault, (__bridge CFDataRef)data,
                                                                                                        kCFPropertyListImmutable,
                                                                                                        NULL);
        if (!cdtDictionary) return noErr;
        if (![cdtDictionary isKindOfClass:[NSDictionary class]]) {
            return noErr;
        }
        
        NSArray *entityNames = [cdtDictionary valueForKeyPath:@"entityNames"];
        NSArray *primaryKeys = [cdtDictionary valueForKeyPath:@"primaryKeys"];
        
        NSDictionary *deleted = [cdtDictionary valueForKeyPath:@"deleted"];
        NSDictionary *inserted = [cdtDictionary valueForKeyPath:@"inserted"];
        NSDictionary *updated = [cdtDictionary valueForKeyPath:@"updated"];
        
        
        NSMutableString *html = [NSMutableString string];
        [html appendString:@"<body><style type='text/css'>body { style='font-family: monospace;'; margin: 10pt; }\n h1 { font-size:150%; }</style>"];
        
        void(^enumerateAndAppendBlock)(id key, id obj, BOOL *stop) = ^(id key, id obj, BOOL *stop) {
            int entityIndex = [key intValue];
            
            NSString *entityName = [entityNames objectAtIndex:entityIndex];
            NSString *primaryKey  = [primaryKeys objectAtIndex:entityIndex];
            
            AppendNSManagedObjectToHTMLString(entityName, primaryKey, obj, html) ;
        };
        
        if (deleted.count > 0) {
            [html appendString:@"<h1>Deleted</h1>"];
            
            [html appendString:@"<ul>"];
            [deleted enumerateKeysAndObjectsUsingBlock:enumerateAndAppendBlock];
            [html appendString:@"</ul>"];
        }
        
        if (inserted.count > 0) {
            [html appendString:@"<h1>Inserted</h1>"];
            
            [html appendString:@"<ul>"];
            [inserted enumerateKeysAndObjectsUsingBlock:enumerateAndAppendBlock];
            [html appendString:@"</ul>"];
        }
        
        if (updated.count > 0) {
            [html appendString:@"<h1>Updated</h1>"];
            
            [html appendString:@"<ul>"];
            [updated enumerateKeysAndObjectsUsingBlock:enumerateAndAppendBlock];
            [html appendString:@"</ul>"];
        }
        
        [html appendString:@"</body>"];
        
        
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithHTML:[html dataUsingEncoding:NSUTF8StringEncoding]
                                                                         documentAttributes:nil];
        
        
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        
        CFRange fitRange;
        CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, 
                                                                        CGSizeMake(500, CGFLOAT_MAX), 
                                                                        &fitRange);
        
        CGRect contentsRect = CGRectMake(0.0, 0.0, frameSize.width, frameSize.height);
        CGRect pageRect = CGRectInset(contentsRect, -20, -20);    
        CGRect mediaBox = pageRect;
        
        
        CGContextRef ctx = QLPreviewRequestCreatePDFContext(preview, &mediaBox, NULL, NULL);
        if(ctx) {
            
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathAddRect(path, NULL, contentsRect);
            
            CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), 
                                                         nil, contentsRect.size, &fitRange);
            
            CGPDFContextBeginPage(ctx, NULL); 
            
            CTFrameRef frame = CTFramesetterCreateFrame(framesetter, fitRange, path, NULL);
            
            CTFrameDraw(frame, ctx);
            
            CFRelease(frame);
            
            CGPDFContextEndPage(ctx);
            
            
            CFRelease(path);            
            
            
            // When we are done with our drawing code QLPreviewRequestFlushContext() is called to flush the context
            QLPreviewRequestFlushContext(preview, ctx);
            
            CFRelease(ctx);
        }
        
        CFRelease(framesetter);

    } @catch (NSException *exception) {
        NSLog(@"!! Exception: %@", exception);
        return noErr;
    }
    
    // no step 3
    
    return noErr;
}


void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}


void AppendNSManagedObjectToHTMLString(NSString *entityName, NSString *primaryKey, NSDictionary *obj, NSMutableString *string)
{
    [string appendFormat:@"<li><b>%@</b>/%@ <ul>", entityName, primaryKey];
    
    __block BOOL first = YES;
    [obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [string appendFormat:@"<li>%@: <i>%@</i></li>", key, obj];
        first = NO;
    }];
    
    [string appendString:@"</ul>"];
}
