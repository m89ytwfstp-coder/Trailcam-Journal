//
//  SpeciesCatalog.swift
//  Trailcam Journal
//

import Foundation

struct Species: Identifiable, Hashable, Codable {
    let id: String                 // stable key (e.g. "wolverine")
    let nameNO: String             // display name (e.g. "Jerv")
    let nameEN: String?
    let group: SpeciesGroup
    let thumbnailName: String      // kept for now; may be removed later
    let latinName: String          // used for iNaturalist lookup

    var displayName: String { nameNO }
}

enum SpeciesGroup: String, CaseIterable, Codable {
    case mammal
    case bird
    case fish
    case other
}

enum SpeciesCatalog {
    static let all: [Species] = mammals + birds + fish + other

    // MARK: - Mammals
    static let mammals: [Species] = [
        Species(id: "brown_bear",   nameNO: "Bjørn",      nameEN: "Brown bear",       group: .mammal, thumbnailName: "brown_bear",   latinName: "Ursus arctos"),
        Species(id: "red_fox",      nameNO: "Rødrev",     nameEN: "Red fox",           group: .mammal, thumbnailName: "red_fox",       latinName: "Vulpes vulpes"),
        Species(id: "arctic_fox",   nameNO: "Fjellrev",   nameEN: "Arctic fox",        group: .mammal, thumbnailName: "arctic_fox",    latinName: "Vulpes lagopus"),
        Species(id: "moose",        nameNO: "Elg",        nameEN: "Moose",             group: .mammal, thumbnailName: "moose",         latinName: "Alces alces"),
        Species(id: "lynx",         nameNO: "Gaupe",      nameEN: "Lynx",              group: .mammal, thumbnailName: "lynx",          latinName: "Lynx lynx"),
        Species(id: "roe_deer",     nameNO: "Rådyr",      nameEN: "Roe deer",          group: .mammal, thumbnailName: "roe_deer",      latinName: "Capreolus capreolus"),
        Species(id: "red_deer",     nameNO: "Hjort",      nameEN: "Red deer",          group: .mammal, thumbnailName: "red_deer",      latinName: "Cervus elaphus"),
        Species(id: "wolverine",    nameNO: "Jerv",       nameEN: "Wolverine",         group: .mammal, thumbnailName: "wolverine",     latinName: "Gulo gulo"),
        Species(id: "pine_marten",  nameNO: "Mår",        nameEN: "Pine marten",       group: .mammal, thumbnailName: "pine_marten",   latinName: "Martes martes"),
        Species(id: "weasel",       nameNO: "Røyskatt",   nameEN: "Weasel",            group: .mammal, thumbnailName: "weasel",        latinName: "Mustela nivalis"),
        Species(id: "otter",        nameNO: "Oter",       nameEN: "Otter",             group: .mammal, thumbnailName: "otter",         latinName: "Lutra lutra"),
        Species(id: "badger",       nameNO: "Grevling",   nameEN: "Badger",            group: .mammal, thumbnailName: "badger",        latinName: "Meles meles"),
        Species(id: "hare",         nameNO: "Hare",       nameEN: "Hare",              group: .mammal, thumbnailName: "hare",          latinName: "Lepus timidus"),
        Species(id: "squirrel",     nameNO: "Ekorn",      nameEN: "Red squirrel",      group: .mammal, thumbnailName: "squirrel",      latinName: "Sciurus vulgaris"),
        Species(id: "beaver",       nameNO: "Bever",      nameEN: "Beaver",            group: .mammal, thumbnailName: "beaver",        latinName: "Castor fiber"),
        Species(id: "wolf",         nameNO: "Ulv",        nameEN: "Wolf",              group: .mammal, thumbnailName: "wolf",          latinName: "Canis lupus"),
        Species(id: "mouse",        nameNO: "Mus",        nameEN: "Mouse",             group: .mammal, thumbnailName: "mouse",         latinName: "Apodemus sylvaticus"),
        Species(id: "reindeer",     nameNO: "Rein",       nameEN: "Reindeer",          group: .mammal, thumbnailName: "reindeer",      latinName: "Rangifer tarandus"),
        Species(id: "mink",         nameNO: "Mink",       nameEN: "American mink",     group: .mammal, thumbnailName: "mink",          latinName: "Neovison vison"),
        Species(id: "stoat",        nameNO: "Snømus",     nameEN: "Stoat",             group: .mammal, thumbnailName: "stoat",         latinName: "Mustela erminea"),
        Species(id: "wild_boar",    nameNO: "Villsvin",   nameEN: "Wild boar",         group: .mammal, thumbnailName: "wild_boar",     latinName: "Sus scrofa"),
        Species(id: "fallow_deer",  nameNO: "Dådyr",      nameEN: "Fallow deer",       group: .mammal, thumbnailName: "fallow_deer",   latinName: "Dama dama"),
        Species(id: "musk_ox",      nameNO: "Moskusfe",   nameEN: "Musk ox",           group: .mammal, thumbnailName: "musk_ox",       latinName: "Ovibos moschatus"),
        Species(id: "polecat",      nameNO: "Ilder",      nameEN: "Polecat",           group: .mammal, thumbnailName: "polecat",       latinName: "Mustela putorius"),
        Species(id: "water_vole",   nameNO: "Vånd",       nameEN: "Water vole",        group: .mammal, thumbnailName: "water_vole",    latinName: "Arvicola amphibius"),
    ]

