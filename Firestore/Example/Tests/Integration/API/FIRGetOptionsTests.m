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

@implementation FIRGetOptionsTests

- (void)testGetDocumentWhileOnlineWithDefaultGetOptions {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetDocumentWhileOfflineWithDefaultGetOptions {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData completion:^(NSError *_Nullable error) {
    XCTAssertTrue(false, "Because we're offline, this should never occur.");
  }];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, newData);
}

- (void)testGetDocumentWhileOnlineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, *is* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetDocumentWhileOfflineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData completion:^(NSError *_Nullable error) {
    XCTFail("Because we're offline, this should never occur.");
  }];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, newData);
}

- (void)testGetDocumentWhileOnlineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetDocumentWhileOfflineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData completion:^(NSError *_Nullable error) {
    XCTAssertTrue(false, "Because we're offline, this should never occur.");
  }];

  // attempt to get doc and ensure it cannot be retreived
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [doc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetDocumentWhileOfflineWithDifferentGetOptions {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData completion:^(NSError *_Nullable error) {
    XCTAssertTrue(false, "Because we're offline, this should never occur.");
  }];

  // Create an initial listener for this query (to attempt to disrupt the gets below) and wait for the listener to be fully initialized before continuing.
  XCTestExpectation *listenerReady = [self expectationWithDescription:@"listenerReady"];
  [doc addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [listenerReady fulfill];
  }];
  [self awaitExpectations];

  // get doc (from cache) and ensure it exists, *is* from the cache, and
  // matches the newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRCache]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, newData);

  // attempt to get doc (with default get options)
  result = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRDefault]];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(result.data, newData);

  // attempt to get doc (from the server) and ensure it cannot be retreived
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [doc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [failedGetDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOnlineWithDefaultGetOptions {
  FIRDocumentReference *doc = [self documentRef];

  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot* snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOfflineWithDefaultGetOptions {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOnlineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRCache] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOfflineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRCache] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOnlineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot* snapshot = [self readDocumentForRef:doc getOptions:[[FIRGetOptions alloc] initWithSource:FIRServer]];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
}

- (void)testGetNonExistingDocWhileOfflineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion = [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithOptions:[[FIRGetOptions alloc] initWithSource:FIRServer] completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

@end
