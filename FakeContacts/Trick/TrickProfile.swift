import Foundation

struct TrickProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var fakePhone: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}
