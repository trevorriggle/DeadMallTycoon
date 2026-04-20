import Foundation

// v8: PERSONALITIES entry
struct Personality {
    let key: String
    let type: VisitorType
    let color: String                 // hex
    let headColor: String             // hex
    let ageRange: ClosedRange<Int>
    let preferredStores: [String]
    let thoughts: [MallState: [String]]
}

enum Personalities {

    // v8: TEEN_NAMES, ADULT_NAMES, ELDER_NAMES, KID_NAMES
    static let teenNames  = ["Brittany","Jason","Amber","Tyler","Jessica","Brandon","Heather","Kevin"]
    static let adultNames = ["Linda","David","Susan","Mike","Karen","Greg","Debbie","Steve"]
    static let elderNames = ["Eleanor","Harold","Betty","Frank","Dorothy","Walter","Ruth","Arthur"]
    static let kidNames   = ["Tommy","Emma","Billy","Sarah","Jake","Lily","Max","Chloe"]

    static func names(for type: VisitorType) -> [String] {
        switch type {
        case .teen:  return teenNames
        case .adult: return adultNames
        case .elder: return elderNames
        case .kid:   return kidNames
        }
    }

    // v8: PERSONALITIES
    // Thought strings are preserved verbatim (including curly quotes / apostrophes).
    static let all: [String: Personality] = [
        "Teen Rebel": Personality(
            key: "Teen Rebel", type: .teen, color: "#c4919a", headColor: "#e8b5b5",
            ageRange: 14...18,
            preferredStores: ["Hot Topic","Spencer's","Sam Goody","Vape Shop","GameStop"],
            thoughts: [
                .thriving:   ["\"This place is sick.\"", "\"Hot Topic has the new NIN shirt.\""],
                .fading:     ["\"Everyone's going to the other mall.\""],
                .struggling: ["\"This place has aura though.\""],
                .dying:      ["\"This is a backrooms level.\""],
                .dead:       ["\"Peak liminal.\""],
            ]
        ),
        "Teen Shopper": Personality(
            key: "Teen Shopper", type: .teen, color: "#d4a1a8", headColor: "#f0c5c5",
            ageRange: 13...17,
            preferredStores: ["Claire's","Hot Topic","Foot Locker","Auntie Anne's"],
            thoughts: [
                .thriving:   ["\"Mom gave me forty bucks.\""],
                .fading:     ["\"Claire's is always empty now.\""],
                .struggling: ["\"My mom says this used to be nice.\""],
                .dying:      ["\"There's nothing here anymore.\""],
                .dead:       ["\"Can we leave?\""],
            ]
        ),
        "Mall Walker": Personality(
            key: "Mall Walker", type: .elder, color: "#e8b888", headColor: "#f4d0a0",
            ageRange: 65...82,
            preferredStores: [],
            thoughts: [
                .thriving:   ["\"Fourth lap today.\""],
                .fading:     ["\"Not as many walkers anymore.\""],
                .struggling: ["\"I'll walk until they turn off the lights.\""],
                .dying:      ["\"Here the day it opened.\""],
                .dead:       ["\"I like the quiet.\""],
            ]
        ),
        "Nostalgic Dad": Personality(
            key: "Nostalgic Dad", type: .adult, color: "#6aada8", headColor: "#a0c8c4",
            ageRange: 35...48,
            preferredStores: ["Radio Shack","B. Dalton","Foot Locker"],
            thoughts: [
                .thriving:   ["\"My dad used to bring me here.\""],
                .fading:     ["\"Where did Waldenbooks go?\""],
                .struggling: ["\"Had my first job at Sam Goody.\""],
                .dying:      ["\"My kids will never know what a mall felt like.\""],
                .dead:       ["\"Goodbye, old friend.\""],
            ]
        ),
        "Suburban Mom": Personality(
            key: "Suburban Mom", type: .adult, color: "#a8c4b8", headColor: "#d0e0d4",
            ageRange: 30...45,
            preferredStores: ["Kay Jewelers","Bath & Body Works","Cinnabon","Sears"],
            thoughts: [
                .thriving:   ["\"Kids, stop running.\""],
                .fading:     ["\"Well it's still cheaper.\""],
                .struggling: ["\"Kids want to go to the new mall.\""],
                .dying:      ["\"I only come out of habit.\""],
                .dead:       ["\"Why did I come?\""],
            ]
        ),
        "Urbex Explorer": Personality(
            key: "Urbex Explorer", type: .teen, color: "#7f77dd", headColor: "#a8a0e8",
            ageRange: 19...26,
            preferredStores: [],
            thoughts: [
                .thriving:   ["\"Too alive for my content.\""],
                .fading:     ["\"Starting to get the vibe.\""],
                .struggling: ["\"Subscribers will love this.\""],
                .dying:      ["\"THIS is the footage.\""],
                .dead:       ["\"Drove four states for this.\""],
            ]
        ),
        "Goth Kid": Personality(
            key: "Goth Kid", type: .teen, color: "#3a2a3a", headColor: "#6a5a6a",
            ageRange: 15...19,
            preferredStores: ["Hot Topic","Spencer's"],
            thoughts: [
                .thriving:   ["\"Everyone here is a normie.\""],
                .fading:     ["\"The decay is aesthetic.\""],
                .struggling: ["\"Liminal decay. Incredible.\""],
                .dying:      ["\"I dream about this place.\""],
                .dead:       ["\"I'm home.\""],
            ]
        ),
        "Little Kid": Personality(
            key: "Little Kid", type: .kid, color: "#f4c8a8", headColor: "#ffdcc0",
            ageRange: 5...9,
            preferredStores: ["Claire's","Cinnabon","Orange Julius"],
            thoughts: [
                .thriving:   ["\"MOM CAN I GET THIS\"", "\"THE KUGEL BALL!\""],
                .fading:     ["\"Where's the toy store?\""],
                .struggling: ["\"It's kind of boring.\""],
                .dying:      ["\"Is the mall broken?\""],
                .dead:       ["\"I'm scared.\""],
            ]
        ),
        "Casual Browser": Personality(
            key: "Casual Browser", type: .adult, color: "#a0a0a0", headColor: "#c8c8c8",
            ageRange: 25...55,
            preferredStores: [],
            thoughts: [
                .thriving:   ["\"Just killing time.\""],
                .fading:     ["\"Is there a point?\""],
                .struggling: ["\"Needed to get out.\""],
                .dying:      ["\"Bored.\""],
                .dead:       ["\"Nothing to do.\""],
            ]
        ),
        "Photographer": Personality(
            key: "Photographer", type: .adult, color: "#2a5a5a", headColor: "#6a9a9a",
            ageRange: 22...38,
            preferredStores: [],
            thoughts: [
                .thriving:   ["\"Too much activity.\""],
                .fading:     ["\"Light through the skylight is perfect.\""],
                .struggling: ["\"These empty storefronts are cinematic.\""],
                .dying:      ["\"This is my best work.\""],
                .dead:       ["\"A ghost mall. My dream.\""],
            ]
        ),
        "Food Court Regular": Personality(
            key: "Food Court Regular", type: .adult, color: "#d4a874", headColor: "#e8c898",
            ageRange: 45...65,
            preferredStores: ["Cinnabon","Orange Julius","Auntie Anne's"],
            thoughts: [
                .thriving:   ["\"Same as yesterday, Linda.\""],
                .fading:     ["\"What do I eat now?\""],
                .struggling: ["\"The food court is half closed.\""],
                .dying:      ["\"Cinnabon lady knows my name.\""],
                .dead:       ["\"She told me it's her last week.\""],
            ]
        ),
        "Bargain Hunter": Personality(
            key: "Bargain Hunter", type: .adult, color: "#b8a874", headColor: "#d4c898",
            ageRange: 38...58,
            preferredStores: ["Claire's","Waldenbooks","Spencer's"],
            thoughts: [
                .thriving:   ["\"50% off!\""],
                .fading:     ["\"Clearance aisle thinned out.\""],
                .struggling: ["\"Everything's liquidation now.\""],
                .dying:      ["\"I feel like a vulture.\""],
                .dead:       ["\"Even the signs are on clearance.\""],
            ]
        ),
    ]

