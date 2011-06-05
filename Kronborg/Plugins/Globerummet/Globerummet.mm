#import "Globerummet.h"
#include "Keystoner.h"

#include <sys/sysctl.h> 

#define V @"1.90"

@implementation Globerummet

@synthesize loadedFiles;

-(void) log:(NSString*)str{
	NSFileHandle *output ;//  
	output = [NSFileHandle fileHandleForWritingAtPath:[[NSString stringWithFormat:@"~/Dropbox/GlobusFælles/globus%ilog.log",PropI(@"machine")] stringByExpandingTildeInPath]];
	NSString * message = [NSString stringWithFormat:@"%@: %@\n",[NSDate date], str];
	[output seekToEndOfFile];
	[output writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
	
	[output closeFile];	
}

-(NSDate*) boottime{
	int mib[2] = { CTL_KERN, KERN_BOOTTIME }; 
	char *value; 
	size_t size; 
	struct timeval boottime; 
	
	if (sysctl(mib, 2, NULL, &size, NULL, 0) == -1) { 
		perror("sysctl(kern.boottime)"); 
	} 
	if (size < sizeof(boottime)) { 
		perror("sizeof(kern.boottime) < sizeof(timeval)"); 
	} 
	value = (char *)malloc(size); 
	if (value == NULL) { 
		perror("malloc"); 
	} 
	if (sysctl(mib, 2, value, &size, NULL, 0) == -1) { 
		perror("sysctl(kern.boottime)"); 
	} 
	memcpy(&boottime, value, sizeof(boottime)); 
	printf("system boot time (seconds since epoch): %d\n", 
		   boottime.tv_sec); 
	
	NSDate * time = [NSDate dateWithTimeIntervalSince1970:(int)boottime.tv_sec];
	return time;
}

- (void) receiveShutdownNote: (NSNotification*) note
{
	[self log:@"Computer will shutdown now!"];
    NSLog(@"receiveShutdownNote: %@", [note name]);
	
	if(PropI(@"machine") == 1){
		NSDictionary* errorDict;
		NSAppleEventDescriptor* returnDescriptor = NULL;

		NSAppleScript*  scriptObject= [[NSAppleScript alloc] initWithSource:
									   [NSString stringWithFormat:
										@"tell application \"sluk\" to run"] 
									   ];					
		returnDescriptor = [scriptObject executeAndReturnError: &errorDict];	
	}	
}


-(void) initPlugin{	
	[self addProperty:[BoolProperty boolPropertyWithDefaultvalue:0] named:@"userbutton"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:4] named:@"machine"];

	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"fade"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"fadeTo"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:12] named:@"fadeToVideo"];	

	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:2] named:@"spherize"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1 minValue:1 maxValue:2] named:@"scale"];	
	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus1maskx"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus1masky"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus2maskx"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus2masky"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus2maskz"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus2maskz2"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus3maskx"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"globus3masky"];	
	
	lastFramesVideo = 0;
	whiteFlash = 0;
	forceDrawNextFrame = NO;
	
	timecodeSetterTimer = [[NSDate date] retain];
	
	
	testCounter = 0;
	[testButton setContinuous:YES];
	[testButton setState:NSOnState];

		
	arduino = [[[ArduinoController alloc] init] retain];
	[arduino setDelegate:self];
	
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
														   selector: @selector(receiveShutdownNote:) 
															   name: NSWorkspaceWillPowerOffNotification object: NULL];
}

//
//-----
//

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	if(context != nil){
		if([(NSString*) context isEqualToString:@"button"]){
			[Prop(@"userbutton") setIntValue:[[object objectForKey:@"value"] intValue]];
		}
		if([(NSString*) context isEqualToString:@"power"] && [[object objectForKey:@"value"] intValue]){
			[self sleepComputer];
		}
	}
	
	/*if([keyPath isEqualToString:@"isConnected"]){
	 if([bsender[2] isConnected]){
	 [networkConnectionImage1 setImage:[NSImage imageNamed:@"tick"]];
	 [networkConnectionText1 setStringValue:@"Globus2 forbundet"];
	 [self log:@"Globus2 korrekt forbundet"];
	 } else {
	 [networkConnectionImage1 setImage:[NSImage imageNamed:@"cross"]];	
	 [networkConnectionText1 setStringValue:@"Globus2 net-fejl"];
	 [self log:@"!!!!!!!!!!!!!!!  Globus2 forbindelsesfejl  !!!!!!!!!!!!!!! "];
	 }
	 
	 if([bsender[3] isConnected]){
	 [networkConnectionImage2 setImage:[NSImage imageNamed:@"tick"]];
	 [networkConnectionText2 setStringValue:@"Globus3 forbundet"];
	 [self log:@"Globus3 korrekt forbundet"];
	 } else {
	 [networkConnectionImage2 setImage:[NSImage imageNamed:@"cross"]];	
	 [networkConnectionText2 setStringValue:@"Globus3 net-fejl"];			
	 [self log:@"!!!!!!!!!!!!!!!  Globus3 forbindelsesfejl  !!!!!!!!!!!!!!! "];
	 }
	 }*/
}

//
//-----
//

