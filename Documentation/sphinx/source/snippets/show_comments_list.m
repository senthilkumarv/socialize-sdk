@interface CreateCommentsList : UIViewController
@end

// begin-snippet

#import <Socialize/Socialize.h>

@implementation CreateCommentsList

- (IBAction)commentsButtonPressed {
    //create an entity that is unique with your application.
    NSString *entityURL = @"http://www.example.com/object/1234";
    
    _SZCommentsListViewController *commentsList = [_SZCommentsListViewController commentsListViewControllerWithEntityKey:entityURL];
    SZNavigationController *nav = [[[SZNavigationController alloc] initWithRootViewController:commentsList] autorelease];
    [self presentViewController:nav animated:YES completion:nil];
}

@end

// end-snippet