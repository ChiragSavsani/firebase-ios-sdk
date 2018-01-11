/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@import FirebaseFirestore;

#import <FirebaseFirestore/FIRFirestore.h>
#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"

@interface FIRGetOptionsTests : FSTIntegrationTestCase
@end

@implementation FIRGetOptionsTests {
  FIRDocumentReference *_emptyDoc;
  FIRDocumentReference *_testDoc;
  NSDictionary<NSString *, id> *_testDocInitialData;
  NSDictionary<NSString *, id> *_testDocUpdatedData;

  FIRCollectionReference *_emptyCol;
  FIRCollectionReference *_testCol;
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *_testColInitialDocs;
  NSArray<NSDictionary<NSString *, id> *> *_testColInitialDocsValues;
  NSArray<NSDictionary<NSString *, id> *> *_testColUpdatedDocsValues;
}

- (void)setUp {
  [super setUp];

  _emptyDoc = [self documentRef];
  _testDoc = [self documentRef];
  _testDocInitialData = @{@"key" : @"value"};
  _testDocUpdatedData = @{@"key2" : @"value2"};

  _emptyCol = [self collectionRef];
  _testCol = [self collectionRef];
  _testColInitialDocs = @{
    @"doc1": @{@"key1" : @"value1"},
    @"doc2": @{@"key2" : @"value2"},
    @"doc3": @{@"key3" : @"value3"}
  };

  _testColInitialDocsValues = @[
    @{@"key1" : @"value1"},
    @{@"key2" : @"value2"},
    @{@"key3" : @"value3"}
  ];

  _testColUpdatedDocsValues = @[
    @{@"key1" : @"value1"},
    @{@"key2" : @"value2", @"key2b": @"value2b"},
    @{@"key3b" : @"value3b"},
    @{@"key4" : @"value4"}
  ];

  // Insert some known values to testDoc and testCol.
  [self writeDocumentRef:_testDoc data:_testDocInitialData];
  [self writeAllDocuments:_testColInitialDocs toCollection:_testCol];
}

/**
 * Updates some of the docs, but doesn't actually wait for the server to
 * acknowledge the writes. (This is expected to be called primarily when
 * offline, so waiting for the server doesn't make sense.)
 */
- (void)updateData {
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [_testDoc setData:_testDocUpdatedData];

  [[_testCol documentWithPath:@"doc2"] setData:@{@"key2b" : @"value2b"} options:FIRSetOptions.merge];
  [[_testCol documentWithPath:@"doc3"] setData:@{@"key3b" : @"value3b"}];
  [[_testCol documentWithPath:@"doc4"] setData:@{@"key4" : @"value4"}];
}

- (void)testGetDocumentWhileOnlineWithDefaultGetOptions {
  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initial data.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocInitialData);
}

- (void)testGetDocumentsWhileOnlineWithDefaultGetOptions {
  // get docs and ensure they are *not* from the cache, and matches the
  // initial docs.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol];
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColInitialDocsValues);
}

- (void)testGetDocumentWhileOfflineWithDefaultGetOptions {
  [self disableNetwork];
  [self updateData];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // updated data.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocUpdatedData);
}

- (void)testGetDocumentsWhileOfflineWithDefaultGetOptions {
  [self disableNetwork];
  [self updateData];

  // get docs and ensure they *are* from the cache, and matches the updated data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColUpdatedDocsValues);
}

- (void)testGetDocumentWhileOnlineCacheOnly {
  // get doc and ensure that it exists, *is* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocInitialData);
}

- (void)testGetDocumentsWhileOnlineCacheOnly {
  // get docs and ensure they *are* from the cache, and matches the
  // initialDocs.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColInitialDocsValues);
}

- (void)testGetDocumentWhileOfflineCacheOnly {
  [self disableNetwork];
  [self updateData];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // updated data.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocUpdatedData);
}