/*
-(void) receiveMessage:(id)message tag:(int)tag{
	if(tag == 0){
		//Timecode
        QTMovie * movie = [videoPlayer getCurrentMovie];
		long long val = [message longLongValue] + double([movie currentTime].timeScale) * 0.1 ;
		//			float t = msg.getArgAsFloat(0)+40;
		//			if(PropI(@"video") != msg.getArgAsInt32(1) && PropF(@"fade") == 0)
		//				[Prop(@"video") setIntValue: msg.getArgAsInt32(1)];
		
		timecodeDifference = [movie currentTime].timeValue - val;
		if(fabs(timecodeDifference / double([movie currentTime].timeScale)) > 0.07){
			[movie setCurrentTime:QTMakeTime(val, [movie currentTime].timeScale)];
		}			
	}
	
	if(tag == 1){
		if(PropI(@"video") != [message intValue] && PropF(@"fade") == 0)
			[Prop(@"video") setIntValue: [message intValue]];
	}
	
	if(tag == 2){
		[Prop(@"fadeToVideo") setIntValue: [message intValue]];
		[Prop(@"fadeTo") setIntValue:1];
		[Prop(@"fade") setIntValue:0];
		
	}
}*/

//
//-----
//

-(void) sendTimecode{
	//dispatch_async(dispatch_get_main_queue(), ^{			
	{
		//		[bsender[2] sendMessage:[NSNumber numberWithLongLong:[movie[int(PropF(@"video"))] currentTime].timeValue] tag:0];
		//		[bsender[3] sendMessage:[NSNumber numberWithLongLong:[movie[int(PropF(@"video"))] currentTime].timeValue] tag:0];
		
		
        /*
		ofxOscMessage m2;
		m2.setAddress( "/video/time" );
		m2.addFloatArg([movie[int(PropF(@"video"))] currentTime].timeValue);
		m2.addIntArg(PropI(@"video"));
		
		osender[3]->sendMessage( m2);
		//});
		
		
		ofxOscMessage m;
		m.setAddress( "/video/time" );
		m.addFloatArg([movie[int(PropF(@"video"))] currentTime].timeValue);
		m.addIntArg(PropI(@"video"));
		
		
		osender[2]->sendMessage( m );
		*/
		
	}
	{
		//dispatch_async(dispatch_get_main_queue(), ^{			
		//	[bsender[2] sendMessage:[NSNumber numberWithInt:PropI(@"video")] tag:1];
		//	[bsender[3] sendMessage:[NSNumber numberWithInt:PropI(@"video")] tag:1];
		//});
	}
	
	[timecodeSetterTimer release];
	timecodeSetterTimer = [[NSDate date] retain];
}

//
//-----
//

-(void) setRemoteVideos:(int) video{
/*	ofxOscMessage m;
	m.setAddress( "/video/video" );
	m.addIntArg(PropI(@"video"));
	osender[2]->sendMessage( m );
	
	ofxOscMessage m2;
	m2.setAddress( "/video/video" );
	m2.addIntArg(PropI(@"video"));
	
	osender[3]->sendMessage( m2 );	*/
}



//
//-----
//

-(IBAction) restart:(id)sender{
    [videoPlayer setCurrentMovie:1];
    QTMovie * movie = [videoPlayer getCurrentMovie];
	[movie setCurrentTime:QTMakeTime(0, 60)];	
}

//
//-----
//

-(IBAction) testButton:(id)sender{
	if ([sender state] == NSOnState) {
		if (testCounter == 0) {
			[Prop(@"userbutton") setBoolValue:YES];
			[globusButtonText setStringValue:@"Globus test"];
			testCounter ++;
		}
	}
	if ([sender state] == NSOffState) {
		testCounter = 0;
		[testButton setState:NSOnState];
		[Prop(@"userbutton") setBoolValue:NO];
		[globusButtonText setStringValue:@"Globus ikke trykket ned"];
	}
}

//
//-----
//

-(void)dealloc {
    [super dealloc];
}

//
//-----
//

- (void) applicationWillTerminate: (NSNotification *)note{

	[self log:@"€€€€€€€€€€€€€€€€  Stop Globus  €€€€€€€€€€€€€€€€€"];
	
}

//
//-----
//

-(void) setLocalVideo:(NSNumber*)video{
	[videoPlayer setCurrentMovie:[video intValue]];	
}

//
//-----
//

-(void) setFadeTo:(NSNumber*)val{
	[Prop(@"fadeTo") setValue:val];
}

//
//-----
//

-(void) arduinoTimeout{
	[self log:@"Arduino timeout"];
	NSLog(@"Arduino timeout");
}


-(void) sleepComputer{
	NSDictionary* errorDict;
	NSAppleEventDescriptor* returnDescriptor = NULL;
	
		
	NSLog(@"Globus2 and 3 are not reachable. Shutting down");
	
	
	NSAppleScript*  scriptObject= [[NSAppleScript alloc] initWithSource:
								   [NSString stringWithFormat:
									@"tell application \"sluk\" to run"] 
								   ];					
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];	
	
	
	scriptObject= [[NSAppleScript alloc] initWithSource:
				   [NSString stringWithFormat:
					@"tell application \"Finder\" to shut down"] 
				   ];					
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];	
	
	/*
	ofxOscMessage m2;
	m2.setAddress( "/shutdown/now" );
	osender[3]->sendMessage( m2);
	
	ofxOscMessage m;
	m.setAddress( "/shutdown/now" );
	osender[2]->sendMessage( m);
	
	*/
}


//
//-----
//

+ (NSString *)computerName
{
	CFStringRef name;
	NSString *computerName;
	name=SCDynamicStoreCopyComputerName(NULL,NULL);
	computerName=[NSString stringWithString:(NSString *)name];
	CFRelease(name);
	return computerName;
}


//
//-----
//

