//
//  PlayViewController.m
//  huizon
//
//  Created by yang Eric on 5/17/14.
//  Copyright (c) 2014 zhaopin. All rights reserved.
//

#import "PlayViewController.h"
#import "MusicListController.h"
#import "JASidePanelController.h"
#import <AVFoundation/AVFoundation.h>

#import "VoiceControls.h"
#import "LeDiscovery.h"
#import "TopControlView.h"

@interface PlayViewController ()<AVAudioPlayerDelegate,LeDiscoveryDelegate, LeTemperatureAlarmProtocol>
{
    AVAudioPlayer *_player;//播放器
    NSTimer *Timer;//计时器
    BOOL     isPlay;
    
    int playIndex;
    
    TopControlView  *topView;
    
    PlayType playMusicType;
}

@property (strong,nonatomic) MusicList *musicArray;

@property (strong,nonatomic) IBOutlet UILabel *lbName;
@property (strong,nonatomic) IBOutlet UILabel *lbAuthor;
@property (strong,nonatomic) IBOutlet UIImageView *imgAlbum;
@property (strong,nonatomic) IBOutlet UIImageView *imgFloat;
@property (strong,nonatomic) IBOutlet UILabel *lbTimeMin;
@property (strong,nonatomic) IBOutlet UILabel *lbTimeMax;
@property (strong,nonatomic) IBOutlet UISlider *slider;
@property (strong,nonatomic) IBOutlet UIButton *btnType;
@property (strong,nonatomic) IBOutlet UIButton *btnPriview;
@property (strong,nonatomic) IBOutlet UIButton *btnNext;
@property (strong,nonatomic) IBOutlet UIButton *btnPlay;

@end

@implementation PlayViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [[LeDiscovery sharedInstance] sendCommand:kBluetoothClose];
    [[VoiceControls voiceSingleton] stopMusic];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.hidden = YES;
    
    topView = [[TopControlView alloc] initWithFrame:CGRectMake(0, 27, 320, 44) nibNameOrNil:nil];
    topView.baseController = self;
    
    [self.view addSubview:topView];
    
    self.imgAlbum.center = CGPointMake(160, theApp.window.frame.size.height/2);
    self.imgFloat.center = CGPointMake(160, theApp.window.frame.size.height/2);
    
    playMusicType = PlayTypeCircle;
    isPlay = NO;
    playIndex = 0;
    [self.view.layer setContents:(id)[IMG(@"play_bg.png") CGImage]];
    
    [self.slider setMinimumTrackTintColor:[UIColor whiteColor]];
    [self.slider setMaximumTrackTintColor:[UIColor colorWithWhite:1.0 alpha:0.8]];
    __block int angle = 0;
    [VoiceControls voiceSingleton].voiceHandler = ^(id acc){
        int currentTime = [[VoiceControls voiceSingleton] musicCurrentTime];
        self.lbTimeMin.text = _S(@"%02d:%02d",currentTime/60,currentTime%60);
        self.slider.value = [[VoiceControls voiceSingleton] musicCurrentTime]/[[VoiceControls voiceSingleton] musicDuration];
        self.imgFloat.transform = CGAffineTransformMakeRotation(angle * (M_PI / 180.0f));
        angle += 2;
        float degree = abs([acc floatValue]);
        int voiceDegree = abs(degree)+1;
        voiceDegree = 40-voiceDegree;
        //        if (currentLevel>0) {
        //            voiceDegree /=currentLevel;
        //        }
        //        else{
        //            currentLevel = 0;
        //        }
        
        
        voiceDegree = voiceDegree<0?0:voiceDegree;
        NSString * myComm = [kBluetoothSpeeds objectAtIndex:voiceDegree];
//        NSLog(@"cmd===%@",myComm);
        ///如果游戏开始，把控制命令发给对方
        if (theApp.currentGamingJid!=nil) {
            [theApp sendControlCode:myComm];
        }
        else{
            [[LeDiscovery sharedInstance] sendCommand:myComm];
        }
        
        
    };
    
    [VoiceControls voiceSingleton].controllHandler= ^(id sender){
        if (playMusicType==PlayTypeSingle) {
            playIndex -= 1;
        }
        [self nextAction:nil];
    };
    
    NSArray *ary = [[NSUserDefaults standardUserDefaults] objectForKey:kMusicLocalKey];
    if (ary) {
        self.musicArray = [[MusicList alloc] initWithArray:ary];
    }
    
    
    
    [self setViewInfo:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTop:) name:kNotificationTop object:nil];
 
    
    [LeDiscovery sharedInstance];

    
    // Do any additional setup after loading the view from its nib.
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshTop:nil];
}

- (void)refreshTop:(NSNotification *)noti
{
    if (noti) {
        NSLog(@"--%@",noti);
    }
    
    [topView refreshTitleName];
}


- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[VoiceControls voiceSingleton] stopMusic];
    isPlay = NO;
    [self playButtonSetImage];
}

