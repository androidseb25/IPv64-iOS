import Foundation
import Testing
@testable import IPv64_net

struct AccountTests {
    private let a = Account(username: "A", apiKey: "key-a")
    private let b = Account(username: "B", apiKey: "key-b")
    private let c = Account(username: "C", apiKey: "key-c")

    @Test func removingInactiveEntryKeepsActiveKey() {
        let d = removalDecision([a, b, c], activeKey: "key-a", id: b.id)
        #expect(d.remaining == [a, c])
        #expect(d.activeKey == "key-a")
        #expect(d.result == .removed)
    }

    @Test func removingActiveEntrySwitchesToFirstRemaining() {
        let d = removalDecision([a, b, c], activeKey: "key-b", id: b.id)
        #expect(d.remaining == [a, c])
        #expect(d.activeKey == "key-a")
        #expect(d.result == .switchedTo(a))
    }

    @Test func removingLastEntryLogsOut() {
        let d = removalDecision([a], activeKey: "key-a", id: a.id)
        #expect(d.remaining.isEmpty)
        #expect(d.activeKey == "")
        #expect(d.result == .loggedOut)
    }

    @Test func sameApiKeyInAnotherEntryDoesNotSwitch() {
        let a2 = Account(username: "A again", apiKey: "key-a")
        let d = removalDecision([b, a, a2], activeKey: "key-a", id: a.id)
        #expect(d.remaining == [b, a2])
        #expect(d.activeKey == "key-a")
        #expect(d.result == .removed)
    }

    @Test func unknownIdIsNotFound() {
        let d = removalDecision([a, b], activeKey: "key-a", id: UUID())
        #expect(d.remaining == [a, b])
        #expect(d.activeKey == "key-a")
        #expect(d.result == .notFound)
    }

    @Test func loggedOutRemovalKeepsEmptyKey() {
        let d = removalDecision([a, b], activeKey: "", id: a.id)
        #expect(d.activeKey == "")
        #expect(d.result == .removed)
    }

    @Test func duplicateIdsAreRepairedToUnique() {
        var dup = b
        dup.id = a.id
        let (list, repaired) = withUniqueIds([a, dup, c])
        #expect(repaired)
        #expect(Set(list.map(\.id)).count == 3)
        #expect(list[0].id == a.id)
        #expect(list.map(\.username) == ["A", "B", "C"])
    }

    @Test func missingIdIsRepaired() {
        var x = a
        x.id = Account.missingID
        let (list, repaired) = withUniqueIds([x])
        #expect(repaired)
        #expect(list[0].id != Account.missingID)
    }

    @Test func uniqueIdsAreUnchanged() {
        let (list, repaired) = withUniqueIds([a, b])
        #expect(!repaired)
        #expect(list == [a, b])
    }

    @Test func defaultUsernameIsDeduplicated() {
        func account(_ name: String) -> Account { Account(username: name, apiKey: name) }
        #expect(nextDefaultUsername([]) == "Default User")
        #expect(nextDefaultUsername([account("Default User")]) == "Default User 1")
        #expect(nextDefaultUsername([account("Default User"), account("Default User 1")]) == "Default User 2")
        #expect(nextDefaultUsername([account("Default User 1")]) == "Default User")
        #expect(nextDefaultUsername([a, b]) == "Default User")
    }

    @Test func removalMessages() {
        #expect(AccountRemovalText.message(.removed, name: "A") == "\"A\" removed from this app.")
        #expect(AccountRemovalText.message(.switchedTo(b), name: "A") == "\"A\" removed. Switched to account \"B\".")
        #expect(AccountRemovalText.message(.loggedOut, name: "A") == "\"A\" removed. You have been logged out.")
        #expect(AccountRemovalText.message(.notFound, name: "A") == nil)
    }

    @Test func confirmTextMentionsSwitchOrLogout() {
        let base = AccountRemovalText.confirm(a, accounts: [a, b], activeKey: "key-b")
        #expect(!base.contains("active account") && !base.contains("last account"))
        #expect(AccountRemovalText.confirm(a, accounts: [a, b], activeKey: "key-a").contains("switch to \"B\""))
        #expect(AccountRemovalText.confirm(a, accounts: [a], activeKey: "key-a").contains("logged out"))
    }

    @Test func accountJSONKeepsLegacyKeysAndReadsId() throws {
        let data = try JSONEncoder().encode(a)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object["uuid"] == a.id.uuidString)
        #expect(object["Username"] == "A" && object["ApiKey"] == "key-a")
        let viaId = try decode(Account.self, "{\"id\":\"\(a.id.uuidString)\",\"Username\":\"A\",\"ApiKey\":\"key-a\"}")
        #expect(viaId.id == a.id)
        #expect(try decode(Account.self, "{\"Username\":\"x\",\"ApiKey\":\"k\"}").id == Account.missingID)
    }
}