-(BOOL) willDraw:(NSMutableDictionary *)drawingInformation{	
//	if(forceDrawNextFrame){
//		forceDrawNextFrame = NO;
//		return YES;
//	}
//	
//	if([videoPlayer getCurrentMovieIndex] >= 1){
//		QTVisualContextTask(textureContext[PropI(@"video")]);
//		
//		if([movie[int(PropF(@"video"))] rate] != 1)
//			dispatch_async(dispatch_get_main_queue(), ^{				
//				[movie[int(PropF(@"video"))] setRate:1]; 
//			});
//		
//		const CVTimeStamp * outputTime;
//		[[drawingInformation objectForKey:@"outputTime"] getValue:&outputTime];
//		if(textureContext[int(PropF(@"video"))] != nil)
//			return QTVisualContextIsNewImageAvailable(textureContext[int(PropF(@"video"))], outputTime);
//	}
	return NO;	
}

//
//-----
//

-(void) setup{	
    videoPlayer = GetPlugin(VideoPlayer);
    
	lastMsgDate = [NSDate date];

	NSLog(@"Setup start");
	//[[[[globalController viewManager] glViews] lastObject] setBackingWidth:400 height:400];

    [videoPlayer setCurrentMovie:1];
	[Prop(@"fade") setFloatValue:0];
	[Prop(@"fadeTo") setFloatValue:0];
	[Prop(@"fadeToVideo") setFloatValue:0];	
	[Prop(@"userbutton") setFloatValue:0];

	if([[Globerummet computerName] isEqualToString:@"halfdanj"]){
		[Prop(@"machine") setIntValue:1];
		[bigLabel setStringValue:@"HalfdanJ \nTest Computer"];
	}
	else if([[Globerummet computerName] isEqualToString:@"globus1"]){
		[Prop(@"machine") setIntValue:1];
		[bigLabel setStringValue:@"Globus 1 \nGlobusprojektion, lys, lyd og knap"];
	}
	else if([[Globerummet computerName] isEqualToString:@"globus2"]){
		[Prop(@"machine") setIntValue:2];
		[bigLabel setStringValue:@"Globus 2 \nGulvprojektion"];
	}
	else if([[Globerummet computerName] isEqualToString:@"globus3"]){
		[Prop(@"machine") setIntValue:3];
		[bigLabel setStringValue:@"Globus 3 \nVægprojektion"];
	} else {
		[Prop(@"machine") setIntValue:2];
		
		NSLog(@"PROBLEM: Could not understand the computername: %@, should be globus1, globus2 or globus3. Set it in Deling in Systemindstillinger",[Globerummet computerName]);
	}
	
	NSFileHandle *output ;
	output = [NSFileHandle fileHandleForWritingAtPath:[[NSString stringWithFormat:@"~/Dropbox/GlobusFælles/globus%ilog.log",PropI(@"machine")] stringByExpandingTildeInPath]];
	[output seekToEndOfFile];
	[output writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[self log:[NSString stringWithFormat:@"################  Start Globus %i ################# ",PropI(@"machine")]];	
	[self log:[NSString stringWithFormat:@"Version: %@",V]];	
	[self log:[NSString stringWithFormat:@"Computer boot time: %@",[self boottime]]];	
	
	
	if(PropF(@"machine") <= 1){		
		[arduino setup];
		[[arduino property:0] setObject:[NSNumber numberWithFloat:-1] forKey:@"pollInterval"];
		[[arduino property:1] setObject:[NSNumber numberWithFloat:-1] forKey:@"pollInterval"];
		
		[[arduino property:2] setObject:[NSNumber numberWithFloat:0.05] forKey:@"pollInterval"];
		[[arduino property:3] setObject:[NSNumber numberWithFloat:0.4] forKey:@"pollInterval"];
		
		[[arduino property:2] addObserver:self forKeyPath:@"value" options:nil context:@"button"];
		[[arduino property:3] addObserver:self forKeyPath:@"value" options:nil context:@"power"];
		
		[arduinoConnectionImage setHidden:NO];
		[arduinoConnectionText setHidden:NO];
		
		if([arduino connected]){
			[arduinoConnectionImage setImage:[NSImage imageNamed:@"tick"]];
			[self log:@"Arduino forbundet"];
			
		} else {
			[arduinoConnectionText setStringValue:@"Ikke forbundet"];	
			[self log:@"!!!!!!!!!!!!!!!  Arduino forbindelsesfejl  !!!!!!!!!!!!!!! "];
			
		}	
	
		[self setRemoteVideos:0];		
	} else {
//		oreceiver = new ofxOscReceiver();
//		oreceiver->setup(1234);
//		
		[styringbox setHidden:YES];
		[kalibbox setHidden:YES];
	}	
	
	dispatch_async(dispatch_get_main_queue(), ^{	
		// /600
		keys[0][0] = @"0:0:0:06.10/600";
		keys[0][1] = @"0:0:0:010.00/600";
		
		if(NUMVIDEOS > 1){
			keys[1][0] = @"0:0:0:00.02/600";
			keys[1][1] = @"0:0:0:04.23/600";		
			
			keys[2][0] = @"0:0:0:22.00/600";
			keys[2][1] = @"0:0:0:24.22/600";
			
			keys[3][0] = @"0:0:0:18.05/600";
			keys[3][1] = @"0:0:0:19.15/600";
			
			keys[4][0] = @"0:0:0:26.17/600";
			keys[4][1] = @"0:0:0:30.01/600";
			
			keys[5][0] = @"0:0:0:38.16/600";
			keys[5][1] = @"0:0:0:41.18/600";
			
			keys[6][0] = @"0:0:0:42.22/600";
			keys[6][1] = @"0:0:0:44.16/600";
			
			keys[7][0] = @"0:0:0:46.21/600";
			keys[7][1] = @"0:0:0:49.05/600";
			
			keys[8][0] = @"0:0:0:50.23/600";
			keys[8][1] = @"0:0:0:54.00/600";
			
			keys[9][0] = @"0:0:1:08.21/600";
			keys[9][1] = @"0:0:1:12.06/600";
			
			keys[10][0] =@"0:0:1:04.17/600";
			keys[10][1] =@"0:0:1:07.11/600";
			
			keys[11][0] =@"0:0:1:00.19/600";
			keys[11][1] =@"0:0:1:03.09/600";
		}
		postTimeBuffer = @"0:0:00:01.00/600";
		
		
		NSError * error = nil;			
		
		NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
									  [NSNumber numberWithBool:NO], QTMovieLoopsAttribute, nil];		
		
		if(PropF(@"machine") != 1){
			//		[dict setObject:[NSNumber numberWithBool:YES] forKey:QTMovieOpenForPlaybackAttribute];
		} else {
			[dict setObject:[NSNumber numberWithBool:YES] forKey:QTMovieEditableAttribute];
			
		}
		
		NSString * basePath = [@"~/Movies/" stringByExpandingTildeInPath];
		
		maske = new ofImage();
		maske->loadImage([[NSString stringWithFormat:@"%@%@",basePath,@"/maske.png"] UTF8String]);
		flashImage = new ofImage();
		flashImage->loadImage([[NSString stringWithFormat:@"%@%@",basePath,@"/flash.png"] UTF8String]);
		
		
		for(int i=0;i<NUMVIDEOS;i++){
			
			NSString * fileNumber;
			if(i<10)
				fileNumber = [NSString stringWithFormat:@"0%i",i];
			else
				fileNumber = [NSString stringWithFormat:@"%i",i]; 
			
			[dict setObject:[NSString stringWithFormat:@"%@/%i-%@.mov",basePath, PropI(@"machine")-1,fileNumber] forKey:QTMovieFileNameAttribute];
			movie[i] = [[QTMovie alloc] initWithAttributes:dict error:&error];
			
			
			if(error != nil){ 
				NSLog(@"ERROR: Could not load movie %i: %@ path: %@",i,error, [dict objectForKey:QTMovieFileNameAttribute]);
				[self log:[NSString stringWithFormat:@"!!!!!!!!!!!!!!!  Kunne ikke loade film %i %@ !!!!!!!!!!!!!!! ",i, [dict objectForKey:QTMovieFileNameAttribute]]];
				
				[dict setObject:[NSString stringWithFormat:@"%@/404.mov",basePath] forKey:QTMovieFileNameAttribute];
				movie[i] = [[QTMovie alloc] initWithAttributes:dict error:&error];		
				
				[loadedFilesController addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:i],@"number",
												  @"404.mov",@"name",
												  @"",@"size",
												  @"", @"codec",
												  QTStringFromTime([movie[i] duration]),@"duration",
												  nil]];				
			} else {
				char codecType[5];
				OSType codecTypeNum;
				NSString *codecTypeString = nil;
				
				
				ImageDescriptionHandle videoTrackDescH =(ImageDescriptionHandle)NewHandleClear(sizeof(ImageDescription));				
				
				GetMediaSampleDescription([[[[movie[i] tracks] lastObject] media] quickTimeMedia], 1,
										  (SampleDescriptionHandle)videoTrackDescH);
				bzero(codecType, 5);           
                memcpy((void *)&codecTypeNum, (const void *)&((*(ImageDescriptionHandle)videoTrackDescH)->cType), 4);
                codecTypeNum = EndianU32_LtoB( codecTypeNum );
                memcpy(codecType, (const void*)&codecTypeNum, 4);
                codecTypeString = [NSString stringWithFormat:@"%s", codecType];
				if([codecTypeString isEqualToString:@"jpeg"]){
					codecTypeString = @"JPEG";
				} 
				if([codecTypeString isEqualToString:@"avc1"]){
					codecTypeString = @"H.264";
				} 
				
				[loadedFilesController addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:i],@"number",
												  [NSString stringWithFormat:@"%i-%@.mov", PropI(@"machine")-1,fileNumber],@"name",
												  [NSString stringWithFormat:@"%dx%d",(*(ImageDescriptionHandle)videoTrackDescH)->width,(*(ImageDescriptionHandle)videoTrackDescH)->height],@"size",
												  codecTypeString, @"codec",
												  QTStringFromTime([movie[i] duration]),@"duration",
												  nil]];
				
				NSLog(@"Loaded %@",[NSString stringWithFormat:@"%@/%i-%@.mov",basePath, PropI(@"machine")-1,fileNumber]);
				
				DisposeHandle((Handle)videoTrackDescH);			
			}
			[movie[i] retain];
			
			if(PropF(@"machine") == 1){
				//Load activate sound
				NSString * fileNumber;
				if(i<10)
					fileNumber = [NSString stringWithFormat:@"0%i",i];
				else
					fileNumber = [NSString stringWithFormat:@"%i",i]; 
				
				[dict setObject:[NSString stringWithFormat:@"%@/%@_button.aif",basePath,fileNumber] forKey:QTMovieFileNameAttribute];
				activateSound[i] = [[QTMovie alloc] initWithAttributes:dict error:&error];
				if(error != nil){ 
					NSLog(@"ERROR: Could not load audio button: %@ path: %@",error, [dict objectForKey:QTMovieFileNameAttribute]);
				} else {
					[activateSound[i] setVolume:0.065];
					[activateSound[i] retain];
					[activateSound[i] stop];
					[activateSound[i] setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];										
				}				
				
				//Load audio
				QTMovie * audioMovie = [[QTMovie movieWithFile:[NSString stringWithFormat:@"%@/%i-%@.aif",basePath, PropI(@"machine")-1,fileNumber] error:nil] autorelease];
				if(audioMovie){
					NSLog(@"Found audio for %i", PropI(@"machine"));
					NSArray *audioTracks = [audioMovie tracksOfMediaType:QTMediaTypeSound];
					QTTrack *audioTrack = nil;
					if( [audioTracks count] > 0 )
					{
						audioTrack = [audioTracks objectAtIndex:0];
					}
					
					if( audioTrack )
					{
						QTTimeRange totalRange;
						totalRange.time = QTZeroTime;
						if([movie[i] duration].timeValue > [audioMovie duration].timeValue){
							totalRange.duration = [[audioMovie attributeForKey:QTMovieDurationAttribute] QTTimeValue];
						} else {
							totalRange.duration = [[movie[i] attributeForKey:QTMovieDurationAttribute] QTTimeValue];
						}
						[movie[i] insertSegmentOfTrack:[audioTrack retain] timeRange:totalRange atTime:QTZeroTime];
						//						[movie[i] setVolume:0.035];
						[movie[i] setVolume:0.15];
					}					
				}
			}
		}
		
		for(int i=0;i<NUMVIDEOS;i++){
			
			[movie[i] stop];
			[movie[i] gotoBeginning];
			//	[movie[i] setIdling:NO];
			[movie[i] setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];
			
			QTOpenGLTextureContextCreate(kCFAllocatorDefault,								
										 CGLContextObj(CGLGetCurrentContext()),		// the OpenGL context
										 CGLGetPixelFormat(CGLGetCurrentContext()),
										 nil,
										 &textureContext[i]);
			//SetMovieVisualContext([movie[i] quickTimeMovie], textureContext[i]);			
			[movie[i] setVisualContext:textureContext[i]];
			
		}
		
		[movie[0] setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
		[movie[0] play];
		[movie[0] setRate:1.0];
		//[movie[0] setVisualContext:textureContext[0]];
		//				[movie[0] setIdling:YES];
	});	
	NSLog(@"Setup done");
}

