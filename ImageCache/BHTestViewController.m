//
//  BHTestViewController.m
//  ImageCache
//
//  Created by Bryan Hansen on 1/20/13.
//  Copyright (c) 2013 skeuo. All rights reserved.
//

#import "BHTestViewController.h"
#import "BHImageCache.h"

@interface BHTestViewController ()

@property (strong, nonatomic) IBOutlet UIImageView *cacheImageView;
@property (strong, nonatomic) IBOutlet UIImageView *downloadImageView;

- (IBAction)downloadImage:(id)sender;

@end

@implementation BHTestViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)downloadImage:(id)sender
{
    CGFloat duration = (self.cacheImageView.image || self.downloadImageView.image) ? 0.35f : 0.0f;
    
    [UIView animateWithDuration:duration animations:^{
        self.cacheImageView.alpha = 0.0f;
        self.downloadImageView.alpha = 0.0f;
        
    } completion:^(BOOL finished) {
        self.cacheImageView.image = nil;
        self.cacheImageView.alpha = 1.0f;
        
        self.downloadImageView.image = nil;
        self.downloadImageView.alpha = 1.0f;
        
        NSURL *url = [NSURL URLWithString:@"https://www.google.com/images/srpr/logo3w.png"];
        
        self.cacheImageView.image = [[BHImageCache sharedCache] imageWithURL:url operationQueue:[NSOperationQueue mainQueue] completionBlock:^(UIImage *image, NSError *error) {
            if (error) {
                NSLog(@"ERROR: %@", error);
                return;
            }
            self.downloadImageView.image = image;
        }];
    }];
}

- (IBAction)clearCache:(id)sender
{
    self.cacheImageView.image = nil;
    self.downloadImageView.image = nil;
    
    [[BHImageCache sharedCache] clearCache];
}

@end
