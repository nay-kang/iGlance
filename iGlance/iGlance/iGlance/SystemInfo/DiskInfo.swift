//  Copyright (C) 2020  D0miH <https://github.com/D0miH> & Contributors <https://github.com/iglance/iGlance/graphs/contributors>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import CocoaLumberjack
import IOKit
import OSLog

class DiskInfo {
    /**
     *  Returns the named tuple of used disk space and free disk space in bytes
     */
    static func getFreeDiskUsageInfo() -> (usedSpace: Int, freeSpace: Int) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let totalSpace = values.volumeTotalCapacity
            let freeSpace = values.volumeAvailableCapacity
            return (totalSpace! - freeSpace!, freeSpace!)
        } catch {
            DDLogError("Error retrieving capacity: \(error.localizedDescription)")
        }
        return (0, 0)
    }

    private static var _parent: io_registry_entry_t?
    private static var _lastRead: Int64 = 0
    private static var _lastWrite: Int64 = 0

    static func getActivityStat() -> (read: Int64, write: Int64) {
        var diffRead: Int64 = 0
        var diffWrite: Int64 = 0
        if _parent == nil {
            let keys: [URLResourceKey] = [.volumeNameKey]
            let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)
            guard let session = DASessionCreate(kCFAllocatorDefault) else {
                DDLogError("cannot create a DASession")
                return (diffRead, diffWrite)
            }
            if let url = paths?.first {
                if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                    if let diskName = DADiskGetBSDName(disk) {
                        let BSDName = String(cString: diskName)
                        let partitionLevel = BSDName.filter { "0"..."9" ~= $0 }.count
                        _parent = getDeviceIOParent(DADiskCopyIOMedia(disk), level: Int(partitionLevel))!
                    }
                }
            }
        }

        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(_parent!, &properties, kCFAllocatorDefault, 0) != kIOReturnSuccess {
            DDLogError("IORegistryEntryCreateCFProperties error")
            return (diffRead, diffWrite)
        }
        defer {
            properties?.release()
        }

        let props = (properties?.takeUnretainedValue())! as NSDictionary

        if let statistic = props.object(forKey: "Statistics") as? NSDictionary {
            let readBytes = statistic.object(forKey: "Bytes (Read)") as? Int64 ?? 0
            let writeBytes = statistic.object(forKey: "Bytes (Write)") as? Int64 ?? 0
            diffRead = readBytes - _lastRead
            diffWrite = writeBytes - _lastWrite
            _lastRead = readBytes
            _lastWrite = writeBytes
            DDLogInfo("reads: \(readBytes) writes: \(writeBytes)")
        }
        return (diffRead, diffWrite)
    }
}

// https://opensource.apple.com/source/bless/bless-152/libbless/APFS/BLAPFSUtilities.c.auto.html
public func getDeviceIOParent(_ obj: io_registry_entry_t, level: Int) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0

    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }

    for _ in 1...level {
        if IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent) != KERN_SUCCESS {
            IOObjectRelease(parent)
            return nil
        }
    }

    return parent
}