    // MARK: - Birds
    static let birds: [Species] = [
        // Galliformes
        Species(id: "capercaillie",  nameNO: "Storfugl",    nameEN: "Capercaillie",         group: .bird, thumbnailName: "capercaillie",  latinName: "Tetrao urogallus"),
        Species(id: "black_grouse",  nameNO: "Orrfugl",     nameEN: "Black grouse",          group: .bird, thumbnailName: "black_grouse",  latinName: "Lyrurus tetrix"),
        Species(id: "ptarmigan",     nameNO: "Rype",        nameEN: "Ptarmigan",             group: .bird, thumbnailName: "ptarmigan",     latinName: "Lagopus muta"),
        Species(id: "hazel_grouse",  nameNO: "Jerpe",       nameEN: "Hazel grouse",          group: .bird, thumbnailName: "hazel_grouse",  latinName: "Tetrastes bonasia"),
        Species(id: "pheasant",      nameNO: "Fasan",       nameEN: "Pheasant",              group: .bird, thumbnailName: "pheasant",      latinName: "Phasianus colchicus"),
        // Corvids
        Species(id: "crow",          nameNO: "Kråke",       nameEN: "Hooded crow",           group: .bird, thumbnailName: "crow",          latinName: "Corvus cornix"),
        Species(id: "magpie",        nameNO: "Skjære",      nameEN: "Magpie",                group: .bird, thumbnailName: "magpie",        latinName: "Pica pica"),
        Species(id: "jay",           nameNO: "Nøtteskrike", nameEN: "Eurasian jay",          group: .bird, thumbnailName: "jay",           latinName: "Garrulus glandarius"),
        Species(id: "raven",         nameNO: "Ravn",        nameEN: "Raven",                 group: .bird, thumbnailName: "raven",         latinName: "Corvus corax"),
        Species(id: "jackdaw",       nameNO: "Kaie",        nameEN: "Jackdaw",               group: .bird, thumbnailName: "jackdaw",       latinName: "Corvus monedula"),
        Species(id: "nutcracker",    nameNO: "Nøttekråke",  nameEN: "Spotted nutcracker",    group: .bird, thumbnailName: "nutcracker",    latinName: "Nucifraga caryocatactes"),
        // Raptors — eagles
        Species(id: "white_tailed_eagle", nameNO: "Havørn",  nameEN: "White-tailed eagle",  group: .bird, thumbnailName: "white_tailed_eagle",  latinName: "Haliaeetus albicilla"),
        Species(id: "golden_eagle",  nameNO: "Kongeørn",    nameEN: "Golden eagle",          group: .bird, thumbnailName: "golden_eagle",  latinName: "Aquila chrysaetos"),
        Species(id: "osprey",        nameNO: "Fiskeørn",    nameEN: "Osprey",                group: .bird, thumbnailName: "osprey",        latinName: "Pandion haliaetus"),
        Species(id: "rough_legged_buzzard", nameNO: "Fjellvåk", nameEN: "Rough-legged buzzard", group: .bird, thumbnailName: "rough_legged_buzzard", latinName: "Buteo lagopus"),
        Species(id: "buzzard",       nameNO: "Musvåk",      nameEN: "Common buzzard",        group: .bird, thumbnailName: "buzzard",       latinName: "Buteo buteo"),
        Species(id: "honey_buzzard", nameNO: "Vepsevåk",    nameEN: "Honey buzzard",         group: .bird, thumbnailName: "honey_buzzard", latinName: "Pernis apivorus"),
        Species(id: "goshawk",       nameNO: "Hønsehauk",   nameEN: "Goshawk",               group: .bird, thumbnailName: "goshawk",       latinName: "Accipiter gentilis"),
        Species(id: "sparrowhawk",   nameNO: "Spurvehauk",  nameEN: "Sparrowhawk",           group: .bird, thumbnailName: "sparrowhawk",   latinName: "Accipiter nisus"),
        Species(id: "peregrine",     nameNO: "Vandrefalk",  nameEN: "Peregrine falcon",      group: .bird, thumbnailName: "peregrine",     latinName: "Falco peregrinus"),
        Species(id: "kestrel",       nameNO: "Tårnfalk",    nameEN: "Kestrel",               group: .bird, thumbnailName: "kestrel",       latinName: "Falco tinnunculus"),
        Species(id: "merlin",        nameNO: "Dvergfalk",   nameEN: "Merlin",                group: .bird, thumbnailName: "merlin",        latinName: "Falco columbarius"),
        // Owls
        Species(id: "tawny_owl",     nameNO: "Kattugle",    nameEN: "Tawny owl",             group: .bird, thumbnailName: "tawny_owl",     latinName: "Strix aluco"),
        Species(id: "great_grey_owl",nameNO: "Lappugle",    nameEN: "Great grey owl",        group: .bird, thumbnailName: "great_grey_owl",latinName: "Strix nebulosa"),
        Species(id: "long_eared_owl",nameNO: "Hornugle",    nameEN: "Long-eared owl",        group: .bird, thumbnailName: "long_eared_owl",latinName: "Asio otus"),
        Species(id: "tengmalms_owl", nameNO: "Perleugle",   nameEN: "Tengmalm's owl",        group: .bird, thumbnailName: "tengmalms_owl", latinName: "Aegolius funereus"),
        Species(id: "pygmy_owl",     nameNO: "Spurveugle",  nameEN: "Pygmy owl",             group: .bird, thumbnailName: "pygmy_owl",     latinName: "Glaucidium passerinum"),
        Species(id: "barn_owl",      nameNO: "Tårnugle",    nameEN: "Barn owl",              group: .bird, thumbnailName: "barn_owl",      latinName: "Tyto alba"),
        Species(id: "snowy_owl",     nameNO: "Snøugle",     nameEN: "Snowy owl",             group: .bird, thumbnailName: "snowy_owl",     latinName: "Bubo scandiacus"),
        Species(id: "hawk_owl",      nameNO: "Haukugle",    nameEN: "Hawk owl",              group: .bird, thumbnailName: "hawk_owl",      latinName: "Surnia ulula"),
        // Woodpeckers
        Species(id: "great_spotted_woodpecker",  nameNO: "Flaggspett",   nameEN: "Great spotted woodpecker",  group: .bird, thumbnailName: "great_spotted_woodpecker",  latinName: "Dendrocopos major"),
        Species(id: "black_woodpecker",          nameNO: "Svartspett",   nameEN: "Black woodpecker",          group: .bird, thumbnailName: "black_woodpecker",          latinName: "Dryocopus martius"),
        Species(id: "three_toed_woodpecker",     nameNO: "Tretåspett",   nameEN: "Three-toed woodpecker",     group: .bird, thumbnailName: "three_toed_woodpecker",     latinName: "Picoides tridactylus"),
        Species(id: "lesser_spotted_woodpecker", nameNO: "Dvergspett",   nameEN: "Lesser spotted woodpecker", group: .bird, thumbnailName: "lesser_spotted_woodpecker", latinName: "Dryobates minor"),
        Species(id: "grey_headed_woodpecker",    nameNO: "Gråspett",     nameEN: "Grey-headed woodpecker",    group: .bird, thumbnailName: "grey_headed_woodpecker",    latinName: "Picus canus"),
        Species(id: "white_backed_woodpecker",   nameNO: "Hvitryggspett",nameEN: "White-backed woodpecker",  group: .bird, thumbnailName: "white_backed_woodpecker",   latinName: "Dendrocopos leucotos"),
        Species(id: "wryneck",                   nameNO: "Vendehals",    nameEN: "Wryneck",                   group: .bird, thumbnailName: "wryneck",                   latinName: "Jynx torquilla"),
        // Tits
        Species(id: "great_tit",      nameNO: "Kjøttmeis",  nameEN: "Great tit",             group: .bird, thumbnailName: "great_tit",      latinName: "Parus major"),
        Species(id: "blue_tit",       nameNO: "Blåmeis",    nameEN: "Blue tit",              group: .bird, thumbnailName: "blue_tit",       latinName: "Cyanistes caeruleus"),
        Species(id: "coal_tit",       nameNO: "Svartmeis",  nameEN: "Coal tit",              group: .bird, thumbnailName: "coal_tit",       latinName: "Periparus ater"),
        Species(id: "marsh_tit",      nameNO: "Granmeis",   nameEN: "Marsh tit",             group: .bird, thumbnailName: "marsh_tit",      latinName: "Poecile palustris"),
        Species(id: "willow_tit",     nameNO: "Lappmeis",   nameEN: "Willow tit",            group: .bird, thumbnailName: "willow_tit",     latinName: "Poecile montanus"),
        Species(id: "crested_tit",    nameNO: "Toppmeis",   nameEN: "Crested tit",           group: .bird, thumbnailName: "crested_tit",    latinName: "Lophophanes cristatus"),
        Species(id: "long_tailed_tit",nameNO: "Stjertmeis", nameEN: "Long-tailed tit",       group: .bird, thumbnailName: "long_tailed_tit",latinName: "Aegithalos caudatus"),
        // Thrushes
        Species(id: "fieldfare",     nameNO: "Gråtrost",    nameEN: "Fieldfare",             group: .bird, thumbnailName: "fieldfare",     latinName: "Turdus pilaris"),
        Species(id: "redwing",       nameNO: "Rødvingetrost",nameEN: "Redwing",              group: .bird, thumbnailName: "redwing",       latinName: "Turdus iliacus"),
        Species(id: "song_thrush",   nameNO: "Måltrost",    nameEN: "Song thrush",           group: .bird, thumbnailName: "song_thrush",   latinName: "Turdus philomelos"),
        Species(id: "mistle_thrush", nameNO: "Duetrost",    nameEN: "Mistle thrush",         group: .bird, thumbnailName: "mistle_thrush", latinName: "Turdus viscivorus"),
        Species(id: "ring_ouzel",    nameNO: "Ringtrost",   nameEN: "Ring ouzel",            group: .bird, thumbnailName: "ring_ouzel",    latinName: "Turdus torquatus"),
        Species(id: "blackbird",     nameNO: "Svarttrost",  nameEN: "Blackbird",             group: .bird, thumbnailName: "blackbird",     latinName: "Turdus merula"),
        // Other passerines
        Species(id: "bullfinch",     nameNO: "Dompap",      nameEN: "Bullfinch",             group: .bird, thumbnailName: "bullfinch",     latinName: "Pyrrhula pyrrhula"),
        Species(id: "crossbill",     nameNO: "Grankorsnebb",nameEN: "Common crossbill",      group: .bird, thumbnailName: "crossbill",     latinName: "Loxia curvirostra"),
        Species(id: "brambling",     nameNO: "Bjørkefink",  nameEN: "Brambling",             group: .bird, thumbnailName: "brambling",     latinName: "Fringilla montifringilla"),
        Species(id: "chaffinch",     nameNO: "Bokfink",     nameEN: "Chaffinch",             group: .bird, thumbnailName: "chaffinch",     latinName: "Fringilla coelebs"),
        Species(id: "goldcrest",     nameNO: "Fuglekonge",  nameEN: "Goldcrest",             group: .bird, thumbnailName: "goldcrest",     latinName: "Regulus regulus"),
        Species(id: "treecreeper",   nameNO: "Trekryper",   nameEN: "Treecreeper",           group: .bird, thumbnailName: "treecreeper",   latinName: "Certhia familiaris"),
        Species(id: "nuthatch",      nameNO: "Spettmeis",   nameEN: "Nuthatch",              group: .bird, thumbnailName: "nuthatch",      latinName: "Sitta europaea"),
        Species(id: "dipper",        nameNO: "Fossekall",   nameEN: "Dipper",                group: .bird, thumbnailName: "dipper",        latinName: "Cinclus cinclus"),
        Species(id: "wren",          nameNO: "Gjerdesmett", nameEN: "Wren",                  group: .bird, thumbnailName: "wren",          latinName: "Troglodytes troglodytes"),
        Species(id: "robin",         nameNO: "Rødstrupe",   nameEN: "Robin",                 group: .bird, thumbnailName: "robin",         latinName: "Erithacus rubecula"),
        Species(id: "redstart",      nameNO: "Rødstjert",   nameEN: "Common redstart",       group: .bird, thumbnailName: "redstart",      latinName: "Phoenicurus phoenicurus"),
        Species(id: "pied_flycatcher",nameNO: "Svarthvit fluesnapper", nameEN: "Pied flycatcher", group: .bird, thumbnailName: "pied_flycatcher", latinName: "Ficedula hypoleuca"),
        // Heron
        Species(id: "heron",         nameNO: "Hegre",       nameEN: "Grey heron",            group: .bird, thumbnailName: "heron",         latinName: "Ardea cinerea"),
        // Ducks & waterfowl
        Species(id: "goldeneye",     nameNO: "Kvinand",     nameEN: "Goldeneye",             group: .bird, thumbnailName: "goldeneye",     latinName: "Bucephala clangula"),
        Species(id: "mallard",       nameNO: "Stokkand",    nameEN: "Mallard",               group: .bird, thumbnailName: "mallard",       latinName: "Anas platyrhynchos"),
        Species(id: "teal",          nameNO: "Krikkand",    nameEN: "Teal",                  group: .bird, thumbnailName: "teal",          latinName: "Anas crecca"),
        Species(id: "whooper_swan",  nameNO: "Sangsvane",   nameEN: "Whooper swan",          group: .bird, thumbnailName: "whooper_swan",  latinName: "Cygnus cygnus"),
        Species(id: "greylag_goose", nameNO: "Grågås",      nameEN: "Greylag goose",         group: .bird, thumbnailName: "greylag_goose", latinName: "Anser anser"),
        // Waders
        Species(id: "golden_plover", nameNO: "Heilo",       nameEN: "Golden plover",         group: .bird, thumbnailName: "golden_plover", latinName: "Pluvialis apricaria"),
        Species(id: "woodcock",      nameNO: "Rugde",       nameEN: "Woodcock",              group: .bird, thumbnailName: "woodcock",      latinName: "Scolopax rusticola"),
        Species(id: "snipe",         nameNO: "Enkeltbekkasin", nameEN: "Common snipe",       group: .bird, thumbnailName: "snipe",         latinName: "Gallinago gallinago"),
        // Cuckoo
        Species(id: "cuckoo",        nameNO: "Gjøk",        nameEN: "Common cuckoo",         group: .bird, thumbnailName: "cuckoo",        latinName: "Cuculus canorus"),
    ]