- (void)setViewInfo:(BOOL)state
{
    if (self.musicArray.count>0) {
        
        self.musicInfo = [self.musicArray objectAtIndex:playIndex];
        [[VoiceControls voiceSingleton] startMusic:[self musicNamePath]];
        if (state) {
            [[VoiceControls voiceSingleton] playMusicAction];
            isPlay = YES;
            [self playButtonSetImage];
        }
        
        
    }
    self.slider.value = 0;
    self.lbName.text = [self.musicInfo musicName];
    self.lbAuthor.text = [self.musicInfo author];
    self.imgFloat.image = [self musicImageInfo:self.musicInfo.musicPath];
    self.lbTimeMin.text = @"00:00";
    int duration = [[VoiceControls voiceSingleton] musicDuration];
    self.lbTimeMax.text = _S(@"%02d:%02d",duration/60,duration%60);
    self.imgFloat.layer.cornerRadius = 76;
    self.imgFloat.layer.masksToBounds = YES;
}

- (IBAction)playAction:(id)sender
{
    if (!isPlay) {
        [[VoiceControls voiceSingleton] playMusicAction];
        isPlay = YES;
    }
    else{
        [[LeDiscovery sharedInstance] sendCommand:kBluetoothClose];
        [[VoiceControls voiceSingleton] pauseMusic];
        isPlay = NO;
    }
    
    [self playButtonSetImage];
    
}

- (void)playButtonSetImage
{
    if (isPlay) {//playing
        [self.btnPlay setImage:IMG(@"button-pause.png") forState:UIControlStateNormal];
        [self.btnPlay setImage:IMG(@"button-pause-pressed.png") forState:UIControlStateHighlighted];
        [self.btnPlay setImage:IMG(@"button-pause-pressed.png") forState:UIControlStateSelected];
    }
    else{
        [self.btnPlay setImage:IMG(@"button-play.png") forState:UIControlStateNormal];
        [self.btnPlay setImage:IMG(@"button-play-pressed.png") forState:UIControlStateHighlighted];
        [self.btnPlay setImage:IMG(@"button-play-pressed.png") forState:UIControlStateSelected];
    }
}


//地址转换为URL
-(NSURL *)musicNamePath
{
    NSURL *url=nil;
    
    if (self.musicInfo) {
        url=[[NSURL alloc]initFileURLWithPath:self.musicInfo.musicPath];
    }
    
    
    return url;
}

#pragma mark -
#pragma mark Action
- (IBAction)leftAction:(id)sender
{
    [theApp.sidePanelController toggleLeftPanel:nil];
}
- (IBAction)rightAction:(id)sender
{
    [theApp.sidePanelController toggleRightPanel:nil];
}

