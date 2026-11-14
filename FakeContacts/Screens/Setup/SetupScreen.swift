import SwiftUI
import UIKit
import PhotosUI

struct SetupScreen: View {
    @EnvironmentObject private var trickEngine: TrickEngine
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                myCardSection
                sequenceSection
                profilesSection
                searchSection
                forcedContactsSection
                peekSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - My Card

    private var myCardSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                myCardPhotoPicker

                SetupTextField(
                    title: "Name",
                    text: $trickEngine.myCard.name
                )

                Divider()

                SetupTextField(
                    title: "Phone",
                    text: phoneBinding($trickEngine.myCard.phone, maxDigits: 10),
                    keyboardType: .phonePad
                )

                Divider()

                SetupTextField(
                    title: "Email",
                    text: $trickEngine.myCard.email,
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    disablesAutocorrection: true
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("My Card")
        } footer: {
            Text("Appears at the top of the contacts list as your own card. Empty fields are hidden.")
        }
    }

    // MARK: - My Card photo

    private var myCardPhotoPicker: some View {
        HStack(spacing: 12) {
            ContactAvatar(
                image: trickEngine.myCard.photo.flatMap { UIImage(data: $0) },
                initials: trickEngine.myCard.initials,
                size: 56
            )

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(trickEngine.myCard.photo == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
            }
            .font(.body)
            .foregroundStyle(Theme.link)

            if trickEngine.myCard.photo != nil {
                Button {
                    trickEngine.myCard.photo = nil
                } label: {
                    Text("Remove")
                        .font(.body)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .task(id: photoItem) {
            guard let photoItem,
                  let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
            if let image = UIImage(data: data) {
                let resized = image.preparingThumbnail(of: CGSize(width: 512, height: 512))
                trickEngine.myCard.photo = resized.jpegData(compressionQuality: 0.8)
            }
        }
    }

    // MARK: - Trick 1

    private var sequenceSection: some View {
        Section {
            Toggle("Armed", isOn: armedBinding)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum time on page")
                    Spacer()
                    if trickEngine.minSeconds == 0 {
                        Text("Instant")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(Int(trickEngine.minSeconds))s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Slider(value: $trickEngine.minSeconds, in: 0...30, step: 1)
            }
            .padding(.vertical, 2)

            HStack {
                Text("Status")
                Spacer()
                Text(trickEngine.sequenceStatus)
                    .foregroundStyle(trickEngine.isArmed ? Color.accentColor : Color.secondary)
            }

            Button("Reset Sequence", role: .destructive) {
                trickEngine.resetSequence()
            }
            .disabled(!trickEngine.isArmed)
        } header: {
            Text("Trick 1 — Contact Sequence")
        } footer: {
            if trickEngine.minSeconds == 0 {
                Text("When armed, opening a contact applies the current profile and advances the sequence immediately.")
            } else {
                Text("When armed, opening a contact applies the current profile. After the contact stays open for the minimum time, the sequence advances.")
            }
        }
    }

    private var profilesSection: some View {
        Section {
            ForEach($trickEngine.profiles) { $profile in
                ProfileRowView(profile: $profile)
            }
            .onDelete { offsets in
                trickEngine.profiles.remove(atOffsets: offsets)
            }
            .onMove { offsets, destination in
                trickEngine.profiles.move(fromOffsets: offsets, toOffset: destination)
            }

            Button {
                trickEngine.profiles.append(TrickProfile())
            } label: {
                Label("Add Profile", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Profiles — in order")
        } footer: {
            Text("Empty fields keep the real contact's value. Swipe to delete or use Edit to reorder.")
        }
    }

    // MARK: - Trick 2

    private var searchSection: some View {
        Section {
            Toggle("Armed", isOn: $trickEngine.searchTrickArmed)

            Stepper(value: $trickEngine.searchTriggerDigits, in: 1...8) {
                Text(
                    String(
                        format: NSLocalizedString(
                            "Trigger after %d digits",
                            comment: "Search trick trigger length"
                        ),
                        trickEngine.searchTriggerDigits
                    )
                )
            }
        } header: {
            Text("Trick 2 — Search Contacts")
        } footer: {
            Text("During a phone-number search, forced contacts appear with matching numbers. At the trigger length, real results are replaced by forced contacts.")
        }
    }

    private var forcedContactsSection: some View {
        Section {
            ForEach($trickEngine.forcedContacts) { $forced in
                ForcedContactRowView(forcedContact: $forced)
            }
            .onDelete { offsets in
                trickEngine.forcedContacts.remove(atOffsets: offsets)
            }
            .onMove { offsets, destination in
                trickEngine.forcedContacts.move(fromOffsets: offsets, toOffset: destination)
            }

            Button {
                trickEngine.forcedContacts.append(ForcedContact())
            } label: {
                Label("Add Forced Contact", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Forced Contacts")
        } footer: {
            Text(
                String(
                    format: NSLocalizedString(
                        "The phone suffix is limited to %d digits so the full number fits ten digits.",
                        comment: "Forced contact suffix footer"
                    ),
                    maxSuffixDigits
                )
            )
        }
    }

    // MARK: - Peek

    private var peekSection: some View {
        Section {
            Toggle("Enable Volume-Button Peek", isOn: $trickEngine.peekEnabled)
            Toggle("Play Sound", isOn: $trickEngine.peekSoundEnabled)
                .disabled(!trickEngine.peekEnabled)
            Toggle("Haptic Feedback", isOn: $trickEngine.peekHapticEnabled)
                .disabled(!trickEngine.peekEnabled)
        } header: {
            Text("Peek")
        } footer: {
            Text("Press either volume button on the contacts list to reveal the last opened contact in the search field. The app does not reset your system volume.")
        }
    }

    // MARK: - Helpers

    private var armedBinding: Binding<Bool> {
        Binding(
            get: { trickEngine.isArmed },
            set: { isOn in
                if isOn {
                    trickEngine.arm()
                } else {
                    trickEngine.disarm()
                }
            }
        )
    }

    private var maxSuffixDigits: Int {
        max(1, 10 - trickEngine.searchTriggerDigits)
    }
}

// MARK: - Profile row

private struct ProfileRowView: View {
    @Binding var profile: TrickProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupTextField(
                title: "Fake phone",
                text: phoneBinding($profile.fakePhone, maxDigits: 10),
                keyboardType: .phonePad
            )

            Divider()

            SetupTextField(
                title: "Fake email",
                text: $profile.fakeEmail,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                disablesAutocorrection: true
            )

            Divider()

            SetupTextField(
                title: "Birthday (DD / MM / YYYY)",
                text: birthdayBinding($profile.fakeBirthday),
                keyboardType: .numberPad
            )

            Divider()

            SetupTextField(
                title: "Fake note",
                text: $profile.fakeNote
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Forced contact row

private struct ForcedContactRowView: View {
    @Binding var forcedContact: ForcedContact
    @EnvironmentObject private var trickEngine: TrickEngine

    private var maxSuffixDigits: Int {
        max(1, 10 - trickEngine.searchTriggerDigits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupTextField(
                title: "Name",
                text: $forcedContact.fakeName
            )

            Divider()

            SetupTextField(
                title: "Phone suffix",
                text: phoneBinding($forcedContact.phoneSuffix, maxDigits: maxSuffixDigits),
                keyboardType: .numberPad
            )

            Divider()

            SetupTextField(
                title: "Fake email",
                text: $forcedContact.fakeEmail,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                disablesAutocorrection: true
            )

            Divider()

            SetupTextField(
                title: "Birthday (DD / MM / YYYY)",
                text: birthdayBinding($forcedContact.fakeBirthday),
                keyboardType: .numberPad
            )

            Divider()

            SetupTextField(
                title: "Note",
                text: $forcedContact.fakeNote
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Field

private struct SetupTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disablesAutocorrection: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("", text: $text)
                .font(.body)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disablesAutocorrection)
        }
    }
}

// MARK: - Input formatting

private func formatBirthdayInput(_ input: String) -> String {
    let digits = String(input.filter(\.isNumber).prefix(8))
    var result = ""

    for (index, character) in digits.enumerated() {
        if index == 2 || index == 4 {
            result += " / "
        }
        result.append(character)
    }

    return result
}

private func birthdayBinding(_ binding: Binding<String>) -> Binding<String> {
    Binding(
        get: { binding.wrappedValue },
        set: { binding.wrappedValue = formatBirthdayInput($0) }
    )
}

private func phoneBinding(_ binding: Binding<String>, maxDigits: Int) -> Binding<String> {
    Binding(
        get: { binding.wrappedValue },
        set: { newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(maxDigits))
            var result = ""

            for (index, character) in digits.enumerated() {
                if index > 0 && index.isMultiple(of: 2) {
                    result += " "
                }
                result.append(character)
            }

            binding.wrappedValue = result
        }
    )
}