- (void)testGetDocumentsWhileOfflineCacheOnly {
  [self disableNetwork];
  [self updateData];

  // get docs and ensure they *are* from the cache, and matches the updated
  // data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColUpdatedDocsValues);
}

- (void)testGetDocumentWhileOnlineServerOnly {
  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocInitialData);
}

- (void)testGetDocumentsWhileOnlineServerOnly {
  // get docs and ensure they are *not* from the cache, and matches the
  // initialData.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColInitialDocsValues);
}

- (void)testGetDocumentWhileOfflineServerOnly {
  [self disableNetwork];

  // attempt to get doc and ensure it cannot be retreived
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [_testDoc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetDocumentsWhileOfflineServerOnly {
  [self disableNetwork];

  // attempt to get docs and ensure they cannot be retreived
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [_testCol getDocumentsWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocsCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetDocumentWhileOfflineWithDifferentGetOptions {
  [self disableNetwork];
  [self updateData];

  // Create an initial listener for this query (to attempt to disrupt the gets below) and wait for the listener to be fully initialized before continuing.
  XCTestExpectation *listenerReady = [self expectationWithDescription:@"listenerReady"];
  [_testDoc addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [listenerReady fulfill];
  }];
  [self awaitExpectations];

  // get doc (from cache) and ensure it exists, *is* from the cache, and
  // matches the updated data.
  FIRDocumentSnapshot *result = [self readDocumentForRef:_testDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocUpdatedData);

  // attempt to get doc (with default get options)
  result = [self readDocumentForRef:_testDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRDefault]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, _testDocUpdatedData);

  // attempt to get doc (from the server) and ensure it cannot be retreived
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [_testDoc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetDocumentsWhileOfflineWithDifferentGetOptions {
  [self disableNetwork];
  [self updateData];

  // Create an initial listener for this query (to attempt to disrupt the gets
  // below) and wait for the listener to be fully initialized before
  // continuing.
  XCTestExpectation *listenerReady = [self expectationWithDescription:@"listenerReady"];
  [_testCol addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
    [listenerReady fulfill];
  }];
  [self awaitExpectations];

  // get docs (from cache) and ensure they *are* from the cache, and
  // matches the updated data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:_testCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColUpdatedDocsValues);

  // attempt to get docs (with default get options)
  result = [self readDocumentSetForRef:_testCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRDefault]];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), _testColUpdatedDocsValues);

  // attempt to get docs (from the server) and ensure they cannot be retreived
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [_testCol getDocumentsWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocsCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOnlineWithDefaultGetOptions {
  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot* snapshot = [self readDocumentForRef:_emptyDoc];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocsWhileOnlineWithDefaultGetOptions {
  // get docs and ensure that they are *not* from the cache.
  FIRQuerySnapshot* snapshot = [self readDocumentSetForRef:_emptyCol];
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOfflineWithDefaultGetOptions {
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [_emptyDoc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocsWhileOfflineWithDefaultGetOptions {
  [self disableNetwork];

  // get docs and ensure they *are* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:_emptyCol];
  XCTAssertTrue(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOnlineCacheOnly {
  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [_emptyDoc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRCache] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocsWhileOnlineCacheOnly {
  // get docs and ensure they *are* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:_emptyCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOfflineCacheOnly {
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [_emptyDoc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRCache] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocsWhileOfflineCacheOnly {
  [self disableNetwork];

  // get docs and ensure they *are* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:_emptyCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOnlineServerOnly {
  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot* snapshot = [self readDocumentForRef:_emptyDoc getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocsWhileOnlineServerOnly {
  // get docs and ensure that they are *not* from the cache.
  FIRQuerySnapshot* snapshot = [self readDocumentSetForRef:_emptyCol getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOfflineServerOnly {
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [_emptyDoc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocsWhileOfflineServerOnly {
  [self disableNetwork];

  // attempt to get docs and ensure they cannot be retreived
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [_emptyCol getDocumentsWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocsCompletion fulfill];
  }];
  [self awaitExpectations];
}

@end
