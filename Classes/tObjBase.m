//
//  tObjBase.m
//  rTracker
//
//  Created by Robert Miller on 29/04/2010.
//  Copyright 2010 Robert T. Miller. All rights reserved.
//

#import "tObjBase.h"
#import "rTracker-constants.h"
#import "rTracker-resource.h"
#import "dbg-defs.h"

@implementation tObjBase

@synthesize toid, dbName, sql, tuniq, tDb;
//sqlite3 *tDb;

/******************************
 *
 * base tObj db tables
 *
 *  uniquev: id(int) ; value(int)
 *       persistent store to maintain unique trackerObj and valueObj IDs
 *
 ******************************/

#pragma mark -
#pragma mark core object methods and support

- (id) init {
	
	if ((self = [super init])) {
		DBGLog1(@"tObjBase init: db %@",self.dbName);
		tDb=nil;
		//[self getTDb];
		self.tuniq = TMPUNIQSTART;
	}
	return self;
}

- (void) dealloc {
    DBGLog2(@"dealloc tObjBase: %@  id=%d",self.dbName,self.toid);
	
	UIApplication *app = [UIApplication sharedApplication];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
												 name:UIApplicationWillTerminateNotification
											   object:app];
		
	[self closeTDb];
	self.sql = nil;
	[sql release];
	self.dbName = nil;
	[dbName release];
	
	[super dealloc];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	DBGLog1(@"tObjBase: app will terminate: toid= %d",self.toid);
	[self closeTDb];
}


#pragma mark -
#pragma mark total db methods 
/*
- (NSString *) trackerDbFilePath {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);  // file itunes accessible
	//NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);  // files not accessible
	NSString *docsDir = [paths objectAtIndex:0];
	return [docsDir stringByAppendingPathComponent:self.dbName];
}
*/

static int col_str_flt (void *udp, int lenA, const void *strA, int lenB, const void *strB) 
{
	// strAm strB not guaranteed to be null-terminated
	
	//double va = atof(strA);
	//double vb = atof(strB);
	char *astr = (char *) strA;
	char *bstr = (char *) strB;
	char *ta = &(astr[lenA-1]);
	char *tb = &(bstr[lenB-1]);
	double va = strtod(strA,&ta);
	double vb = strtod(strB,&tb);
	int r=0;
	if (va>vb)
		r= 1;
	if (va<vb) 
		r= -1;
	//DBGLog3(@"a= %f  b= %f  r= %d",va,vb,r);

	return r;
}


- (void) getTDb {
	DBGLog2(@"getTDb dbName= %@ id=%d",self.dbName,self.toid);
	NSAssert(self.dbName, @"getTDb called with no dbName set");
	
	if (sqlite3_open([[rTracker_resource ioFilePath:self.dbName access:DBACCESS] UTF8String], &tDb) != SQLITE_OK) {
		sqlite3_close(tDb);
		NSAssert(0, @"error opening rTracker database");
	} else {
		DBGLog1(@"opened tDb %@",self.dbName);
		int c;
		
		self.sql = @"create table if not exists uniquev (id integer, value integer);";
		[self toExecSql];
		self.sql = @"select count(*) from uniquev where id=0;";
		c = [self toQry2Int];
		
		if (c == 0) {
			DBGLog(@"init uniquev");
			self.sql = @"insert into uniquev (id, value) values (0, 1);";
			[self toExecSql];
		} else {
			self.sql = @"select value from uniquev where id=0;";
			c = [self toQry2Int];
			DBGLog1(@"uniquev= %d",c);
		}
		self.sql = nil;

		
		sqlite3_create_collation(tDb,"CMPSTRDBL",SQLITE_UTF8,NULL,col_str_flt);
		
		UIApplication *app = [UIApplication sharedApplication];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(applicationWillTerminate:) 
													 name:UIApplicationWillTerminateNotification
												   object:app];
		
		
	}
}

/* valid to have as nil
- (sqlite3*) tDb {
    if (nil == tDb) {
        [self getTDb];
    }
    return tDb;
}
*/

- (void) deleteTDb {
	DBGLog2(@"deleteTDb dbName= %@ id=%d",self.dbName,self.toid);
	NSAssert(self.dbName, @"deleteTDb called with no dbName set");
	sqlite3_close(tDb);
	tDb = nil;
	NSFileManager *fm = [[NSFileManager alloc] init];
	BOOL didRemove = [fm removeItemAtPath:[rTracker_resource ioFilePath:self.dbName access:DBACCESS] error:NULL];
	[fm release];
	if (! didRemove) {
		DBGErr1(@"error removing tDb named %@",dbName);
	} else {
		self.dbName = nil;
	}
}

