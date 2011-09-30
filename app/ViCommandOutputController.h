#import "ViViewController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : ViViewController
{
}

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content;
- (void)setContent:(NSString *)content;

@end
