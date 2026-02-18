//
//  SpeciesCatalog.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 18/12/2025.
//

import Foundation

struct Species: Identifiable, Hashable, Codable {
    let id: String                 // stable key (e.g. "wolverine")
    let nameNO: String             // display name (e.g. "Jerv")
    let nameEN: String?
    let group: SpeciesGroup

    // NEW
    let thumbnailName: String      // asset name in Assets.xcassets

    var displayName: String { nameNO }
}


enum SpeciesGroup: String, CaseIterable, Codable {
    case mammal
    case bird
}

enum SpeciesCatalog {
    static let all: [Species] = [

        // MARK: - Mammals
        Species(
                   id: "brown_bear",
                   nameNO: "Bjørn",
                   nameEN: "Brown bear",
                   group: .mammal,
                   thumbnailName: "brown_bear"
               ),
               Species(
                   id: "red_fox",
                   nameNO: "Rødrev",
                   nameEN: "Red fox",
                   group: .mammal,
                   thumbnailName: "red_fox"
               ),
               Species(
                    id: "arctic_fox",
                    nameNO: "Fjellrev",
                    nameEN: "Arctic fox",
                    group: .mammal,
                    thumbnailName: "arctic_fox"
               ),
               Species(
                   id: "moose",
                   nameNO: "Elg",
                   nameEN: "Moose",
                   group: .mammal,
                   thumbnailName: "moose"
               ),
               Species(
                   id: "lynx",
                   nameNO: "Gaupe",
                   nameEN: "Lynx",
                   group: .mammal,
                   thumbnailName: "lynx"
               ),
               Species(
                   id: "roe_deer",
                   nameNO: "Rådyr",
                   nameEN: "Roe deer",
                   group: .mammal,
                   thumbnailName: "roe_deer"
               ),
               Species(
                   id: "red_deer",
                   nameNO: "Hjort",
                   nameEN: "Red deer",
                   group: .mammal,
                   thumbnailName: "red_deer"
               ),
               Species(
                   id: "wolverine",
                   nameNO: "Jerv",
                   nameEN: "Wolverine",
                   group: .mammal,
                   thumbnailName: "wolverine"
               ),
               Species(
                    id: "pine_marten",
                    nameNO: "Mår",
                    nameEN: "Pine marten",
                    group: .mammal,
                    thumbnailName: "pine_marten"
               ),
               Species(
                    id: "weasel",
                    nameNO: "Røyskatt",
                    nameEN: "Weasel",
                    group: .mammal,
                    thumbnailName: "weasel"
               ),
               Species(
                   id: "otter",
                   nameNO: "Oter",
                   nameEN: "Otter",
                   group: .mammal,
                   thumbnailName: "otter"
               ),
               Species(
                   id: "badger",
                   nameNO: "Grevling",
                   nameEN: "Badger",
                   group: .mammal,
                   thumbnailName: "badger"
               ),
               Species(
                   id: "hare",
                   nameNO: "Hare",
                   nameEN: "Hare",
                   group: .mammal,
                   thumbnailName: "hare"
               ),
               Species(
                   id: "squirrel",
                   nameNO: "Ekorn",
                   nameEN: "Red squirrel",
                   group: .mammal,
                   thumbnailName: "squirrel"
               ),
               Species(
                   id: "beaver",
                   nameNO: "Bever",
                   nameEN: "Beaver",
                   group: .mammal,
                   thumbnailName: "beaver"
               ),
               Species(
                   id: "wolf",
                   nameNO: "Ulv",
                   nameEN: "Wolf",
                   group: .mammal,
                   thumbnailName: "wolf"
               ),
               Species(
                   id: "mouse",
                   nameNO: "Mus",
                   nameEN: "Mouse",
                   group: .mammal,
                   thumbnailName: "mouse"
               ),

               // MARK: - Birds
               Species(
                   id: "capercaillie",
                   nameNO: "Storfugl",
                   nameEN: "Capercaillie",
                   group: .bird,
                   thumbnailName: "capercaillie"
               ),
               Species(
                   id: "black_grouse",
                   nameNO: "Orrfugl",
                   nameEN: "Black grouse",
                   group: .bird,
                   thumbnailName: "black_grouse"
               ),
               Species(
                   id: "ptarmigan",
                   nameNO: "Rype",
                   nameEN: "Ptarmigan",
                   group: .bird,
                   thumbnailName: "ptarmigan"
               ),
               Species(
                   id: "crow",
                   nameNO: "Kråke",
                   nameEN: "Crow",
                   group: .bird,
                   thumbnailName: "crow"
               ),
               Species(
                   id: "magpie",
                   nameNO: "Skjære",
                   nameEN: "Magpie",
                   group: .bird,
                   thumbnailName: "magpie"
               ),
               Species(
                   id: "jay",
                   nameNO: "Nøtteskrike",
                   nameEN: "Eurasian jay",
                   group: .bird,
                   thumbnailName: "jay"
               ),
               Species(
                   id: "raven",
                   nameNO: "Ravn",
                   nameEN: "Raven",
                   group: .bird,
                   thumbnailName: "raven"
               ),
               Species(
                   id: "heron",
                   nameNO: "Hegre",
                   nameEN: "Heron",
                   group: .bird,
                   thumbnailName: "heron"
               )
           ]
       }

