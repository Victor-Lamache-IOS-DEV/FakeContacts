import Foundation

struct ForcedContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var fakeName: String = ""
    var phoneSuffix: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}
