import Foundation

/**
 *  Simple countdown latch synchronization utility
 *  Commonly used to keep track of completion of background tasks
 */
struct CountdownLatch {

  /// Use dispatch group primitive
  let group: DispatchGroup

  /**
   Create new instance

   - returns: new CountdownLatch
   */
  init() {
    group = DispatchGroup()
  }

  /**
  Indicate that an item has started that we need to wait on
  */
  func add() {
    group.enter()
  }

  /**
  Indicate that an item we are waiting on has finished
  */
  func remove() {
    group.leave()
  }

  /**
  Block current thread until all items are complete, may block forever
  */
  func wait() {
    _ = group.wait(timeout: DispatchTime.distantFuture)
  }

  /**
  Block current thread until all items are complete or timeout occurs

  - parameter secondTimeout: seconds to wait before timing out

  - returns: true if all items complete before timeout, false if timeout occurred
  */
  func wait(_ secondTimeout: Int) -> Bool {
    let until = DispatchTime.now() + Double(Int64(secondTimeout) * 1000000000) / Double(NSEC_PER_SEC)
    return DispatchTimeoutResult.success == group.wait(timeout: until)
  }
}
