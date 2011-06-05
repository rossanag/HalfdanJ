#import "VideoPlayer.h"
#include "Keystoner.h"

@implementation VideoPlayer

@synthesize loadedFiles, numberVideos, fileName, basePath;

-(id)init{
    if((self = [super init])){
        basePath  = [@"~/Movies/" stringByExpandingTildeInPath];
        fileName = @"";
        numberVideos = 9;
    } 
    return self;
}

-(void) initPlugin{	
	NSLog(@"Init videplayer");
	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:numberVideos] named:@"video"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:0 minValue:0 maxValue:1] named:@"chapter"];	
	[self addProperty:[NumberProperty sliderPropertyWithDefaultvalue:1 minValue:0 maxValue:1] named:@"volume"];	
	
	[self assignMidiChannel:8];	
	lastFramesVideo = -1;
	forceDrawNextFrame = NO;
	
	loadedFiles = [[NSMutableArray array] retain]; 
}

//
//-----
//

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	if(object == Prop(@"volume")){
		dispatch_async(dispatch_get_main_queue(), ^{	
			for(int i=0;i<numberVideos;i++){				
				if(movie[i]){
					[movie[i] setVolume:[object floatValue]];							
				}
			}
		});
	}
	if(object == Prop(@"video")){		
		if(PropI(@"video") == 0){			
			NSLog(@"Reset video");
			dispatch_async(dispatch_get_main_queue(), ^{		
				for(int i=0;i<numberVideos;i++){				
					if(movie[i]){
						[movie[i] gotoBeginning];				
						[movie[i] setRate:0.0];							
					}
				}
				forceDrawNextFrame = YES;
				lastFramesVideo = -1;
				[chapterSelector removeAllItems];
				[chapterSelector addItemWithTitle:@" - No Chapters - "];
				[((NumberProperty*) Prop(@"chapter")) setMaxValue:[NSNumber numberWithInt:0]];
				[Prop(@"chapter") setIntValue:0];
				
			});			
		} else {
			dispatch_async(dispatch_get_main_queue(), ^{	
				for(int i=0;i<numberVideos;i++){				
					if(movie[i]){
						[movie[i] gotoBeginning];				
						[movie[i] setRate:0.0];							
					}
				}
                QTMovie * mov = movie[[object intValue]-1];
				if(mov){				
					[chapterSelector removeAllItems];				
					if([mov chapterCount] > 0){
						for(NSDictionary * dict in [mov chapters]){
							[chapterSelector addItemWithTitle:[dict valueForKey:QTMovieChapterName]];
						}
						[((NumberProperty*) Prop(@"chapter")) setMaxValue:[NSNumber numberWithInt:[mov chapterCount]-1]];
						[Prop(@"chapter") setIntValue:0];
					} else {
						[chapterSelector addItemWithTitle:@" - No Chapters - "];
						[((NumberProperty*) Prop(@"chapter")) setMaxValue:[NSNumber numberWithInt:0]];
						[Prop(@"chapter") setIntValue:0];
					}				
				}
			});			
			
		}
	}
	
	if(object == Prop(@"chapter")){
		if(PropI(@"video") != 0){	
			QTMovie * mov = movie[PropI(@"video")-1];
			if([mov hasChapters]){
				dispatch_async(dispatch_get_main_queue(), ^{	
					NSLog(@"Change chapter");
					[mov setCurrentTime:[mov startTimeOfChapter:PropI(@"chapter")]];
					[mov setRate:1.0];
					
				});
			}
		}
	}
}


//
//-----
//


-(IBAction) restart:(id)sender{
	[movie[PropI(@"video")-1] setCurrentTime:QTMakeTime(0, 60)];	
}

//
//-----
//

- (void) applicationWillTerminate: (NSNotification *)note{
	for(int i=0;i<numberVideos;i++){
		// stop and release the movie
		if (movie[i]) {
			[movie[i] setRate:0.0];
			SetMovieVisualContext([movie[i] quickTimeMovie], NULL);
			[movie[i] release];
			movie[i] = nil;
		}	
		
		// don't leak textures
		if (currentFrame) {
			CVOpenGLTextureRelease(currentFrame[i]);
			currentFrame[i] = NULL;
		}
		
		// release the OpenGL Texture Context
		if (textureContext[i]) {
			CFRelease(textureContext[i]);
			textureContext[i] = NULL;
		}
	}
}



