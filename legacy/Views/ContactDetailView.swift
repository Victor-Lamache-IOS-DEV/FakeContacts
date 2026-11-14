import SwiftUI
import UIKit

struct ContactDetailView: View {
    let contact: Contact

    @EnvironmentObject private var trickEngine: TrickEngine
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var presentation: ContactPresentation?
    @State private var sequenceTask: Task<Void, Never>?
    @State private var hasAdvanced = false
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    @State private var showingShareError = false

    var body: some View {
        ScrollView {
            if let presentation {
                VStack(spacing: 0) {
                    posterHeader(presentation)
                    detailContent(presentation)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 320)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if presentation == nil {
                preparePresentation()
            } else if presentation?.appliedTrick == true,
                      !hasAdvanced,
                      sequenceTask == nil {
                scheduleAdvance()
            }
        }
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if presentation?.appliedTrick == true,
                   !hasAdvanced,
                   sequenceTask == nil {
                    scheduleAdvance()
                }
            } else {
                sequenceTask?.cancel()
                sequenceTask = nil
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareURL {
                ActivityView(items: [shareURL])
            }
        }
        .alert("Unable to Share Contact", isPresented: $showingShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The contact could not be prepared for sharing.")
        }
    }

    // MARK: - Poster

    private func posterHeader(_ presentation: ContactPresentation) -> some View {
        VStack(spacing: 14) {
            AvatarView(contact: contact, size: 132, posterStyle: true)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

            VStack(spacing: 6) {
                Text(contact.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                if !contact.organizationName.isEmpty,
                   contact.organizationName != contact.name {
                    Text(contact.organizationName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }

            actionButtons(presentation)
                .padding(.top, 4)
        }
        .padding(.top, 30)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            posterBackground
        }
        .clipped()
    }

    @ViewBuilder
    private var posterBackground: some View {
        if let data = contact.imageData, let image = UIImage(data: data) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 24)
                    .overlay(Color.black.opacity(0.35))

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.43, blue: 0.51),
                    Color(red: 0.28, green: 0.28, blue: 0.38),
                    Color(red: 0.09, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func actionButtons(_ presentation: ContactPresentation) -> some View {
        let phone = presentation.phoneNumbers.first?.value
        let email = presentation.emailAddresses.first?.value
        let faceTimeTarget = phone ?? email

        if phone != nil || email != nil {
            HStack(spacing: 24) {
                PosterActionButton(
                    icon: "message.fill",
                    title: NSLocalizedString("Message", comment: "Contact action"),
                    isEnabled: phone != nil
                ) {
                    open(ContactAction.messageURL(phone ?? ""))
                }

                PosterActionButton(
                    icon: "phone.fill",
                    title: NSLocalizedString("Call", comment: "Contact action"),
                    isEnabled: phone != nil
                ) {
                    open(ContactAction.phoneURL(phone ?? ""))
                }

                PosterActionButton(
                    icon: "video.fill",
                    title: NSLocalizedString("FaceTime", comment: "Contact action"),
                    isEnabled: faceTimeTarget != nil
                ) {
                    open(ContactAction.faceTimeURL(faceTimeTarget ?? ""))
                }

                PosterActionButton(
                    icon: "envelope.fill",
                    title: NSLocalizedString("Mail", comment: "Contact action"),
                    isEnabled: email != nil
                ) {
                    open(ContactAction.mailURL(email ?? ""))
                }
            }
        }
    }

    // MARK: - Details

    @ViewBuilder
    private func detailContent(_ presentation: ContactPresentation) -> some View {
        VStack(spacing: 18) {
            if !presentation.phoneNumbers.isEmpty {
                ContactDetailCard {
                    ForEach(Array(presentation.phoneNumbers.enumerated()), id: \.element.id) { index, field in
                        Button {
                            open(ContactAction.phoneURL(field.value))
                        } label: {
                            ContactInfoRow(
                                icon: "phone.fill",
                                label: ContactLabel.localized(field.label),
                                value: formatPhone(field.value),
                                actionable: true
                            )
                        }
                        .buttonStyle(.plain)

                        if index < presentation.phoneNumbers.count - 1 {
                            Divider().padding(.leading, 18)
                        }
                    }
                }
            }

            if !presentation.emailAddresses.isEmpty {
                ContactDetailCard {
                    ForEach(Array(presentation.emailAddresses.enumerated()), id: \.element.id) { index, field in
                        Button {
                            open(ContactAction.mailURL(field.value))
                        } label: {
                            ContactInfoRow(
                                icon: "envelope.fill",
                                label: ContactLabel.localized(field.label),
                                value: field.value,
                                actionable: true
                            )
                        }
                        .buttonStyle(.plain)

                        if index < presentation.emailAddresses.count - 1 {
                            Divider().padding(.leading, 18)
                        }
                    }
                }
            }

            if let birthdayText = presentation.birthdayText {
                ContactDetailCard {
                    ContactInfoRow(
                        icon: "gift.fill",
                        label: NSLocalizedString("birthday", comment: "Birthday field"),
                        value: birthdayText,
                        actionable: false
                    )
                }
            }

            if !presentation.note.isEmpty {
                ContactDetailCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(presentation.note)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }

            ContactDetailCard {
                Button {
                    shareContact(presentation)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.medium))
                            .frame(width: 24)
                        Text("Share Contact")
                            .font(.body)
                        Spacer()
                    }
                    .foregroundStyle(.tint)
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Presentation

    private func preparePresentation() {
        guard presentation == nil else { return }

        var phones = contact.phoneNumbers
        var emails = contact.emailAddresses
        var birthday = contact.birthday
        var birthdayText = formatBirthday(contact.birthday)
        var note = contact.note
        var appliedTrick = false

        if !contact.isForced, let profile = trickEngine.activeProfile {
            appliedTrick = true

            let fakePhone = profile.fakePhone.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakePhone.isEmpty {
                phones = [ContactField(label: "mobile", value: profile.fakePhone)]
            }

            let fakeEmail = profile.fakeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakeEmail.isEmpty {
                emails = [ContactField(label: "email", value: fakeEmail)]
            }

            let fakeBirthday = profile.fakeBirthday.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakeBirthday.isEmpty {
                birthday = birthdayComponents(from: profile.fakeBirthday)
                birthdayText = formatBirthday(birthday) ?? profile.fakeBirthday
            }

            let fakeNote = profile.fakeNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fakeNote.isEmpty {
                note = profile.fakeNote
            }
        }

        let resolved = ContactPresentation(
            phoneNumbers: phones,
            emailAddresses: emails,
            birthday: birthday,
            birthdayText: birthdayText,
            note: note,
            appliedTrick: appliedTrick
        )

        presentation = resolved
        trickEngine.markLastOpened(
            name: contact.name,
            phone: resolved.phoneNumbers.first?.value ?? ""
        )

        if appliedTrick {
            scheduleAdvance()
        }
    }

    private func scheduleAdvance() {
        guard presentation?.appliedTrick == true, !hasAdvanced else { return }

        sequenceTask?.cancel()

        let seconds = max(0, trickEngine.minSeconds)
        guard seconds > 0 else {
            hasAdvanced = true
            trickEngine.advance()
            return
        }

        sequenceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled, !hasAdvanced else { return }
            hasAdvanced = true
            trickEngine.advance()
            sequenceTask = nil
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }

    private func shareContact(_ presentation: ContactPresentation) {
        do {
            shareURL = try VCardBuilder.temporaryFileURL(
                for: contact,
                presentation: presentation
            )
            showingShareSheet = true
        } catch {
            showingShareError = true
        }
    }
}

// MARK: - Poster action

private struct PosterActionButton: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(Color.white.opacity(isEnabled ? 0.20 : 0.08))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Card

private struct ContactDetailCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Info row

private struct ContactInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let actionable: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(actionable ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(actionable ? Color.accentColor : Color.primary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
