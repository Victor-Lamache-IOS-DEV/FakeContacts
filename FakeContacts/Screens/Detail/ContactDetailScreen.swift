import SwiftUI
import UIKit

struct ContactDetailScreen: View {
    let contact: Contact

    @EnvironmentObject private var trickEngine: TrickEngine
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var presentation: ContactPresentation?
    @State private var fullImage: UIImage?
    @State private var sequenceTask: Task<Void, Never>?
    @State private var hasAdvanced = false
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    @State private var showingShareError = false

    private var image: UIImage? {
        fullImage ?? contact.thumbnail
    }

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(image: image, seed: contact.id)

            ScrollView {
                if let presentation {
                    VStack(spacing: 0) {
                        header(presentation)
                        details(presentation)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {}
            }
        }
        .task(id: contact.id) {
            guard !contact.isForced else { return }
            let identifier = contact.id
            let data = await Task.detached(priority: .userInitiated) {
                ContactStore.fullImageData(for: identifier)
            }.value
            if let data, let loaded = UIImage(data: data) {
                fullImage = loaded
            }
        }
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

    // MARK: - Header

    private func header(_ presentation: ContactPresentation) -> some View {
        VStack(spacing: 18) {
            ContactAvatar(
                image: image,
                initials: contact.initials,
                size: image == nil ? 200 : 240,
                style: .glass
            )

            Text(contact.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            actionRow(presentation)
                .padding(.horizontal, 16)
                .padding(.top, 6)
        }
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
    }

    private func actionRow(_ presentation: ContactPresentation) -> some View {
        let phone = presentation.phoneNumbers.first?.value
        let email = presentation.emailAddresses.first?.value
        let showsTitles = image != nil

        return HStack(spacing: showsTitles ? 10 : 22) {
            DetailActionButton(
                icon: "message.fill",
                title: "message",
                showsTitle: showsTitles,
                isEnabled: phone != nil
            ) {
                open(ContactAction.messageURL(phone ?? ""))
            }

            DetailActionButton(
                icon: "phone.fill",
                title: "call",
                showsTitle: showsTitles,
                isEnabled: phone != nil
            ) {
                open(ContactAction.phoneURL(phone ?? ""))
            }

            DetailActionButton(
                icon: "video.fill",
                title: "video",
                showsTitle: showsTitles,
                isEnabled: phone != nil || email != nil
            ) {
                open(ContactAction.faceTimeURL(phone ?? email ?? ""))
            }

            DetailActionButton(
                icon: "envelope.fill",
                title: "mail",
                showsTitle: showsTitles,
                isEnabled: email != nil
            ) {
                open(ContactAction.mailURL(email ?? ""))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cards

    @ViewBuilder
    private func details(_ presentation: ContactPresentation) -> some View {
        InfoCard {
            posterRow
        }

        // Phone card: shown only when the contact has phones.
        if !presentation.phoneNumbers.isEmpty {
            InfoCard {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.phoneNumbers.enumerated()), id: \.element.id) { index, field in
                        phoneRow(field)
                        if index < presentation.phoneNumbers.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    Divider().padding(.leading, 16)
                    notesBody
                }
            }
        }

        // Email card: shown only when the contact has emails.
        if !presentation.emailAddresses.isEmpty {
            InfoCard {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.emailAddresses.enumerated()), id: \.element.id) { index, field in
                        emailRow(field)
                        if index < presentation.emailAddresses.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }

        // Birthday card: shown only when a birthday is present.
        if let birthdayText = presentation.birthdayText {
            InfoCard {
                InfoRow(
                    label: NSLocalizedString("birthday", comment: "Birthday field"),
                    value: birthdayText
                )
            }
        }

        // Standalone notes card when there is no phone to host it.
        if presentation.phoneNumbers.isEmpty {
            InfoCard {
                notesBody
            }
        }

        InfoCard {
            VStack(spacing: 0) {
                if !presentation.phoneNumbers.isEmpty {
                    sendMessageRow(presentation)
                    Divider().padding(.leading, 16)
                }
                shareRow(presentation)
            }
        }
    }

    // MARK: - Row builders

    private var posterRow: some View {
        HStack(spacing: 14) {
            ContactAvatar(image: image, initials: contact.initials, size: 44)

            Text("Contact Photo & Poster")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
        }
        .padding(12)
    }

    private func phoneRow(_ field: ContactField) -> some View {
        Button {
            open(ContactAction.phoneURL(field.value))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ContactLabel.localized(field.label))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(formatPhone(field.value))
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.link)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emailRow(_ field: ContactField) -> some View {
        Button {
            open(ContactAction.mailURL(field.value))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(ContactLabel.localized(field.label))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(field.value)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.link)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var notesBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
    }

    private func sendMessageRow(_ presentation: ContactPresentation) -> some View {
        let phone = presentation.phoneNumbers.first?.value

        return Button {
            open(ContactAction.messageURL(phone ?? ""))
        } label: {
            actionLabel("Send Message")
        }
        .buttonStyle(.plain)
    }

    private func shareRow(_ presentation: ContactPresentation) -> some View {
        Button {
            shareContact(presentation)
        } label: {
            actionLabel("Share Contact")
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
    }

    // MARK: - Trick and last opened

    private func preparePresentation() {
        guard presentation == nil else { return }

        let resolved = ContactPresentation.resolve(
            contact: contact,
            profile: trickEngine.activeProfile
        )

        presentation = resolved
        trickEngine.markLastOpened(
            name: contact.name,
            phone: resolved.phoneNumbers.first?.value ?? ""
        )

        if resolved.appliedTrick {
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
