//
//  SJBInputPassengerInfoTableViewController.m
//  Scanning
//
//  Created by du leiming on 12/08/15.
//  Copyright (c) 2015 mushoom. All rights reserved.
//

#import "SJBInputPassengerInfoTableViewController.h"
#import "SJBPassportScanningViewController.h"

@interface SJBInputPassengerInfoTableViewController ()<SJBPassportScanningDelegate>
{
    NSMutableArray *passagerData;
    BOOL isScanned;
}
@end

@implementation SJBInputPassengerInfoTableViewController


- (void)drawView{
    
    
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    //
    NSNumber *value = [NSNumber numberWithInt:UIDeviceOrientationPortrait];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewDidLoad {
    
    
    
    [super viewDidLoad];
    
    passagerData = [NSMutableArray arrayWithObjects:@{@"label":@"姓", @"data":@"如：liu"},
                    @{@"label":@"名", @"data":@"如：lijun"},
                    @{@"label":@"性别", @"data":@""},
                    @{@"label":@"出生日期", @"data":@""},
                    @{@"label":@"国籍", @"data":@""},
                    @{@"label":@"护照号", @"data":@"如：E65123458"},
                    @{@"label":@"有效期", @"data":@"如：101010"},
                    @{@"label":@"本次扫描所用时间", @"data":@""},
                    nil];
    
    
    self.title = @"添加旅客信息";
    
    UIBarButtonItem *scanButton = [[UIBarButtonItem alloc] initWithTitle:@"扫描护照" style:UIBarButtonItemStylePlain target:self action:@selector(launchScanning)];
    self.navigationItem.rightBarButtonItem = scanButton;
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)launchScanning{
    SJBPassportScanningViewController *passportScanning = [[SJBPassportScanningViewController alloc] init];
    passportScanning.delegate = self;
    
    passportScanning.backGroundImageName = @"passport.png";
    passportScanning.scanningLineImageName = @"scan_line.png";
    
    passportScanning.scanningFrameRect = CGRectMake(20.0f, 30.0f, 90.0f, 607.0f);
    passportScanning.scanningLineSize = CGSizeMake(90.0f, 20.0f);
    
    isScanned = NO;
    
    [self presentViewController:passportScanning animated:YES completion:nil];
    passportScanning = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    //#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return [passagerData count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *MyIdentifier = @"MyReuseIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:MyIdentifier];
    }
    
    //Configure the cell...
    NSDictionary *dic = [passagerData objectAtIndex:indexPath.row];
    
    cell.textLabel.text = dic[@"label"];
    cell.detailTextLabel.text = dic[@"data"];
    
    return cell;
}


/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark -
#pragma mark - PassportScanningDelegate
-(void)passportScanningSuccessfull:(SJBPassportScanningViewController *)scanViewController secondName:(NSString *)secondName firstName:(NSString *)firstName sex:(NSString *)sex birthDay:(NSString *)birthDay nation:(NSString *)nation passportNumber:(NSString *)passportNumber valideDate:(NSString *)validDate usedTime:(NSString *)usedTime
{
    
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    
    if (isScanned) {
        return;
    }
    
    isScanned = YES;
    
    [passagerData removeAllObjects];
    
    if (secondName != nil) {
        
        [passagerData addObject:@{@"label":@"姓", @"data":secondName}];
    }
    
    if (firstName != nil) {
        
        [passagerData addObject:@{@"label":@"名", @"data":firstName}];
        
    }
    
    if (sex != nil) {
        
        [passagerData addObject:@{@"label":@"性别", @"data":sex}];
        
        
    }
    
    if (birthDay != nil) {
        
        [passagerData addObject:@{@"label":@"出生日期", @"data":birthDay}];
    }
    
    if (nation != nil) {
        
        [passagerData addObject:@{@"label":@"国籍", @"data":nation}];
    }
    
    if (passportNumber != nil) {
        
        [passagerData addObject:@{@"label":@"护照号", @"data":passportNumber}];
        
    }
    
    if (validDate != nil) {
        
        [passagerData addObject:@{@"label":@"有效期", @"data":validDate}];
    }
    
    if (usedTime != nil) {
        
        [passagerData addObject:@{@"label":@"本次扫描所用时间", @"data":usedTime}];
    }
    
    [self.tableView reloadData];
    
    UIAlertView * alert =[[UIAlertView alloc ] initWithTitle:nil
                                                     message:@"扫描成功，请仔细核对自动填写的内容与护照信息是否一致!"
                                                    delegate:nil
                                           cancelButtonTitle:@"关闭"
                                           otherButtonTitles: nil];
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [alert show];
        
    });
    
    
}

-(void)passportScanningCancelled:(SJBPassportScanningViewController *)scanViewController{
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