//
//-----
//

-(BOOL) willDraw:(NSMutableDictionary *)drawingInformation{
	if(PropI(@"video") > 0 && PropI(@"video") <= numberVideos){
		return YES;
	}
	return NO;
	if(PropI(@"video") > 0 && PropI(@"video") <= numberVideos){
		QTVisualContextTask(textureContext[PropI(@"video")-1]);
		
		if(forceDrawNextFrame){
			forceDrawNextFrame = NO;
			return YES;
		}
		
		
		const CVTimeStamp * outputTime;
		[[drawingInformation objectForKey:@"outputTime"] getValue:&outputTime];
		if(textureContext[PropI(@"video")-1] != nil)
			return QTVisualContextIsNewImageAvailable(textureContext[PropI(@"video")-1], outputTime);
		return NO;	
	} else {
		return forceDrawNextFrame;	
	}
}

//
//-----
//

-(void) setup{	
	
	NSLog(@"Setup video with basePath %@",basePath);
	[Prop(@"video") setFloatValue:0];
	dispatch_async(dispatch_get_main_queue(), ^{	
		
		NSError * error = [NSError alloc];			
		
		NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
									  [NSNumber numberWithBool:NO], QTMovieLoopsAttribute, nil];		
		
		for(int i=0;i<numberVideos;i++){
			NSString * fileNumber = [NSString stringWithFormat:@"%i",i];
            if(numberVideos > 9 && i <= 9){
                fileNumber = [NSString stringWithFormat:@"0%@", fileNumber];
            }
			
			[dict setObject:[NSString stringWithFormat:@"%@/%@%@.mov",basePath,fileName, fileNumber] forKey:QTMovieFileNameAttribute];
			movie[i] = [[QTMovie alloc] initWithAttributes:dict error:&error];
			if(error != nil){ 
				NSLog(@"ERROR: Could not load movie %i %@: %@",i,[dict valueForKey:QTMovieFileNameAttribute], error);
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
				
				NSArray* vtracks = [movie[i] tracksOfMediaType:QTMediaTypeVideo];
				QTTrack* track = [vtracks objectAtIndex:0];
				sizes[i] = [track apertureModeDimensionsForMode:QTMovieApertureModeClean];
				
				
				[loadedFilesController addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:i],@"number",
												  [NSString stringWithFormat:@"%@%@.mov",fileName, fileNumber],@"name",
												  [NSString stringWithFormat:@"%ix%i",int(sizes[i].width),int( sizes[i].height)],@"size",
												  codecTypeString, @"codec",
												  QTStringFromTime([movie[i] duration]),@"duration",
												  [NSNumber numberWithInt:[movie[i] chapterCount]],@"chapters",
												  nil]];
				
				NSLog(@"Loaded %@",[NSString stringWithFormat:@"%@/%@%@.mov",basePath,fileName,fileNumber]);
				
				DisposeHandle((Handle)videoTrackDescH);	
			}
			
		}
		
		for(int i=0;i<numberVideos;i++){
			[movie[i] retain];
			[movie[i] stop];
			[movie[i] setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];
			
			QTOpenGLTextureContextCreate(kCFAllocatorDefault,								
										 CGLContextObj(CGLGetCurrentContext()),		// the OpenGL context
										 CGLGetPixelFormat(CGLGetCurrentContext()),
										 nil,
										 &textureContext[i]);
			[movie[i] setVisualContext:textureContext[i]];
		}
		
		[videoSelector removeAllItems];
		[videoSelector addItemWithTitle:@" - No video - "];
		
		for(NSDictionary * dict in [loadedFilesController content]){
			[videoSelector addItemWithTitle:[dict valueForKey:@"name"]];
		}
		
		
		[chapterSelector removeAllItems];
		[chapterSelector addItemWithTitle:@" - No Chapters - "];
		
	});		
	
	//
	
}

//
//-----
//