    // MARK: - Fish
    static let fish: [Species] = [
        Species(id: "atlantic_salmon", nameNO: "Laks",   nameEN: "Atlantic salmon", group: .fish, thumbnailName: "atlantic_salmon", latinName: "Salmo salar"),
        Species(id: "brown_trout",     nameNO: "Ørret",  nameEN: "Brown trout",     group: .fish, thumbnailName: "brown_trout",     latinName: "Salmo trutta"),
        Species(id: "arctic_char",     nameNO: "Røye",   nameEN: "Arctic char",     group: .fish, thumbnailName: "arctic_char",     latinName: "Salvelinus alpinus"),
        Species(id: "pike",            nameNO: "Gjedde", nameEN: "Pike",            group: .fish, thumbnailName: "pike",            latinName: "Esox lucius"),
        Species(id: "perch",           nameNO: "Abbor",  nameEN: "Perch",           group: .fish, thumbnailName: "perch",           latinName: "Perca fluviatilis"),
        Species(id: "grayling",        nameNO: "Harr",   nameEN: "Grayling",        group: .fish, thumbnailName: "grayling",        latinName: "Thymallus thymallus"),
    ]

    // MARK: - Other
    static let other: [Species] = [
        Species(id: "adder",       nameNO: "Hoggorm",  nameEN: "Common adder",  group: .other, thumbnailName: "adder",       latinName: "Vipera berus"),
        Species(id: "grass_snake", nameNO: "Buorm",    nameEN: "Grass snake",   group: .other, thumbnailName: "grass_snake", latinName: "Natrix natrix"),
        Species(id: "frog",        nameNO: "Frosk",    nameEN: "Common frog",   group: .other, thumbnailName: "frog",        latinName: "Rana temporaria"),
        Species(id: "toad",        nameNO: "Padde",    nameEN: "Common toad",   group: .other, thumbnailName: "toad",        latinName: "Bufo bufo"),
        Species(id: "hedgehog",    nameNO: "Pinnsvin", nameEN: "Hedgehog",      group: .other, thumbnailName: "hedgehog",    latinName: "Erinaceus europaeus"),
    ]
}
