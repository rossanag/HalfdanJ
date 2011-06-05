//
//  ArduinoController.m
//  kronborg
//
//  Created by Jonas Jongejan on 21/09/10.
//  Copyright 2010 HalfdanJ. All rights reserved.
//

#import "ArduinoController.h"


@implementation ArduinoController
-(void) setup{
	thread = [[NSThread alloc] initWithTarget:self
									 selector:@selector(updateSerial:)
									   object:nil];
	serial = new ofSerial();	
	serial->enumerateDevices();
	
	
	//We will find serial devices by listing the directory
	
	DIR *dir;
	struct dirent *entry;
	dir = opendir("/dev");
	string str			= "";
	string device		= "";
	int deviceCount		= 0;
	string goodStr = "";
	
	if (dir == NULL){
		ofLog(OF_LOG_ERROR,"ofSerial: error listing devices in /dev");
	} else {
		printf("ofSerial: listing devices\n");
		while ((entry = readdir(dir)) != NULL){
			str = (char *)entry->d_name;
			if( str.substr(0,12) == "cu.usbserial" ){
				printf("device %i - %s\n", deviceCount, str.c_str());
				goodStr = str;
				deviceCount++;
			}
		}
	}
	
	
	ok = connected = serial->setup("/dev/"+goodStr,115200);
//	ok = connected = serial->setup(0,115200);	
	
	pthread_mutex_init(&mutex, NULL);
	serialBuffer = new vector<unsigned char>;
	inCommandProcess = false;
	commandInProcess = -1;
	typeInProcess = -1;
	if(ok)
		[thread start];	
	timeout = 0;
	
	properties = [[NSMutableDictionary dictionary] retain];
}

-(void) update{
	if([self connected]	){
		
	}
}

-(void) setDelegate:(id)_delegate{
	delegate = _delegate;
}

-(void) updateSerial:(id)param{
	
	
	if(connected){
		
		while(1){
			NSAutoreleasePool * perFramePool = [[NSAutoreleasePool alloc] init];

			timeout++;
			if(timeout > 1000){
				cout<<"Timeout to arduino... Trying again"<<endl;
				dispatch_async(dispatch_get_main_queue(), ^{											

				[delegate arduinoTimeout];
				});
				timeout = 0;
				ok = true;
				inCommandProcess = false;
				commandInProcess = -1;
				typeInProcess = -1;
			}
			while(serial->available() > 0){
				timeout = 0;
				
				bool needMoreData = false;
				int n=serial->available();
				//	int expectedBytes = serial->readByte();
				
				unsigned char buffer[100];
				
				//	cout<<"Theres data on the way. Command: "<<commandInProcess<<" on the way: "<<serial->available() <<" expecting: "<<0<< endl;				
				
				if(typeInProcess & ArduinoReceive){
					//Receiving
					typeInProcess -= ArduinoReceive;
					
					NSMutableDictionary * property = [self property:commandInProcess];
					
					int val = serial->readByte();
					//	NSLog(@"Received a byte: %i for prop %i",val,commandInProcess);
					
					if([[property valueForKey:@"value"] floatValue] != val){						
						[property setObject:[NSNumber numberWithInt:val] forKey:@"value"];
						[property setObject:[NSNumber numberWithInt:val] forKey:@"syncValue"];				
						
					}
					
					
				}
				serial->flush(true, true);
				
				
				if(!needMoreData){
					inCommandProcess = false;
					commandInProcess = -1;
					typeInProcess = -1;
					ok = true; 
				}
			}
			if(ok){	
				if(serialBuffer->size() > 0){
					int n = serialBuffer->size();
					unsigned char * bytes = new unsigned char[n+1];;
					
					for(int i=0;i<n;i++){
						bytes[i] = serialBuffer->at(0);
						//		cout<<(int)bytes[i]<<endl;
						
						if(bytes[i] == 255 && inCommandProcess){
							//Begin of new commando
							n = i;
						} else {
							if(bytes[i] == 255){
								inCommandProcess = true;
							} else if(inCommandProcess && typeInProcess == -1){
								typeInProcess = bytes[i];
							} else if(inCommandProcess && commandInProcess == -1){
								commandInProcess = bytes[i];
								//	cout<<"Command in process: "<<(int)bytes[i]<<endl;
							}
							serialBuffer->erase(serialBuffer->begin());
						}
					}
					
					serial->writeBytes(bytes, n);
					delete bytes;
					ok = false;
				} else {
					int n=0;
					pthread_mutex_lock(&mutex);
					
					
					//Send updates
					NSArray * keys = [self propertyKeys];
					for(NSString * propertyKey in keys){
						NSMutableDictionary * property = [properties objectForKey:propertyKey];
						int value = ofClamp([[property valueForKey:@"value"] intValue], 0, 254);
						if(value != [[property valueForKey:@"syncValue"] intValue]){
							serialBuffer->push_back(255);					
							serialBuffer->push_back(ArduinoTypeIntArray );												
							serialBuffer->push_back([propertyKey intValue]);
							serialBuffer->push_back(value);							
							[property setObject:[NSNumber numberWithInt:value] forKey:@"syncValue"];
							break;
						} else if( [[property objectForKey:@"pollInterval"] floatValue] > 0 && -[[property objectForKey:@"lastPollTime"] timeIntervalSinceNow] > [[property objectForKey:@"pollInterval"] floatValue]){
							[property setObject:[NSDate date] forKey:@"lastPollTime"];							
							serialBuffer->push_back(255);					
							serialBuffer->push_back(ArduinoTypeIntArray | ArduinoReceive);												
							serialBuffer->push_back([propertyKey intValue]);
							break;
							
						}
						
					}
					pthread_mutex_unlock(&mutex);
					
				}
			}
			
			[perFramePool release];

			[NSThread sleepForTimeInterval:0.003];
			
		}
	}
	
}

-(BOOL) connected{
	return connected;
}	

-(NSArray*) propertyKeys{
	NSMutableArray* array = [NSMutableArray arrayWithArray:[properties allKeys]];
	[array sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
	return array;
}

-(NSMutableDictionary *) property:(int)tag{
	NSMutableDictionary * property = [properties valueForKey:[self propertyKey:tag]];
	if(property == nil){
		property = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:0],@"value", 
					[NSNumber numberWithInt:0],@"syncValue", 
					[NSNumber numberWithFloat:-1], @"pollInterval",
					[NSDate date], @"lastPollTime",
					nil];
		[properties setObject:property forKey:[self propertyKey:tag]];
	}	
	
	return property;
}

-(NSString *) propertyKey:(int)tag{
	return [NSString stringWithFormat:@"%@",[NSNumber numberWithInt:tag]];
}
@end
