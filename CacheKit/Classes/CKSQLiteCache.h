//
//  CKSQLiteCache.h
//  Pods
//
//  Created by David Beck on 10/13/14.
//
//

#import "CKCache.h"


/** CKCache that stores it's objects in an SQLite database.
 
 Objects are persisted to the cache database using this cache. In addition, there is an in
 memory NSCache for quick access.
 
 All database access is performed on a serial queue and is thread safe.
 
 Notice: Objects must conform to the `NSCoding` protocol. Internally, objects are encoded
 using `NSCoding`. Properties are not stored as columns.
 */
@interface CKSQLiteCache : CKCache

/** A shared database cache.
 
 You can use this cache for general content you want stored in a database. Make sure your keys are
 unique across your app by prefixing them with class names or other unique data.
 
 @return A singleton instance of a database cache.
 */
+ (nonnull instancetype)sharedCache;

/** Clear the internal in memory cache
 
 This is primarily for testing purposes.
 */
- (void)clearInternalCache;

/** Init cache which stores data at a given directory.
 
 This isn't very much "cachy", since the given directory could not be in the "caches" directory, but using a persistent directory (eg: Library or Documents) you can prevent the cache from being wiped by the system in case of low disk space.
 
 @param name The name for the new cache. If a cache is persistent, passing the same name 2 caches
 will cause them to share data, however there may be issues with concurrency. You should use the
 same name for the cache each time the app is launched.
 @param baseURL The URL for the directory where the database will be stored.
 @return A new cache with the given name and the base directory.
 */
- (nonnull instancetype)initWithName:(nonnull NSString *)name
                         inDirectory:(nonnull NSURL *)baseURL;

@end
