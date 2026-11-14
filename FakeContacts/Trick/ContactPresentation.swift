import Foundation

struct ContactPresentation {
    let phoneNumbers: [ContactField]
    let emailAddresses: [ContactField]
    let birthday: DateComponents?
    let birthdayText: String?
    let appliedTrick: Bool

    static func resolve(contact: Contact, profile: TrickProfile?) -> ContactPresentation {
        var phones = contact.phoneNumbers
        var emails = contact.emailAddresses
        var birthday = contact.birthday
        var birthdayText = formatBirthday(contact.birthday)
        var appliedTrick = false

        if !contact.isForced, let profile {
            appliedTrick = true

            let fakePhone = profile.fakePhone.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakePhone.isEmpty {
                phones = [ContactField(label: "mobile", value: fakePhone)]
            }

            let fakeEmail = profile.fakeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakeEmail.isEmpty {
                emails = [ContactField(label: "email", value: fakeEmail)]
            }

            let fakeBirthday = profile.fakeBirthday.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakeBirthday.isEmpty {
                birthday = birthdayComponents(from: fakeBirthday)
                birthdayText = formatBirthday(birthday) ?? fakeBirthday
            }
        }

        return ContactPresentation(
            phoneNumbers: phones,
            emailAddresses: emails,
            birthday: birthday,
            birthdayText: birthdayText,
            appliedTrick: appliedTrick
        )
    }
}
