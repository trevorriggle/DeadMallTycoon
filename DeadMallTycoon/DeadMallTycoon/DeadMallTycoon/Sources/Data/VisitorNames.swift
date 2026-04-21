import Foundation

// v9 Prompt 4 Phase 1 — period-appropriate name pools for visitor identity.
// Weighted toward American births 1940s-1970s, Midwest distribution. Plain
// arrays, no generation logic — VisitorFactory picks uniformly.
//
// 75 first names · 40 last names.
enum VisitorNames {

    static let firstNames: [String] = [
        // 1940s-50s skew
        "Linda", "Robert", "Susan", "James", "Barbara", "Michael", "Mary",
        "David", "Patricia", "William", "Nancy", "Richard", "Carol",
        "Kenneth", "Sandra", "Donald", "Judith", "Charles", "Diane",
        "George", "Sharon", "Ronald", "Cheryl", "Thomas",
        // 1960s-70s skew
        "Karen", "Jeffrey", "Debbie", "Mark", "Kim", "Kevin", "Lisa",
        "Brian", "Michelle", "Scott", "Jennifer", "Greg", "Stephanie",
        "Jason", "Kristin", "Todd", "Amy", "Jeff", "Tammy", "Eric",
        "Kelly", "Craig", "Heather", "Doug", "Melissa",
        // 1970s-80s
        "Tyler", "Amber", "Brandon", "Jessica", "Ryan", "Nicole",
        "Justin", "Crystal", "Chad", "Tiffany", "Dustin", "Brittany",
        // Elder-coded
        "Eleanor", "Harold", "Betty", "Frank", "Dorothy", "Walter",
        "Ruth", "Arthur", "Mildred", "Raymond", "Evelyn", "Ernest",
        "Gloria", "Bernard",
    ]

    static let lastNames: [String] = [
        "Hansen", "Johnson", "Miller", "Anderson", "Wilson", "Thompson",
        "Davis", "Martin", "Clark", "Lewis", "Walker", "Hall",
        "Allen", "Young", "King", "Wright", "Scott", "Green",
        "Adams", "Baker", "Nelson", "Carter", "Mitchell", "Parker",
        "Evans", "Edwards", "Collins", "Stewart", "Morris", "Rogers",
        "Peterson", "Reed", "Cook", "Bailey", "Bell", "Gray",
        "Sullivan", "Ross", "Henderson", "Coleman",
    ]
}