- (void) closeTDb 
{
	if (tDb != nil) {
		sqlite3_close(tDb);
		tDb = nil;
		DBGLog1(@"closed tDb: %@", self.dbName);
	} else {
		DBGWarn1(@"tDb already closed %@", self.dbName);
	}
}

#pragma mark -
#pragma mark tObject support utilities

- (int) getUnique {
	int i;
	if (tDb == nil) {
		++tuniq;
		i = -tuniq;
		DBGLog2(@"temp tObj id=%d getUnique returning %d",self.toid,i);
	} else {
		self.sql = @"select value from uniquev where id=0;";
		i = [self toQry2Int];
		DBGLog2(@"id %d getUnique got %d",self.toid,i);
		self.sql = [NSString stringWithFormat:@"update uniquev set value = %d where id=0;",i+1];
		[self toExecSql];
		self.sql = nil;
	}
	return i;
}

#pragma mark -
#pragma mark sql query execute methods

- (void) toQry2AryS : (NSMutableArray *) inAry {
	
	SQLDbg2(@"toQry2AryS: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryS called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			char *rslts = (char *) sqlite3_column_text(stmt, 0);
			NSString *tlentry = [NSString stringWithUTF8String:rslts];
			[inAry addObject:(id) tlentry];
			SQLDbg1(@"  rslt: %@",tlentry);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	SQLDbg1(@"  returns %@", inAry);
}

- (void) toQry2AryIS : (NSMutableArray *) i1 s1: (NSMutableArray *) s1 {
	
	
	SQLDbg2(@"toQry2AryIS: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryIS called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[i1 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt,0)]];
			
			[s1 addObject: [NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, 1)]];
			
			SQLDbg2(@"  rslt: %@ %@",[i1 lastObject], [s1 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}

- (void) toQry2AryISI : (NSMutableArray *) i1 s1:(NSMutableArray *)s1 i2:(NSMutableArray *)i2 {
	
	
	SQLDbg2(@"toQry2AryISI: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryISI called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[i1 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt,0)]];
			[s1 addObject: [NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, 1)]];
			[i2 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt,2)]];
			
			SQLDbg3(@"  rslt: %@ %@ %@",[i1 lastObject], [s1 lastObject],[i2 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}

- (void) toQry2ArySS : (NSMutableArray *) s1 s2: (NSMutableArray *) s2 {
	
	
	SQLDbg2(@"toQry2ArySS: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2ArySS called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[s1 addObject: [NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, 0)]];
			
			[s2 addObject: [NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, 1)]];
			
			SQLDbg2(@"  rslt: %@ %@",[s1 lastObject], [s2 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}

- (void) toQry2AryIIS : (NSMutableArray *) i1 i2: (NSMutableArray *) i2 s1: (NSMutableArray *) s1 {
// not used
	
	SQLDbg2(@"toQry2AryIIS: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryIIS called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[i1 addObject:[NSNumber numberWithInt: sqlite3_column_int(stmt, 0)]];
			
			[i2 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, 1)]];
			
			[s1 addObject: [NSString stringWithUTF8String: (char *) sqlite3_column_text(stmt, 2)]];
			
			SQLDbg3(@"  rslt: %@ %@ %@",[i1 lastObject], [i2 lastObject], [s1 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}


- (void) toQry2AryIISIII : (NSMutableArray *) i1 i2: (NSMutableArray *) i2 s1: (NSMutableArray *) s1 i3:(NSMutableArray *)i3 i4:(NSMutableArray *)i4 i5:(NSMutableArray *)i5 
{
	
	
	SQLDbg2(@"toQry2AryIISII: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryIISII called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[i1 addObject: [NSNumber numberWithInt:sqlite3_column_int(stmt, 0)]];
			
			[i2 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, 1)]];
			
			[s1 addObject: [NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, 2)]];
			
			[i3 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, 3)]];
			
			[i4 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, 4)]];
			[i5 addObject: [NSNumber numberWithInt: sqlite3_column_int(stmt, 5)]];
			
			SQLDbg6(@"  rslt: %@ %@ %@ %@ %@ %@",[i1 lastObject], [i2 lastObject], [s1 lastObject], [i4 lastObject], [i4 lastObject], [i5 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}


- (void) toQry2AryID : (NSMutableArray *)i1 d1:(NSMutableArray *)d1
{
	SQLDbg2(@"toQry2AryIF: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryIF called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[i1 addObject: [NSNumber numberWithInt:sqlite3_column_int(stmt, 0)]];
			[d1 addObject: [NSNumber numberWithDouble: sqlite3_column_double(stmt, 1)]];

			SQLDbg2(@"  rslt: %@ %@",[i1 lastObject], [d1 lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}
   
- (void) toQry2AryI : (NSMutableArray *) inAry {
	
	SQLDbg2(@"toQry2AryI: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryI called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			[inAry addObject: [NSNumber numberWithInt:sqlite3_column_int(stmt, 0)]];
			SQLDbg1(@"  rslt: %@",[inAry lastObject]);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	SQLDbg1(@"  returns %@", inAry);
}

- (void) toQry2IntInt:(int *)i1 i2:(int*)i2 {
	
	SQLDbg2(@"toQry2AryII: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2AryII called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		*i1=0;
		*i2=0;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			*i1 = sqlite3_column_int(stmt, 0);
			*i2 = sqlite3_column_int(stmt, 1);
			SQLDbg2(@"  rslt: %d %d",*i1,*i2);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	SQLDbg2(@"  returns %d %d",*i1,*i2);
}

- (int) toQry2Int {
	SQLDbg2(@"toQry2Int: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2Int called with no tDb");
	
	sqlite3_stmt *stmt;
	int irslt=0;
	
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			irslt = sqlite3_column_int(stmt, 0);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	
	SQLDbg1(@"  returns %d",irslt);

	return irslt;
}

- (NSString *) toQry2Str {
	SQLDbg2(@"toQry2StrCopy: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2StrCopy called with no tDb");
	
	sqlite3_stmt *stmt;
	NSString *srslt=@"";
	
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		//int rslt;
		if((/*rslt =*/ sqlite3_step(stmt)) == SQLITE_ROW) {
			srslt = [NSString stringWithUTF8String: (char *) sqlite3_column_text(stmt, 0)];
		} else {
			DBGErr2(@"tob error executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
		//if (rslt != SQLITE_DONE) {
		//	DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		//}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	
	SQLDbg1(@"  returns _%@_",srslt);
	
	return srslt;
}

- (float) toQry2Float {
	SQLDbg2(@"toQry2Float: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2Float called with no tDb");
	
	sqlite3_stmt *stmt;
	float frslt=0.0f;
	
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			frslt = (float) sqlite3_column_double(stmt, 0);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	
	SQLDbg1(@"  returns %f",frslt);
	
	return frslt;
}

- (double) toQry2Double {
	SQLDbg2(@"toQry2Double: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2Double called with no tDb");
	
	sqlite3_stmt *stmt;
	double drslt=0.0f;
	
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			drslt = sqlite3_column_double(stmt, 0);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
	
	SQLDbg1(@"  returns %f",drslt);
	
	return drslt;
}


- (void) toExecSql {
	SQLDbg2(@"toExecSql: %@ => _%@_", self.dbName, self.sql);
	NSAssert(tDb,@"toExecSql called with no tDb");
	
	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		if (sqlite3_step(stmt) != SQLITE_DONE) {
			NSAssert2(0,@"tob error executing _%@_  : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}


- (void) toQry2Log {
	SQLDbg2(@"toQry2Log: %@ => _%@_",self.dbName,self.sql);
	NSAssert(tDb,@"toQry2Log called with no tDb");
	
	sqlite3_stmt *stmt;
	NSString *srslt;
	
	if (sqlite3_prepare_v2(tDb, [self.sql UTF8String], -1, &stmt, nil) == SQLITE_OK) {
		int rslt;
		int c = sqlite3_column_count(stmt);
		int i;
		NSString *cols=@"";
		for (i=0; i<c; i++) {
			cols = [cols stringByAppendingString:[NSString stringWithUTF8String:sqlite3_column_name(stmt,i)]];
			cols = [cols stringByAppendingString:@" "];
		}
		SQLDbg1(@"%@",cols);
		while ((rslt = sqlite3_step(stmt)) == SQLITE_ROW) {
			cols = @"";
			for (i=0; i<c; i++) {
				srslt = [NSString stringWithUTF8String: (char *) sqlite3_column_text(stmt, i)];
				cols = [cols stringByAppendingString:srslt];
				cols = [cols stringByAppendingString:@" "];
			}
			SQLDbg1(@"%@",cols);
		}
		if (rslt != SQLITE_DONE) {
			DBGErr2(@"tob not SQL_DONE executing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
		}
	} else {
		DBGErr2(@"tob error preparing . %@ . : %s", self.sql, sqlite3_errmsg(tDb));
	}
	sqlite3_finalize(stmt);
}

@end
