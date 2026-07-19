import Foundation
import UserNotifications

struct FinanceNotificationHelper {
    
    // MARK: - Funny Messages
    static let foodMessages = [
        ("Hey, you gotta eat! 🍕", "Fuel for the engine. Enjoy every bite!"),
        ("Yum! 🍔", "Hope it tastes as good as it costs!"),
        ("Chef's Kiss 👩‍🍳", "Treat yourself, you deserve it."),
        ("Grocery Run 🛒", "Fridge fully stocked? Nice work."),
        ("Snack Attack 🥨", "A little snack never hurt nobody.")
    ]
    
    static let transportMessages = [
        ("Vroom Vroom 🚗", "The car needs juice too!"),
        ("On the Move 💨", "Getting from A to B safely."),
        ("Gas Tank Full ⛽", "Ready for the next adventure."),
        ("Ticket to Ride 🎫", "Commuting like a pro."),
        ("Smooth Sailing ⛵", "Keep moving forward!")
    ]
    
    static let billsMessages = [
        ("Adulting is Hard 💼", "Bills don't stop for anyone, but you got this."),
        ("Responsible Choice 📜", "Keeping the lights on! Literally."),
        ("Paid and Done ✅", "One less thing to worry about."),
        ("Invest in Yourself 🏠", "Covering the essentials."),
        ("Peace of Mind 🧘", "Bills paid = stress reduced.")
    ]
    
    static let shoppingMessages = [
        ("Treat Yourself! 🛍️", "A little retail therapy strictly for medicinal purposes."),
        ("New Gear! 🎒", "Exciting! Hope it sparks joy."),
        ("Add to Cart 🛒", "You bought it, you own it!"),
        ("Look at You! 😎", "Style upgrade incoming."),
        ("Cha-Ching! 💸", "Tracking it makes it guilt-free, right?")
    ]
    
    static let entertainmentMessages = [
        ("Have a Blast! 🎬", "Memories are priceless."),
        ("Fun Times 🎉", "Life isn't just about work!"),
        ("Enjoy the Show 🍿", "Hope it's a 10/10 experience."),
        ("Game On 🎮", "Leveling up your downtime."),
        ("Relax & Recharge 🔋", "Money well spent on happiness.")
    ]
    
    static let otherMessages = [
        ("Recorded! 📝", "Tracking every penny counts."),
        ("Got it! 👌", "Financial awareness +1."),
        ("Sorted. 🗂️", "Your budget thanks you."),
        ("Done & Dusted ✨", "Transaction saved successfully."),
        ("Keep it Up! 🚀", "Consistency is key to financial freedom.")
    ]
    
    // MARK: - Budget Alerts
    static let overBudgetMessages = [
        ("Whoops! 🚨", "You've gone over your budget for this category."),
        ("Budget Breached 📉", "Might want to slow down on this category!"),
        ("Limit Exceeded ⚠️", "You've passed your set limit."),
        ("Ouch! 💸", "That alert is your wallet crying."),
        ("Check the Plan 📋", "You're officially over budget here.")
    ]
    
    static let nearBudgetMessages = [
        ("Heads Up! ⚠️", "You're getting close to your budget limit."),
        ("Almost There 🛑", "80% of your budget is used."),
        ("Watch Out 👀", "Approaching the danger zone for this category."),
        ("Budget Low 📉", "Only a little left in the tank for this."),
        ("Steady Now 🐢", "You're nearing the cap.")
    ]
    
    // MARK: - Message Selection
    static func getMessage(for category: TransactionCategory) -> (title: String, body: String) {
        let messages: [(String, String)]
        
        switch category {
        case .food:
            messages = foodMessages
        case .transport:
            messages = transportMessages
        case .bills:
            messages = billsMessages
        case .shopping:
            messages = shoppingMessages
        case .entertainment:
            messages = entertainmentMessages
        case .other:
            messages = otherMessages
        }
        
        return messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Trigger Notification
    static func triggerNotification(for transaction: Transaction) {
        let message = getMessage(for: transaction.category)
        scheduleNotification(title: message.title, body: message.body)
    }
    
    static func triggerBudgetAlert(status: BudgetStatus, category: TransactionCategory) {
        let messages = status == .over ? overBudgetMessages : nearBudgetMessages
        let message = messages.randomElement() ?? messages[0]
        
        scheduleNotification(
            title: message.0,
            body: "\(message.1) (\(category.rawValue.capitalized))",
            delay: 2 // Slightly after the dopamine hit
        )
    }
    
    private static func scheduleNotification(title: String, body: String, delay: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "finance-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}

enum BudgetStatus {
    case near // > 80%
    case over // > 100%
}
