//
//  TBPost.m
//  Tribo
//
//  Created by Carter Allen on 9/25/11.
//  Copyright (c) 2011 Opt-6 Products, LLC. All rights reserved.
//

#import "TBPost.h"
#import "markdown.h"
#import "html.h"
#import "TBError.h"

static NSDateFormatter *dateStringFormatter;
static NSDateFormatter *relativeURLFormatter;

@interface TBPost ()
- (BOOL)parse:(NSError **)error;
- (NSError *)badPostError;
@property (readonly) NSString *dateString;
@property (readonly) NSString *XMLDate;
@property (readonly) NSString *summary;
@property (readonly) NSString *relativeURL;
@end

@implementation TBPost
@synthesize URL=_URL;
@synthesize title=_title;
@synthesize author=_author;
@synthesize date=_date;
@synthesize slug=_slug;
@synthesize markdownContent=_markdownContent;
+ (TBPost *)postWithURL:(NSURL *)URL error:(NSError **)error{
	return (TBPost *)[super pageWithURL:URL inSite:nil error:error];
}
- (NSString *)dateString {
	if (dateStringFormatter == nil) {
		dateStringFormatter = [NSDateFormatter new];
		dateStringFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"dMMMyyyy" options:0 locale:[NSLocale currentLocale]];
	}
	return [dateStringFormatter stringFromDate:self.date];
}
- (NSString *)XMLDate {
	static NSDateFormatter *XMLDateFormatter;
	if (XMLDateFormatter == nil) {
		XMLDateFormatter = [NSDateFormatter new];
		XMLDateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ";
	}
	NSMutableString *mutableDateString = [[XMLDateFormatter stringFromDate:self.date] mutableCopy];
	[mutableDateString insertString:@":" atIndex:mutableDateString.length - 2];
	return mutableDateString;
}
- (NSString *)summary {
	NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
	[self.content getParagraphStart:&paraStart end:&paraEnd contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
	NSRange paragraphRange = NSMakeRange(paraStart, contentsEnd - paraStart);
	return [self.content substringWithRange:paragraphRange];
}
- (NSString *)relativeURL {
	if (relativeURLFormatter == nil) {
		relativeURLFormatter = [NSDateFormatter new];
		relativeURLFormatter.dateFormat = @"/yyyy/MM/dd";
	}
	NSString *directoryStructure = [relativeURLFormatter stringFromDate:self.date];
	return [directoryStructure stringByAppendingPathComponent:self.slug];
}

- (BOOL)parse:(NSError **)error {
	NSMutableString *markdownContent = [NSMutableString stringWithContentsOfURL:self.URL encoding:NSUTF8StringEncoding error:nil];
    if (![markdownContent length]) {
        if (error) {
            *error = [self badPostError];
        }
        return NO;
    }
	
	// Titles are optional.
	// A single # header on the first line of the document is regarded as the title.
	static NSRegularExpression *headerRegex;
	if (headerRegex == nil)
		headerRegex = [NSRegularExpression regularExpressionWithPattern:@"#[ \\t](.*)[ \\t]#" options:0 error:nil];
	NSRange firstLineRange = NSMakeRange(0, [markdownContent rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location);
	NSString *firstLine = [markdownContent substringWithRange:firstLineRange];
	NSTextCheckingResult *titleResult = [headerRegex firstMatchInString:firstLine options:0 range:NSMakeRange(0, firstLine.length)];
	if (titleResult) {
		self.title = [firstLine substringWithRange:[titleResult rangeAtIndex:1]];
		[markdownContent deleteCharactersInRange:NSMakeRange(firstLineRange.location, firstLineRange.length + 1)];
	}
	[markdownContent deleteCharactersInRange:[markdownContent rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]]];
	self.markdownContent = markdownContent;
	
	// Dates are generated by a pattern in the post file name.
	static NSRegularExpression *fileNameRegex;
	if (fileNameRegex == nil)
		fileNameRegex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+-\\d+-\\d+)-(.*)" options:0 error:nil];
	NSString *fileName = [self.URL.lastPathComponent stringByDeletingPathExtension];
	NSTextCheckingResult *fileNameResult = [fileNameRegex firstMatchInString:fileName options:0 range:NSMakeRange(0, fileName.length)];
	if (fileNameResult) {
		static NSDateFormatter *fileNameDateFormatter;
		if (fileNameDateFormatter == nil) {
			fileNameDateFormatter = [NSDateFormatter new];
			fileNameDateFormatter.dateFormat = @"yyyy-MM-dd";
		}
		self.date = [fileNameDateFormatter dateFromString:[fileName substringWithRange:[fileNameResult rangeAtIndex:1]]];
		self.slug = [fileName substringWithRange:[fileNameResult rangeAtIndex:2]];
	}
	
	// Create and fill a buffer for with the raw markdown data.
	if ([markdownContent length] == 0) return YES;
	struct sd_callbacks callbacks;
	struct html_renderopt options;
	const char *rawMarkdown = [markdownContent cStringUsingEncoding:NSUTF8StringEncoding];
	struct buf *inputBuffer = bufnew(strlen(rawMarkdown));
	bufputs(inputBuffer, rawMarkdown);
	
	// Parse the markdown into a new buffer using Sundown.
	struct buf *outputBuffer = bufnew(64);
	sdhtml_renderer(&callbacks, &options, 0);
	struct sd_markdown *markdown = sd_markdown_new(0, 16, &callbacks, &options);
	sd_markdown_render(outputBuffer, inputBuffer->data, inputBuffer->size, markdown);
	sd_markdown_free(markdown);
	
	self.content = [NSString stringWithCString:bufcstr(outputBuffer) encoding:NSUTF8StringEncoding];
	
	bufrelease(inputBuffer);
	bufrelease(outputBuffer);
    return YES;
}
- (NSError *)badPostError{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Could not read any content from the post at %@", [[self URL] lastPathComponent]], NSLocalizedDescriptionKey, [self URL], NSURLErrorKey, nil];
    NSError *contentError = [NSError errorWithDomain:TBErrorDomain code:TBErrorBadContent userInfo:info];
    return contentError;
}
@end