//
//  Mission.swift
//  MarsImagesIOS
//
//  Created by Mark Powell on 7/27/17.
//  Copyright © 2017 Mark Powell. All rights reserved.
//

import Foundation

class Mission {
    static let names = [ OPPORTUNITY, SPIRIT, CURIOSITY ]
    static let missionKey = "mission"
    static let OPPORTUNITY = "Opportunity"
    static let SPIRIT = "Spirit"
    static let CURIOSITY = "Curiosity"
    let EARTH_SECS_PER_MARS_SEC = 1.027491252
    static let missions:[String:Mission] = [OPPORTUNITY: Opportunity(), SPIRIT: Spirit(), CURIOSITY: Curiosity()]
    
    var epoch:Date?
    var formatter:DateFormatter
    
    static func currentMission() -> Mission {
        return missions[currentMissionName()]!
    }
    
    static func currentMissionName() -> String {
        let userDefaults = UserDefaults.standard
        if userDefaults.value(forKey: missionKey) == nil {
            userDefaults.set(OPPORTUNITY, forKey: missionKey)
            userDefaults.synchronize()
        }
        return userDefaults.value(forKey: missionKey) as! String
    }
    
    func sol(_ title: String) -> Int {
        let tokens = title.components(separatedBy: " ")
        if tokens.count >= 2 {
            return Int(tokens[1])!
        }
        return 0;
    }
    
    init() {
        self.formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .long
    }
    
    func rowTitle(_ title: String) -> String {
        return title
    }
    
    func subtitle(_ title: String) -> String {
        let marstime = tokenize(title).marsLocalTime
        return "\(marstime) LST"
    }
    
    func tokenize(_ title: String) -> Title {
        return Title()
    }
    
    func getSortableImageFilename(url: String) -> String {
        return url
    }

    func solAndDate(sol:Int) -> String {
        let interval = Double(sol*24*60*60)*EARTH_SECS_PER_MARS_SEC
        let imageDate = Date(timeInterval: interval, since: epoch!)
        let formattedDate = formatter.string(from: imageDate)
        return "Sol \(sol) \(formattedDate)"
    }
}

class Title {
    var sol = 0
    var imageSetID = ""
    var instrumentName = ""
    var marsLocalTime = ""
    var siteIndex = 0
    var driveIndex = 0
}