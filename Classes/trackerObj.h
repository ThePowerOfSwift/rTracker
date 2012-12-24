//
//  trackerObj.h
//  rTracker
//
//  Created by Robert Miller on 16/03/2010.
//  Copyright 2010 Robert T. Miller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "/usr/include/sqlite3.h"

#import "tObjBase.h"
#import "valueObj.h"
#import "rTracker-constants.h"

// to config checkbutton default states
#define SAVERTNDFLT   YES

// to config textfield default values
// #define PRIVDFLT		0  //note: already in valObj.h


@interface trackerObj : tObjBase {
	//int tid;
	NSString *trackerName;
	NSDate *trackerDate;
	NSMutableDictionary *optDict;
    
	NSMutableArray *valObjTable;
	CGSize maxLabel;
	NSInteger nextColor;
	
	//NSArray *colorSet;
	NSArray *votArray;
	
	UIControl *activeControl;	// ugly: track currently active text field so can scroll when keyboard shown, resign on background tap
	UIViewController *vc;		// ugly: vos may need this to present a voEdit page
    
    NSDateFormatter *dateFormatter;
    NSDateFormatter *dateOnlyFormatter;
    
    id togd;
}

//@property (nonatomic) int tid;
@property (nonatomic,retain) NSString *trackerName;
@property (nonatomic,retain) NSDate *trackerDate;
@property (nonatomic,retain) NSMutableDictionary *optDict;
@property (nonatomic,retain) NSMutableArray *valObjTable;
@property (nonatomic) CGSize maxLabel;
@property (nonatomic) NSInteger nextColor;
@property (nonatomic,retain) NSArray *votArray;
@property (nonatomic,assign) UIControl *activeControl;
@property (nonatomic,assign) UIViewController *vc;
@property (nonatomic,retain) NSDateFormatter *dateFormatter;
@property (nonatomic,retain) NSDateFormatter *dateOnlyFormatter;
@property (nonatomic,retain) id togd;

- (id) init:(int) tid;
- (id) initWithDict:(NSDictionary*)dict;

- (void) confirmTOdict:(NSDictionary*)dict;

- (void) addValObj:(valueObj*)valObj;
- (void) saveConfig;
- (void) saveChoiceConfigs;

- (NSDictionary*) dictFromTO;

- (void) loadConfig;
- (void) loadConfigFromDict:(NSDictionary*)dict;
- (void) rescanMaxLabel; 

- (void) setToOptDictDflts;
- (int) getDateCount;
- (BOOL) loadData:(NSInteger)iDate;
- (void) saveData;
- (void) resetData;
- (void) deleteTrackerDB;
- (void) deleteCurrEntry;
- (void) deleteTrackerRecordsOnly;

- (NSInteger) dateNearest:(int)targ;
- (NSInteger) prevDate;
- (NSInteger) postDate;
- (NSInteger) lastDate;
- (NSInteger) firstDate;

- (valueObj *) copyVoConfig:(valueObj*)srcVO;
- (valueObj *) getValObj:(NSInteger)vid;
- (void) describe;

- (BOOL) voHasData:(NSInteger)vid;
- (BOOL) checkData;
- (BOOL) hasData;
- (int) countEntries;
- (NSString*) voGetNameForVID:(NSInteger)vid;

- (BOOL) voVIDisUsed:(NSInteger)vid;
- (void) voUpdateVID:(NSInteger)old new:(NSInteger)new;

- (int) noCollideDate:(int)testDate;
- (void) changeDate:(NSDate*)newdate;

- (void) trackerUpdated:(NSNotification*)n;
- (void) recalculateFns;

- (void) export;
- (void) writeTrackerCSV:(NSFileHandle*)nsfh;
- (NSDictionary *) genRtrk:(BOOL)withData;

- (void) loadDataDict:(NSDictionary*)dataDict;

//- (void)applicationWillTerminate:(NSNotification *)notification;

- (void)receiveRecord:(NSDictionary *)aRecord;

- (void) setTOGD:(CGRect)inRect;
- (int) getPrivacyValue;

@end
