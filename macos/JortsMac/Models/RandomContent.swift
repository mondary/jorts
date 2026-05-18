import Foundation

enum RandomContent {
    private static let titles = [
        "All my best friends",
        "My secret recipe",
        "My todo list",
        "Super secret to not tell anyone",
        "My grocery list",
        "Shower thoughts",
        "My fav fanfics",
        "My fav dinosaurs",
        "My evil mastermind plan",
        "What made me smile today",
        "Hello world!",
        "New sticky, new me",
        "Pirate treasure location",
        "To remember",
        "Dear Diary,",
        "Have a nice day! :)",
        "My meds schedule",
        "Household chores",
        "My cats favourite mischiefs",
        "My dogs favourite toys",
        "How cool my birds are",
        "Suspects in the Last Cookie affair",
        "Words my parrots know",
        "Original compliments to give out",
        "My dream Pokemon team",
        "My little notes",
        "Surprise gift list",
        "Brainstorming notes",
        "To bring to the party",
        "My amazing mixtape",
        "Margin scribbles",
        "My fav songs to sing along",
        "When to water which plant",
        "Top 10 anime betrayals",
        "Amazing ascii art!",
        "For the barbecue",
        "My favourite bands",
        "Best ingredients for salad",
        "Books to read",
        "Places to visit",
        "Hobbies to try out",
        "Who would win against Goku",
        "To plant in the garden",
        "Meals this week",
        "Everyone's pizza order",
        "Today selfcare to do",
        "Important affirmations to remember",
        "The coolest linux apps",
        "My favourite dishes",
        "My funniest jokes",
        "The perfect breakfast",
        "What makes me smile",
        "Most interesting characters",
        "Activities to do with friends"
    ]

    static func title() -> String {
        titles.randomElement() ?? "New sticky, new me"
    }

    static func newNoteData(skipping skippedTheme: NoteTheme?) -> NoteData {
        var note = NoteData(theme: NoteTheme.random(excluding: skippedTheme))

        if Int.random(in: 0..<1000) == 1 {
            note.title = "🔥WOW Congratulations!🔥"
            note.content = """
            You have found the Golden Sticky Note!

            CRAZY BUT TRU: This message appears once in a thousand times!
            Nobody will believe you hehehe ;)

            I hope my little app brings you a lot of joy
            Have a great day!🎇
            """
            note.theme = .banana
        }

        return note
    }
}
