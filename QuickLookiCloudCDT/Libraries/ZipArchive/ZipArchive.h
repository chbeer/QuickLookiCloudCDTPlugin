//
//  ZipArchive.h
//  
//
//  Created by aish on 08-9-11.
//  acsolu@gmail.com
//  Copyright 2008  Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "minizip/zip.h"
#include "minizip/unzip.h"

@protocol ZipArchiveDelegate <NSObject>
@optional
-(void) ErrorMessage:(NSString*) msg;
-(BOOL) OverWriteOperation:(NSString*) file;
-(void) ProcessingEntry:(NSString*) entry;
@end


@interface ZipArchive : NSObject {
@private
	zipFile		_zipFile;
	unzFile		_unzFile;
	
	id			_delegate;
}

@property (nonatomic, strong) id delegate;

-(BOOL) CreateZipFile2:(NSString*) zipFile;
-(BOOL) addFileToZip:(NSString*) file newname:(NSString*) newname;
-(BOOL) CloseZipFile2;

-(BOOL) UnzipOpenFile:(NSString*) zipFile;
-(BOOL) UnzipFileTo:(NSString*) path overWrite:(BOOL) overwrite;
-(NSData *) dataForUnzipFileName:(NSString *)fileName;
-(NSArray *) UnzipFileLists;
-(BOOL) UnzipCloseFile;

@end