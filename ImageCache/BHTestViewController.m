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
    NSURL *url = [NSURL URLWithString:@"http://Icarus.local:4567/images/appstore.png"];
    
    self.cacheImageView.image = [[BHImageCache sharedCache] imageWithURL:url operationQueue:[NSOperationQueue mainQueue] completionBlock:^(UIImage *image, NSError *error) {
        if (error) {
            NSLog(@"ERROR: %@", error);
            return;
        }
        self.downloadImageView.image = image;
    }];
}

- (IBAction)clearImages:(id)sender
{
    self.cacheImageView.image = nil;
    self.downloadImageView.image = nil;
}

@end