- (IBAction)openMusicList:(id)sender
{
    IMP_BLOCK_SELF(PlayViewController)
    MusicListController *mvc = [[MusicListController alloc] init];
    mvc.musicHandler = ^(id sender){
//        block_self.musicInfo = (MusicItem *)sender;
        playIndex = [sender intValue];
        isPlay = NO;
        [block_self setViewInfo:YES];
        [block_self playAction:nil];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mvc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark ActionMusic
- (IBAction)typeAction:(id)sender
{
    int type = playMusicType;
    type++;
    type %=3;
    playMusicType = type;
    if (playMusicType==PlayTypeSingle) {
        [self.btnType setImage:IMG(@"button-repeat-one.png") forState:UIControlStateNormal];
        [self.btnType setImage:IMG(@"button-repeat-one-disabled.png") forState:UIControlStateHighlighted];
        [self.btnType setImage:IMG(@"button-repeat-one-disabled.png") forState:UIControlStateSelected];
    }
    else if (playMusicType == PlayTypeCircle){
        [self.btnType setImage:IMG(@"button-repeat.png") forState:UIControlStateNormal];
        [self.btnType setImage:IMG(@"button-repeat-disabled.png") forState:UIControlStateHighlighted];
        [self.btnType setImage:IMG(@"button-repeat-disabled.png") forState:UIControlStateSelected];
    }
    else{
        [self.btnType setImage:IMG(@"button-random.png") forState:UIControlStateNormal];
        [self.btnType setImage:IMG(@"button-random-disabled.png") forState:UIControlStateHighlighted];
        [self.btnType setImage:IMG(@"button-random-disabled.png") forState:UIControlStateSelected];
    }
}
- (IBAction)previewAction:(id)sender
{
    playIndex--;
    if (playIndex<0) {
        playIndex = 0;
    }
    
    if (playMusicType==PlayTypeRandom) {
        playIndex = (arc4random() % self.musicArray.count);
    }
    
    [self playButtonStatus];
}
- (IBAction)nextAction:(id)sender
{
    playIndex++;
    if (playIndex>self.musicArray.count-1) {
        playIndex = self.musicArray.count-1;
    }
    if (playMusicType==PlayTypeRandom) {
        playIndex = (arc4random() % self.musicArray.count);
    }
    
    [self playButtonStatus];
    
}
- (IBAction)slideAction:(id)sender
{
    int currentTime =(self.slider.value)*[[VoiceControls voiceSingleton] musicDuration];
    [[VoiceControls voiceSingleton] setPlayTime:currentTime];
    self.lbTimeMin.text = _S(@"%02d:%02d",currentTime/60,currentTime%60);
    
}

#pragma mark -
#pragma mark Func
- (void)playButtonStatus
{
    isPlay = NO;
    [[VoiceControls voiceSingleton] stopMusic];
    self.btnPriview.enabled = YES;
    self.btnNext.enabled = YES;
    
    if (playIndex>=self.musicArray.count-1) {
        self.btnNext.enabled = NO;
    }
    
    if (playIndex<=0) {
        self.btnPriview.enabled = NO;
    }
    
    [self setViewInfo:YES];
}


- (UIImage *)musicImageInfo:(NSString *)path
{
    UIImage *img = IMG(@"mode-music-front.png");
    
    NSURL *fileUrl=[NSURL fileURLWithPath:path];
    AVURLAsset *mp3Asset=[AVURLAsset URLAssetWithURL:fileUrl options:nil];
    for (NSString *format in [mp3Asset availableMetadataFormats])
    {
        for (AVMetadataItem *metadataItem in [mp3Asset metadataForFormat:format]) {
            NSLog(@"commonKey:%@",metadataItem.commonKey);
            if ([metadataItem.commonKey isEqualToString:@"artwork"]) {
                img =[UIImage imageWithData:[(NSDictionary*)metadataItem.value objectForKey:@"data"]];
            }
        }
    }
    
    return img;
}

- (NSDictionary *)musicAlbum:(NSString *)path
{
    NSMutableDictionary *albumDict = [[NSMutableDictionary alloc] init];
    NSURL * fileURL=[NSURL fileURLWithPath:path];
    NSString *fileExtension = [[fileURL path] pathExtension];
    if ([fileExtension isEqual:@"mp3"]||[fileExtension isEqual:@"m4a"])
    {
        AudioFileID fileID  = nil;
        OSStatus err        = noErr;
        
        err = AudioFileOpenURL( (__bridge CFURLRef) fileURL, kAudioFileReadPermission, 0, &fileID );
        if( err != noErr ) {
            NSLog( @"AudioFileOpenURL failed" );
        }
        UInt32 id3DataSize  = 0;
        err = AudioFileGetPropertyInfo( fileID,   kAudioFilePropertyID3Tag, &id3DataSize, NULL );
        
        if( err != noErr ) {
            NSLog( @"AudioFileGetPropertyInfo failed for ID3 tag" );
        }
        NSDictionary *piDict = nil;
        UInt32 piDataSize   = sizeof( piDict );
        err = AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict );
        if( err != noErr ) {
            NSLog( @"AudioFileGetProperty failed for property info dictionary" );
        }
        CFDataRef AlbumPic= nil;
        UInt32 picDataSize = sizeof(picDataSize);
        err =AudioFileGetProperty( fileID,   kAudioFilePropertyAlbumArtwork, &picDataSize, &AlbumPic);
        if( err != noErr ) {
            NSLog( @"Get picture failed" );
        }
        
        NSString * Album = [(NSDictionary*)piDict objectForKey:
                            [NSString stringWithUTF8String: kAFInfoDictionary_Album]];
        NSString * Artist = [(NSDictionary*)piDict objectForKey:
                             [NSString stringWithUTF8String: kAFInfoDictionary_Artist]];
        NSString * Title = [(NSDictionary*)piDict objectForKey:
                            [NSString stringWithUTF8String: kAFInfoDictionary_Title]];
        
        if (Album) {
            [albumDict setObject:Album forKey:@"album"];
        }
        if (Artist) {
            [albumDict setObject:Artist forKey:@"artist"];
        }
        if (Title) {
            [albumDict setObject:Title forKey:@"title"];
        }
        
        
    }
    return albumDict;
}

- (NSMutableArray *)allFilesAtPath:(NSString *)direString
{
    NSMutableArray *pathArray = [NSMutableArray array];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *tempArray = [fileManager contentsOfDirectoryAtPath:direString error:nil];
    for (NSString *fileName in tempArray) {
        BOOL flag = YES;
        NSString *fullPath = [direString stringByAppendingPathComponent:fileName];
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&flag]) {
            if (!flag) {
                // ignore .DS_Store
                if (![[fileName substringToIndex:1] isEqualToString:@"."] && [fileName hasSuffix:@".mp3"]) {
                    [pathArray addObject:fullPath];
                }
            }
            else {
                [pathArray addObject:[self allFilesAtPath:fullPath]];
            }
        }
    }
    
    return pathArray;
}



@end
