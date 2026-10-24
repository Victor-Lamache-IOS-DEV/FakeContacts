import SwiftUI

// MARK: - Input Helpers
func formatBirthdayInput(_ input: String) -> String {
    let digits = input.filter { $0.isNumber }
    let limited = String(digits.prefix(8))
    var result = ""
    for (i, char) in limited.enumerated() {
        if i == 2 || i == 4 { result += " / " }
        result.append(char)
    }
    return result
}

func birthdayBinding(_ text: Binding<String>) -> Binding<String> {
    Binding(
        get: { text.wrappedValue },
        set: { text.wrappedValue = formatBirthdayInput($0) }
    )
}

func phoneBinding(_ text: Binding<String>, maxDigits: Int) -> Binding<String> {
    Binding(
        get: { text.wrappedValue },
        set: { newValue in
            let digits = newValue.filter { $0.isNumber }
            let limited = String(digits.prefix(maxDigits))
            var formatted = ""
            for (i, char) in limited.enumerated() {
                if i > 0 && i % 2 == 0 { formatted += " " }
                formatted.append(char)
            }
            text.wrappedValue = formatted
        }
    )
}


// MARK: - Config View
struct ConfigView: View {
    @EnvironmentObject var trickEngine: TrickEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // ── TRICK 1: Timer ───────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum time on page")
                            Spacer()
                            Text(trickEngine.minSeconds == 0 ? "Instant" : "\(Int(trickEngine.minSeconds))s")
                                .foregroundColor(trickEngine.minSeconds == 0 ? .secondary : .primary)
                                .monospacedDigit()
                        }
                        Slider(value: $trickEngine.minSeconds, in: 0...30, step: 1)
                            .tint(.blue)
                            .onChange(of: trickEngine.minSeconds) { _ in trickEngine.save() }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Trick 1 — Number Force")
                } footer: {
                    Text(trickEngine.minSeconds == 0
                         ? "Sequence advances instantly as soon as the contact is opened."
                         : "Contact must be open this long before the sequence advances.")
                }

                // ── TRICK 1: Profiles ────────────────────────────────
                Section {
                    ForEach($trickEngine.profiles) { $profile in
                        ProfileRowView(profile: $profile)
                    }
                    .onDelete { trickEngine.profiles.remove(atOffsets: $0); trickEngine.save() }
                    .onMove   { trickEngine.profiles.move(fromOffsets: $0, toOffset: $1); trickEngine.save() }

                    Button(action: {
                        trickEngine.profiles.append(TrickProfile())
                        trickEngine.save()
                    }) {
                        Label("Add Profile", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Profiles — in order")
                } footer: {
                    Text("Each profile fires once per contact opened. Swipe to delete, drag to reorder.")
                }

                // ── TRICK 1: Status ──────────────────────────────────
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(trickEngine.isArmed
                             ? "Armed (\(trickEngine.currentIndex + 1)/\(trickEngine.profiles.count))"
                             : "Disarmed")
                            .foregroundColor(trickEngine.isArmed ? .red : .secondary)
                    }
                    if trickEngine.isArmed {
                        Button("Reset Sequence", role: .destructive) {
                            trickEngine.currentIndex = 0
                            trickEngine.save()
                        }
                    }
                }

                // ── TRICK 2: Settings ────────────────────────────────
                Section {
                    Toggle("Armed", isOn: $trickEngine.searchTrickArmed)
                        .onChange(of: trickEngine.searchTrickArmed) { _ in trickEngine.save() }

                    Stepper(
                        "Trigger after \(trickEngine.searchTriggerDigits) digit\(trickEngine.searchTriggerDigits > 1 ? "s" : "")",
                        value: $trickEngine.searchTriggerDigits, in: 1...8
                    )
                    .onChange(of: trickEngine.searchTriggerDigits) { _ in trickEngine.save() }
                } header: {
                    Text("Trick 2 — Name Force")
                } footer: {
                    Text("When armed, fake contacts appear mixed in during search. At the trigger digit count, only fake contacts are shown.")
                }

                // ── TRICK 2: Forced Contacts ─────────────────────────
                Section {
                    ForEach($trickEngine.forcedContacts) { $fc in
                        ForcedContactRowView(fc: $fc)
                    }
                    .onDelete { trickEngine.forcedContacts.remove(atOffsets: $0); trickEngine.save() }
                    .onMove   { trickEngine.forcedContacts.move(fromOffsets: $0, toOffset: $1); trickEngine.save() }

                    Button(action: {
                        trickEngine.forcedContacts.append(ForcedContact())
                        trickEngine.save()
                    }) {
                        Label("Add Forced Contact", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Forced Contacts")
                } footer: {
                    Text("Suffix length auto-limited to \(max(1, 10 - trickEngine.searchTriggerDigits)) digits based on trigger setting.")
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Trick 1 Profile Row
struct ProfileRowView: View {
    @Binding var profile: TrickProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Fake phone (10 digits)", text: phoneBinding($profile.fakePhone, maxDigits: 10))
                .keyboardType(.phonePad)
                .font(.system(size: 15))
            Divider()
            TextField("Fake email", text: $profile.fakeEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .font(.system(size: 15))
            Divider()
            TextField("Birthday  DD / MM / YYYY", text: birthdayBinding($profile.fakeBirthday))
                .keyboardType(.numberPad)
                .font(.system(size: 15))
            Divider()
            TextField("Fake note", text: $profile.fakeNote)
                .font(.system(size: 15))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Trick 2 Forced Contact Row
struct ForcedContactRowView: View {
    @Binding var fc: ForcedContact
    @EnvironmentObject var trickEngine: TrickEngine

    var maxSuffix: Int { max(1, 10 - trickEngine.searchTriggerDigits) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name (e.g. Sarah Martin)", text: $fc.fakeName)
                .font(.system(size: 15))
            Divider()
            TextField("Phone suffix (\(maxSuffix) digits)", text: phoneBinding($fc.phoneSuffix, maxDigits: maxSuffix))
                .keyboardType(.numberPad)
                .font(.system(size: 15))
            Divider()
            TextField("Fake email", text: $fc.fakeEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .font(.system(size: 15))
            Divider()
            TextField("Birthday  DD / MM / YYYY", text: birthdayBinding($fc.fakeBirthday))
                .keyboardType(.numberPad)
                .font(.system(size: 15))
            Divider()
            TextField("Note (optional)", text: $fc.fakeNote)
                .font(.system(size: 15))
        }
        .padding(.vertical, 6)
    }
}