//
//-----
//



-(void) update:(NSDictionary *)drawingInformation{		
	int i= PropI(@"video");	
	framerateAvg.push_back(ofGetFrameRate());
	if(framerateAvg.size() > 200)
		framerateAvg.erase(framerateAvg.begin());
	
	float avg;
	for(int i=0;i<framerateAvg.size();i++){
		avg += framerateAvg[i];
	}
	avg /= framerateAvg.size();
	
	lowFramerateCounter--;	
	lowFramerateCounter = ofClamp(lowFramerateCounter, 0, 2000);
	
	
	if(lastMsgDate != nil && [lastMsgDate timeIntervalSinceNow] < -60 && PropF(@"machine") > 1){
		[self log:[NSString stringWithFormat:@"No messages, will restart osc. Last msg was at %@",avg, lastMsgDate]];
		NSLog(@"Restart OSC");
		lastMsgDate = [NSDate date];

		NSAppleEventDescriptor* returnDescriptor = NULL;
		 NSDictionary* errorDict;
		 
		 NSAppleScript*  scriptObject= [[NSAppleScript alloc] initWithSource:
		 [NSString stringWithFormat:
		 @"tell application \"Finder\" to restart"] 
		 ];					
		 returnDescriptor = [scriptObject executeAndReturnError: &errorDict];	
		/*
		if(oreceiver)
			delete oreceiver;
		oreceiver = new ofxOscReceiver();
		oreceiver->setup(1234);
		
		 */
		
	}
	
	if(avg < 15 && framerateAvg.size() > 190 && lowFramerateCounter == 0){
		[self log:[NSString stringWithFormat:@"Low avg framerate: %f",avg]];
		cout<<"Low framerate"<<endl;
		lowFramerateCounter = 1000;
	}
	
	if(PropF(@"machine") <= 1){
		//HOST
		
		if(PropF(@"userbutton")){// || ofRandom(0, 1) < 0.01){
			//Button is pressed
			if(PropF(@"video") == 0){
				//We are in video 0
				for(int u=0;u<NUMVIDEOS-1;u++){					
					if([movie[0] currentTime].timeValue > QTTimeFromString(keys[u][0]).timeValue && [movie[0] currentTime].timeValue < QTTimeFromString(keys[u][1]).timeValue + QTTimeFromString(postTimeBuffer).timeValue){	
						//We are in a period where we can press the button
						/*	if(PropF(@"latency") > 0){
						 dispatch_async(dispatch_get_main_queue(), ^{											
						 [self performSelector:@selector(setLocalVideo:) withObject:[NSNumber numberWithInt:u+1] afterDelay:PropF(@"latency")];						
						 });
						 } else {*/
						[self setLocalVideo:[NSNumber numberWithInt:u+1]];
						i = u+1;
						//						}
						
						//Set the remote to that video aswell
						[self setRemoteVideos:u+1];
						
						[activateSound[u+1] gotoBeginning];
						[activateSound[u+1] play];
						
						[Prop(@"userbutton") setBoolValue:NO];
						
						[self log:@"Button pressed"];
						NSLog(@"Button pressed");						
					}
				}
			}					
		}	
		
		//Host receives OSC message
		
		//Send timecode to clients
		if(-[timecodeSetterTimer timeIntervalSinceNow] > 1){
			[self sendTimecode];
		}
		
		
		//
		//Light
		//
		float lightSpeed = PropF(@"lightSpeed")*0.02*60.0/ofGetFrameRate();
		if(PropF(@"light") < PropF(@"lightGoal")){
			[Prop(@"light") setFloatValue:PropF(@"light") + lightSpeed];
			if(PropF(@"light") > PropF(@"lightGoal"))
				[Prop(@"light") setFloatValue:PropF(@"lightGoal")];			
		}
		if(PropF(@"light") > PropF(@"lightGoal")){
			[Prop(@"light") setFloatValue:PropF(@"light") - lightSpeed];
			if(PropF(@"light") < PropF(@"lightGoal"))
				[Prop(@"light") setFloatValue:PropF(@"lightGoal")];			
		}
		
		lightSpeed = PropF(@"light2Speed")*0.02*60.0/ofGetFrameRate();
		if(PropF(@"light2") < PropF(@"light2Goal")){
			[Prop(@"light2") setFloatValue:PropF(@"light2") + lightSpeed];
			if(PropF(@"light2") > PropF(@"light2Goal"))
				[Prop(@"light2") setFloatValue:PropF(@"light2Goal")];			
		}
		if(PropF(@"light2") > PropF(@"light2Goal")){
			[Prop(@"light2") setFloatValue:PropF(@"light2") - lightSpeed];
			if(PropF(@"light2") < PropF(@"light2Goal"))
				[Prop(@"light2") setFloatValue:PropF(@"light2Goal")];			
		}
		
		//
		//
		//
		
	}else {
		//Client
		while( oreceiver->hasWaitingMessages() )
		{
			lastMsgDate = [NSDate date];
			NSLog(@"resc");
			// get the next message
			ofxOscMessage m;
			oreceiver->getNextMessage( &m );
			
			if ( m.getAddress() == "/shutdown/now" ){
				NSAppleEventDescriptor* returnDescriptor = NULL;
				NSDictionary* errorDict;
				
				NSAppleScript*  scriptObject= [[NSAppleScript alloc] initWithSource:
											   [NSString stringWithFormat:
												@"tell application \"Finder\" to shut down"] 
											   ];					
				returnDescriptor = [scriptObject executeAndReturnError: &errorDict];	
				
			} else if ( m.getAddress() == "/video/time" ){
				
				
				float val = m.getArgAsFloat(0) + double([movie[[Prop(@"video") intValue]] currentTime].timeScale) * 0.1 ;
				//			float t = msg.getArgAsFloat(0)+40;
				//			if(PropI(@"video") != msg.getArgAsInt32(1) && PropF(@"fade") == 0)
				//				[Prop(@"video") setIntValue: msg.getArgAsInt32(1)];
				
				timecodeDifference = [movie[[Prop(@"video") intValue]] currentTime].timeValue - val;
				if(fabs(timecodeDifference / double([movie[[Prop(@"video") intValue]] currentTime].timeScale)) > 0.07){
					[movie[[Prop(@"video") intValue]] setCurrentTime:QTMakeTime(val, [movie[[Prop(@"video") intValue]] currentTime].timeScale)];
				}			
				
				
				//if(tag == 1){
				if(PropI(@"video") != m.getArgAsInt32(1) && PropF(@"fade") == 0)
					[Prop(@"video") setIntValue:  m.getArgAsInt32(1)];
				//			}
			} else if ( m.getAddress() == "/video/video" ){
				
				[Prop(@"fadeToVideo") setIntValue: m.getArgAsInt32(0)];
				[Prop(@"fadeTo") setIntValue:1];
				[Prop(@"fade") setIntValue:0];
			}
		}			
	}
	
	
	//White flash
	if(whiteFlash > 0 && ofGetFrameRate() > 20)
		whiteFlash -= 0.04*60.0/ofGetFrameRate();	
	whiteFlash = MAX(0,whiteFlash);
	
	
	if(PropF(@"fadeTo") != PropF(@"fade")){
		int dir = 1;
		if(PropF(@"fadeTo") < PropF(@"fade"))
			dir = -1;
		
		[Prop(@"fade") setFloatValue:PropF(@"fade")+dir*0.02*60.0/ofGetFrameRate()];
		
		if(dir == 1 && PropF(@"fadeTo") < PropF(@"fade")){
			//Gone to complete fade down goal
			[Prop(@"fade") setFloatValue:PropF(@"fadeTo")];
			[Prop(@"video") setFloatValue:PropF(@"fadeToVideo")];
			dispatch_async(dispatch_get_main_queue(), ^{											
				[self performSelector:@selector(setFadeTo:) withObject:[NSNumber numberWithInt:0] afterDelay:2];
			});
		}
		
		if(dir == -1 && PropF(@"fadeTo") > PropF(@"fade")){
			//Gone to complete fade up goal
			[Prop(@"fade") setFloatValue:PropF(@"fadeTo")];
		}
	}
	
	if(lastLightTime.timeValue < [movie[i] currentTime].timeValue){
		QTTimeRange timeRange;
		timeRange.time = lastLightTime;
		timeRange.duration = QTTimeDecrement([movie[i] currentTime], lastLightTime);
		for(NSDictionary * dict in [lightCues objectAtIndex:i]){
			if(QTTimeInTimeRange( QTTimeFromString([dict objectForKey:@"time"]), timeRange)){
				int light = [[dict valueForKey:@"light"] intValue];
				if(light & 1){
					[Prop(@"lightSpeed") setFloatValue:[[dict valueForKey:@"speed"] floatValue]];
					[Prop(@"lightGoal") setFloatValue:[[dict valueForKey:@"value"] floatValue]];
				}	
				if(light & 2){
					[Prop(@"light2Speed") setFloatValue:[[dict valueForKey:@"speed"] floatValue]];
					[Prop(@"light2Goal") setFloatValue:[[dict valueForKey:@"value"] floatValue]];
				}				
			}
		}
	}
	lastLightTime = [movie[i] currentTime];
	
	
	// check for new frame
	const CVTimeStamp * outputTime;
	[[drawingInformation objectForKey:@"outputTime"] getValue:&outputTime];
	QTVisualContextTask(textureContext[PropI(@"video")]);
	
	
	if(movie[i] != nil){
		if(lastFramesVideo != i){
			
			//Video change
			NSLog(@"Change video %i to %i",lastFramesVideo, i);
			[self log:[NSString stringWithFormat:@"Start video %i",i]];
			
			
			if(i > 0){		
				//Går til en historie
				dispatch_sync(dispatch_get_main_queue(), ^{				
					
					[movie[i] setCurrentTime:QTTimeDecrement([movie[0] currentTime], QTTimeFromString(keys[i-1][0]))];
					
					
					
					//Gå til slutningen af historien i base videoen
					[movie[0] setCurrentTime:QTTimeFromString(keys[i-1][1] )];				
					
				});
				
				if(PropF(@"machine") <= 1){						
					whiteFlash = 1;
					ApplySurface(@"");{
						ofEnableAlphaBlending();
						ofSetColor(255,255,255, 255*whiteFlash);
						ofRect(-2, -2, 4, 4);
						
						//	flashImage->draw(0.0, 0.0,1.0, 1.0);
					} PopSurface();
					
					glFlush();
					forceDrawNextFrame = YES;						
				}
			} else {
				//Går tilbage til base videoen
				if(PropF(@"machine") <= 1){
					[self setRemoteVideos:0];
				}
				dispatch_sync(dispatch_get_main_queue(), ^{				
					
					[movie[lastFramesVideo] gotoBeginning];		
				});
			}
			dispatch_sync(dispatch_get_main_queue(), ^{				
				
				[movie[lastFramesVideo] setRate:0.0];	
				//				[movie[lastFramesVideo] setIdling:NO];
				//								[movie[i] setIdling:YES];
				[movie[i] setRate:1.0];		
			});
			
			lastFramesVideo = i;
			lastLightTime = QTTimeFromString(@"0");			
		}
		
		//NSLog(@"%lld  >= %lld ",[movie[i] currentTime].timeValue , [movie[i] duration].timeValue);
		if(i > 0 && [movie[i] currentTime].timeValue >= [movie[i] duration].timeValue-80){
			//Videoen er nået til ende, så gå til video 0
			[Prop(@"video") setFloatValue:0];
			if(PropF(@"machine") > 1){
				[Prop(@"fade") setIntValue:1];
				[Prop(@"fadeTo") setIntValue:0];
			}
		}		
		
		
		
		//		QTVisualContextTask(textureContext[i]);
		
		if (textureContext[i] != NULL && QTVisualContextIsNewImageAvailable(textureContext[i], outputTime)) {
			// if we have a previous frame release it
			if (NULL != currentFrame[i]) {
				CVOpenGLTextureRelease(currentFrame[i]);
				currentFrame[i] = NULL;
			}
			// get a "frame" (image buffer) from the Visual Context, indexed by the provided time
			OSStatus status = QTVisualContextCopyImageForTime(textureContext[i], NULL, outputTime, &currentFrame[i]);
			
			// the above call may produce a null frame so check for this first
			// if we have a frame, then draw it
			if ( ( status != noErr ) && ( currentFrame[i] != NULL ) )
			{
				NSLog(@"Error: OSStatus: %d",status);
				CFRelease( currentFrame[i] );
				
				currentFrame[i] = NULL;
			} // if
			
		} else if  (textureContext[i] == NULL){
			NSLog(@"No textureContext");
			if (NULL != currentFrame[i]) {
				CVOpenGLTextureRelease(currentFrame[i]);
				currentFrame[i] = NULL;
			}
		}		
	}
}

