//
//  Cache.swift
//  FeedCache
//
//  Created by Rob Seward on 7/17/15.
//  Copyright © 2015 Rob Seward. All rights reserved.
//

import Foundation

struct FeedCacheFileNames {
    static let apiCacheFolderName = "FeedCache"
    static let genericArchiveName = "feed_cache.archive"
}

public func deleteAllFeedCaches() throws {
    let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
    let libraryCachesDirectory: AnyObject = paths[0]
    let cacheDirectory = libraryCachesDirectory.stringByAppendingPathComponent(FeedCacheFileNames.apiCacheFolderName)
    try NSFileManager.defaultManager().removeItemAtPath(cacheDirectory)
}

public class FeedCache<T:FeedItem>{
    
    let name: String!
    var diskOperationQueue = NSOperationQueue()
    public var items : [T] = []
    public var saved = false
    
    public init(name: String) {
        if FeedCachePerformWorkSynchronously {
            diskOperationQueue = NSOperationQueue.mainQueue()
        }
        diskOperationQueue.maxConcurrentOperationCount = 1
        self.name = name
    }
        
    public func addItems(items: [T]){
        self.saved = false
        self.items = self.items + items
        let data = NSKeyedArchiver.archivedDataWithRootObject(self.items)
        _saveData(data)
    }
    
    // Completion will fire on main queue
    public func loadCache(completion: ( (success: Bool)->() )? = nil){
        
        // Once background queue is exited, synchronize will unblock
        // thus completion will fire **after** synchronize unblocks
        let mainQueueCompletion : (success: Bool) -> () = {
            (success: Bool) -> () in
            if NSThread.isMainThread() == false {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion?(success: success)
                })
            }
            else {
                completion?(success: success)
            }
        }
        
        _getCachedData (completion: {(data) -> () in
            if let data = data {
                let unarchivedItems = NSKeyedUnarchiver.unarchiveObjectWithData(data)
                if let unarchivedItems = unarchivedItems as? [T] {
                    self.items = unarchivedItems
                    mainQueueCompletion(success: true)
                    return
                }
            }
            mainQueueCompletion(success: false)
        })
    }
    
    public func clearCache() {
        self.saved = false
        self.items = []
        _deleteCache()
        self.saved = true
    }
    
    // Wait until operation queue is empty
    public func waitUntilSynchronized(){
        if diskOperationQueue != NSOperationQueue.mainQueue() {
            diskOperationQueue.waitUntilAllOperationsAreFinished()
        }
    }
    
    private func _deleteCache() {
        let folderName = name
        let folderPath = _folderPathFromFolderName(folderName, insideCacheFolder: true)
        let filePath = (folderPath as NSString).stringByAppendingPathComponent(FeedCacheFileNames.genericArchiveName)
        do {
            try NSFileManager.defaultManager().removeItemAtPath(filePath)
        }
        catch let error as NSError {
            print(error)
        }
    }
    
    private func _saveData(data : NSData){
        diskOperationQueue.addOperationWithBlock {
            [weak self]() -> Void in
            
            if let
                strongSelf = self,
                folderName = strongSelf.name
            {
                let folderPath = strongSelf._folderPathFromFolderName(folderName, insideCacheFolder: true)
                strongSelf._createFolderIfNeeded(folderPath)
                
                let filePath = (folderPath as NSString).stringByAppendingPathComponent(FeedCacheFileNames.genericArchiveName)
                
                data.writeToFile(filePath, atomically: true)
                if strongSelf.diskOperationQueue.operationCount == 1 {
                    strongSelf.saved = true
                }
            }
        }
    }
    
    private func _getCachedData(completion completion: (NSData?)->()){
        diskOperationQueue.addOperationWithBlock {
            [weak self]() -> Void in

            if let
                folderName = self?.name,
                strongSelf = self
            {
                let folderPath = strongSelf._folderPathFromFolderName(folderName, insideCacheFolder: true)

                let filePath = (folderPath as NSString).stringByAppendingPathComponent(FeedCacheFileNames.genericArchiveName)
                let data = NSData(contentsOfFile: filePath)
                completion(data)
            }
            else {
                completion(nil)
            }
        }
    }
    
    
    private func _folderPathFromFolderName(folderName : String, insideCacheFolder: Bool) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        var libraryCachesDirectory: AnyObject = paths[0]
        
        if insideCacheFolder {
            libraryCachesDirectory = libraryCachesDirectory.stringByAppendingPathComponent(FeedCacheFileNames.apiCacheFolderName)
        }
        
        let folderPath = libraryCachesDirectory.stringByAppendingPathComponent(folderName)
        return folderPath
    }
    
    private func _createFolderIfNeeded(folderPath: String)  {
        if (!NSFileManager.defaultManager().fileExistsAtPath(folderPath)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(folderPath, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error as NSError {
                print(error)
            }
        }
    }

}