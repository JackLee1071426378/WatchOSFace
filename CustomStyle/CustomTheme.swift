//
//  CustomTheme.swift
//  SpriteWatchInterface
//
//  Created by 李弘辰 on 2019/6/16.
//  Copyright © 2019 李弘辰. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//

import Foundation

enum ThemeError : Error {
    case FileNotFound
    case DirectoryError
    case InformationFileError
    case ElementFileError
}

class CustomTheme
{
    
    var informationDict = [String : String]()
    var shouldWirteInformation = false
    
    var isFirstTmp : Bool
    var isExistsInDisk : Bool
    
    var name : String
    {
        didSet
        {
            informationDict["name"] = name
            shouldWirteInformation = true
        }
    }
    var time : String
    {
        didSet
        {
            informationDict["time"] = time
            shouldWirteInformation = true
        }
    }
    private(set) var rootDir : File
    private(set) var themeDir : File
    
    // Something like "~/.../.../SpriteClock", not theme directory
    init(name : String, time : String, rootDir : File, themeDirName : String)
    {
        self.name = name
        self.time = time
        informationDict["name"] = name
        informationDict["time"] = time
        self.rootDir = rootDir
        self.themeDir = self.rootDir.append(childName: "tmp_\(time)_\(themeDirName)")
        shouldWirteInformation = true
        isFirstTmp = true
        isExistsInDisk = false
    }
    
    // Something like "~/.../.../SpriteClock", not theme directory
    init(name : String, time : String, rootDirPath : String, themeDirName : String)
    {
        self.name = name
        self.time = time
        informationDict["name"] = name
        informationDict["time"] = time
        self.rootDir = File(path: rootDirPath)
        self.themeDir = self.rootDir.append(childName: "tmp_\(time)_\(themeDirName)")
        shouldWirteInformation = true
        isFirstTmp = true
        isExistsInDisk = false
    }
    
    private init(name : String, time : String, themeDir : File) throws
    {
        self.name = name
        self.time = time
        informationDict["name"] = name
        informationDict["time"] = time
        self.themeDir = themeDir
        self.rootDir = self.themeDir.getParentFile()
        if self.themeDir.path.elementsEqual(self.rootDir.path)
        {
            throw ThemeError.DirectoryError
        }
        isFirstTmp = themeDir.getName().hasPrefix("tmp_")
        isExistsInDisk = true
    }
    
    func commit() throws
    {
        // Remove "tmp_" if it has
        if themeDir.isDirectory()
        {
            let dirName = themeDir.getName()
            if dirName.hasPrefix("tmp_")
            {
                try themeDir.rename(to: String(dirName.suffix(dirName.count - 4)))
            }
            try write()
            isFirstTmp = false
        } else
        {
            throw ThemeError.FileNotFound
        }
    }
    
    func delete() throws
    {
        try themeDir.delete()
    }
}

// Read theme from directory
extension CustomTheme
{
    // Something like "~/.../.../SpriteClock/1560606239456254_theme1", theme directory
    static func read(themeDirPath : String) throws -> CustomTheme
    {
        return try read(themeDir: File(path: themeDirPath))
    }
    
    static func read(themeDir : File) throws -> CustomTheme
    {
        if themeDir.isDirectory()
        {
            // Read information.plist
            if let theme = try readInformation(themeDir: themeDir)
            {
                // Read elements.plist
                // 也要读elements.tmp，提示用户上次没保存
                // TODO: XXX
                
                
                return theme
            } else
            {
                throw ThemeError.InformationFileError
            }
        } else
        {
            throw ThemeError.FileNotFound
        }
    }
    
    private static func readInformation(themeDir : File) throws -> CustomTheme?
    {
        let information = themeDir.append(childName: "information.plist")
        if let nsDict = NSDictionary(contentsOfFile: information)
        {
            if let dict = nsDict as? Dictionary<String,String>, let name = dict["name"], let time = dict["time"]
            {
                return try CustomTheme(name: name, time: time, themeDir: themeDir)
            }
        }
        return nil
    }
}

// Write theme to disk
extension CustomTheme
{
    func write() throws
    {
        if !isExistsInDisk
        {
            // Try to create new temporary theme directory
            let _ = try themeDir.createDirectory(withIntermediateDirectories: true, attributes: nil)
        }
        if shouldWirteInformation
        {
            // Write information.plist
            try writeInformation()
        }
        try writeElements()
        isExistsInDisk = true
    }
    
    // Write information.plist
    private func writeInformation() throws
    {
        try (informationDict as NSDictionary).write(to: themeDir.append(childName: "information.plist"))
    }
    
    // 先elements.tmp文件，保存的时候再搞
    private func writeElements() throws
    {
        
    }
}

extension CustomTheme
{
    static func list(rootDir : File) -> [String]
    {
        
        var names = [String]()
        var times = [String]()
        if rootDir.isDirectory()
        {
            do
            {
                let dirs = try rootDir.list()
                for fileName in dirs
                {
                    if !fileName.contains("tmp"), let dict = NSDictionary(contentsOfFile: rootDir.append(childName: fileName).append(childName: "information.plist")) as? Dictionary<String, String>
                    {
                        let time = dict["time"]!
                        let name = dict["name"]!
                        if times.count == 0
                        {
                            times.append(time)
                            names.append(name)
                        } else {
                            var startIndex = 0
                            var endIndex = times.count - 1
                            var midIndex = (startIndex + endIndex) / 2
                            var right = false
                            while startIndex <= endIndex
                            {
                                right = false
                                midIndex = (startIndex + endIndex) / 2
                                if Double(time)! > Double(times[midIndex])!
                                {
                                    startIndex = midIndex + 1
                                    right = true
                                } else
                                {
                                    endIndex = midIndex - 1
                                }
                            }
                            if right { midIndex += 1 }
                            times.insert(time, at: midIndex)
                            names.insert(name, at: midIndex)
                        }
                    }
                }
            } catch {}
        }
        return names
    }
}









/*
 if let e = error as? ThemeError
 {
 switch e {
 case .DirectoryError:
 EasyMethod.showAlert("Something wrong with theme directory.", .critical)
 case .InformationFileError:
 EasyMethod.showAlert("Theme's information.plist has some problems.", .critical)
 case .FileNotFound:
 EasyMethod.showAlert("\"\(tmpName!)\" Not found!", .critical)
 default:
 EasyMethod.caughtError(error)
 }
 } else { EasyMethod.caughtError(error) }
 */