-(void) draw:(NSDictionary*)drawingInformation{
	int i = PropF(@"video");	
	
	if(currentFrame[i] != nil ){		
		//Draw video
		GLfloat topLeft[2], topRight[2], bottomRight[2], bottomLeft[2];
		
		GLenum target = CVOpenGLTextureGetTarget(currentFrame[i]);	
		GLint _name = CVOpenGLTextureGetName(currentFrame[i]);				
		
		// get the texture coordinates for the part of the image that should be displayed
		CVOpenGLTextureGetCleanTexCoords(currentFrame[i], bottomLeft, bottomRight, topRight, topLeft);
		
		
		glEnable(target);
		glBindTexture(target, _name);
		ofSetColor(255,255, 255, 255);						
		glPushMatrix();
		
		ApplySurface(@"");{
			
			if(PropI(@"machine") > 1){
				glBegin(GL_QUADS);{
					glTexCoord2f(topLeft[0], topLeft[1]);  glVertex2f(0, 0);
					glTexCoord2f(topRight[0], topRight[1]);     glVertex2f(Aspect(@"",0),  0);
					glTexCoord2f(bottomRight[0], bottomRight[1]);    glVertex2f( Aspect(@"",0),  1);
					glTexCoord2f(bottomLeft[0], bottomLeft[1]); glVertex2f( 0, 1);
				}glEnd();
			} else {
				glTranslated(0.5, 0.5, 0.0);
				glRotated(180, 0.0, 0.0, 1.0);
				glTranslated(-0.5, -0.5, 0.0);
				
				float gridSize = 64.0;
				
				float mesh[(int)gridSize+1][(int)gridSize+1][3];
				
				float scale = PropF(@"scale");
				float sphe = PropF(@"spherize");
				ofxVec2f cent = ofxVec2f(0.5,0.5);
				
				for(int x=0 ; x<=gridSize ; x++){
					for(int y=0 ; y<=gridSize ; y ++){
						float xVal = x/gridSize;
						float yVal = y/gridSize;
						
						ofxVec2f dir = ofxVec2f(xVal, yVal) - cent;
						ofxVec2f pos =cent + scale*scale* dir * cos(dir.length()*sphe);
						
						mesh[x][y][0] = pos.x;
						mesh[x][y][1] = pos.y;
						mesh[x][y][2] = -dir.length();
					}
				}
				
				for(float x=0 ; x<1 ; x+=1.0/gridSize){
					for(float y=0 ; y<1 ; y += 1.0/gridSize){
						glBegin(GL_QUADS);{
							//	NSLog(@"%f %f",x,y);
							float texX1 = topLeft[0]*(1-x) + topRight[0]*(x);
							float texY1 = topLeft[1]*(1-y) + bottomLeft[1]*(y);
							float texX2 = topLeft[0]*(1-(x+1.0/gridSize)) + topRight[0]*(x+1.0/gridSize);
							float texY2 = topLeft[1]*(1-(y+1.0/gridSize)) + bottomLeft[1]*(y+1.0/gridSize);
							
							float texCord[4][2];
							texCord[0][0] = texX1;
							texCord[0][1] = texY1;
							texCord[1][0] = texX2;
							texCord[1][1] = texY1;
							texCord[2][0] = texX2;
							texCord[2][1] = texY2;
							texCord[3][0] = texX1;
							texCord[3][1] = texY2;
							
							float * meshPoint[4];
							meshPoint[0]  = mesh[int(x*gridSize)][int(y*gridSize)];
							meshPoint[1]  = mesh[int(x*gridSize)+1][int(y*gridSize)];
							meshPoint[2]  = mesh[int(x*gridSize)+1][int(y*gridSize)+1];
							meshPoint[3]  = mesh[int(x*gridSize)][int(y*gridSize)+1];
							
							for(int p=0;p<4;p++){
								glTexCoord2f(texCord[p][0], texCord[p][1]);  glVertex3f(meshPoint[p][0], meshPoint[p][1], meshPoint[p][2]);	
							}
						}glEnd();
					}
				}
			}
		} PopSurface();
		
		glPopMatrix();
		
		
		glDisable(target);
		
		QTVisualContextTask(textureContext[i]);		
	}
	
	ofEnableAlphaBlending();
	ofFill();
	if(whiteFlash > 0){
		ApplySurface(@"");{
			ofEnableAlphaBlending();
			ofSetColor(255,255,255, 255*whiteFlash);
			ofRect(-2, -2, 4, 4);
			//flashImage->draw(0.0, 0.0,1.0, 1.0);
		} PopSurface();
	}
	
	
	
	if(PropF(@"fade") > 0){
		ApplySurface(@"");{
			ofSetColor(0,0,0, 255*PropF(@"fade")*1.1);
			ofRect(0, 0, Aspect(@"",0), 1);
		} PopSurface();
	}
	
	
	if(PropI(@"machine") == 2 && maske != nil){
		ApplySurface(@"");{
			ofSetColor(255,255,255, 255);
			//			maske->draw(0,0,1,1);
			
			ofSetColor(0, 0, 0,255);
			ofSetCircleResolution(100);
			ofRect(PropF(@"globus1maskx"), PropF(@"globus1masky"), -0.3, -0.3);
			ofEllipse(PropF(@"globus2maskx"), PropF(@"globus2masky"),PropF(@"globus2maskz"),PropF(@"globus2maskz2"));
			ofRect(PropF(@"globus3maskx"), PropF(@"globus3masky"), 0.3, 0.3);
			ofRect(0, 1, 1, -0.05);
			
		} PopSurface();
	}
	
	if(PropI(@"machine") == 3){
		ofSetColor(255, 255, 255,255);
		//		ofCircle(0, 0, 0.001);
		ofCircle(0.9, 0, 0.001);
		ofCircle(0.9, 0.9, 0.001);
		//		ofCircle(0, 1, 0.001);
	}
	// if(currentFrame[i] != nil ){				
	//	 ofDrawBitmapString("Timecode for "+ofToString(i)+": "+[QTStringFromTime([movie[i] currentTime]) cString], 0.01, 0.02);
	//	 ofDrawBitmapString("Difference to host: "+ofToString(timecodeDifference/double([movie[[Prop(@"video") intValue]] currentTime].timeScale), 2)+" sec", 0.01, 0.04);
	//	 }
	//	 
	//	 for(int u=0;u<NUMVIDEOS-1;u++){
	//	 if([movie[0] currentTime].timeValue > QTTimeFromString(keys[u][0]).timeValue && [movie[0] currentTime].timeValue < QTTimeFromString(keys[u][1]).timeValue + QTTimeFromString(postTimeBuffer).timeValue){	
	//	 ofSetColor(255, 0, 0);
	//	 ofRect(0, 0.9, 1.0, 1);
	//	 } 	
	//	 
	//	 }
	
	
}

@end