-(void) update:(NSDictionary *)drawingInformation{		
	// check for new frame
	const CVTimeStamp * outputTime;
	[[drawingInformation objectForKey:@"outputTime"] getValue:&outputTime];	
	if(PropI(@"video")-1 >= 0){
		if([movie[PropI(@"video")-1] currentTime].timeValue >= [movie[PropI(@"video")-1] duration].timeValue-0.1*[movie[PropI(@"video")-1] duration].timeScale){
			//Videoen er nået til ende, så gå til næste video
			[Prop(@"video") setIntValue:0];
		} else if([movie[PropI(@"video")-1] hasChapters]){
			//	NSLog(@"Selected chapter: %i,  number chapter: %i,  currentChapter: %i",PropI(@"chapter"), [movie[PropI(@"video")-1] chapterCount], [movie[PropI(@"video")-1] chapterIndexForTime:[movie[PropI(@"video")-1] currentTime]] );
			int currentChapter = [movie[PropI(@"video")-1] chapterIndexForTime:QTTimeIncrement([movie[PropI(@"video")-1] currentTime],QTMakeTime(1, 30))];
			int numberChapters = [movie[PropI(@"video")-1] chapterCount];
			int selectedChapter = PropI(@"chapter");
			if(currentChapter == numberChapters)
				currentChapter --;
			
			if(currentChapter == selectedChapter + 1){
				dispatch_async(dispatch_get_main_queue(), ^{
					
					if(selectedChapter + 1 < numberChapters){					
						[movie[PropI(@"video")-1] setCurrentTime:QTTimeDecrement([movie[PropI(@"video")-1] startTimeOfChapter:PropI(@"chapter")+1],QTMakeTime(2, 30))];
					}
					
					[movie[PropI(@"video")-1] setRate:0.0];
					NSLog(@"End of chapter.");
				});
			}
			
			
		}
	}
	
	
	if(PropI(@"video") > 0 && PropI(@"video") <= numberVideos){
		int i = PropI(@"video")-1;	
		
		if(movie[i] != nil){
			if(lastFramesVideo != i){
				//Video change
				NSLog(@"Change video %i to %i",lastFramesVideo, i);
				
				dispatch_async(dispatch_get_main_queue(), ^{		
					forceDrawNextFrame = YES;	
					if(lastFramesVideo > 0){
						[movie[lastFramesVideo] setRate:0.0];	
						[movie[lastFramesVideo] gotoBeginning];				
					}
					[movie[i] gotoBeginning];				
					[movie[i] setRate:1.0];					
				});
				
				lastFramesVideo = i;
			}
			
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
					NSLog(@"Error: OSStatus: %ld",status);
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
}

-(void) draw:(NSDictionary*)drawingInformation{
	if(PropI(@"video") > 0 && PropI(@"video") <= numberVideos){
		
		//	NSLog(@"Draw");
		int i = PropI(@"video")-1;
		
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
			
			int projector = 0;
			[GetPlugin(Keystoner)  applySurface:@"Screen" projectorNumber:projector viewNumber:ViewNumber];
            
			
			float aspect;
            aspect = Aspect(@"Screen",projector);	
            glBegin(GL_QUADS);{
                glTexCoord2f(topLeft[0], topLeft[1]);  glVertex2f(0, 0);
                glTexCoord2f(topRight[0], topRight[1]);     glVertex2f(aspect,  0);
                glTexCoord2f(bottomRight[0], bottomRight[1]);    glVertex2f(aspect,  1);
                glTexCoord2f(bottomLeft[0], bottomLeft[1]); glVertex2f( 0, 1);
            }glEnd();
			//		ApplySurface(([NSString stringWithFormat:@"Skærm%i",i+1])){
            
			
			
			[GetPlugin(Keystoner)  popSurface];
			
			glPopMatrix();		
			
			glDisable(target);
			
			QTVisualContextTask(textureContext[i]);		
		}
		
		ofEnableAlphaBlending();
	}
}

-(QTMovie*) getMovie:(int)i{
    return movie[i];
}

-(QTMovie*) getCurrentMovie{
    if(PropI(@"video") > 0 && PropI(@"video") <= numberVideos){
        int i = PropI(@"video")-1;
        return movie[i];
    }
    return nil;
}

-(int) getCurrentMovieIndex{
    return PropI(@"video");
}

-(void) setCurrentMovie:(int)i{
    [Prop(@"video") setIntValue:i];
}

@end