    // v8: P_WEIGHTS — stored as ordered tuple arrays so weighted picking is deterministic
    // across Swift runs (Dictionary iteration order is not guaranteed).
    static let weights: [MallState: [(String, Int)]] = [
        .thriving: [
            ("Teen Rebel", 12), ("Teen Shopper", 15), ("Mall Walker", 8),
            ("Nostalgic Dad", 10), ("Suburban Mom", 18), ("Food Court Regular", 8),
            ("Bargain Hunter", 10), ("Urbex Explorer", 0), ("Little Kid", 10),
            ("Goth Kid", 6), ("Casual Browser", 4), ("Photographer", 1),
        ],
        .fading: [
            ("Teen Rebel", 10), ("Teen Shopper", 10), ("Mall Walker", 10),
            ("Nostalgic Dad", 12), ("Suburban Mom", 12), ("Food Court Regular", 10),
            ("Bargain Hunter", 14), ("Urbex Explorer", 1), ("Little Kid", 6),
            ("Goth Kid", 6), ("Casual Browser", 6), ("Photographer", 2),
        ],
        .struggling: [
            ("Teen Rebel", 8), ("Teen Shopper", 5), ("Mall Walker", 12),
            ("Nostalgic Dad", 10), ("Suburban Mom", 6), ("Food Court Regular", 8),
            ("Bargain Hunter", 16), ("Urbex Explorer", 5), ("Little Kid", 3),
            ("Goth Kid", 10), ("Casual Browser", 8), ("Photographer", 6),
        ],
        .dying: [
            ("Teen Rebel", 4), ("Teen Shopper", 2), ("Mall Walker", 10),
            ("Nostalgic Dad", 12), ("Suburban Mom", 2), ("Food Court Regular", 5),
            ("Bargain Hunter", 8), ("Urbex Explorer", 15), ("Little Kid", 1),
            ("Goth Kid", 12), ("Casual Browser", 4), ("Photographer", 12),
        ],
        .dead: [
            ("Teen Rebel", 2), ("Teen Shopper", 0), ("Mall Walker", 6),
            ("Nostalgic Dad", 12), ("Suburban Mom", 1), ("Food Court Regular", 2),
            ("Bargain Hunter", 3), ("Urbex Explorer", 25), ("Little Kid", 0),
            ("Goth Kid", 14), ("Casual Browser", 2), ("Photographer", 20),
        ],
    ]
}
