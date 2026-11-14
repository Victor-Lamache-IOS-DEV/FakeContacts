import SwiftUI
import UIKit

struct ContactsListView: View {
    @EnvironmentObject private var trickEngine: TrickEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @StateObject private var store = ContactStore()
    @StateObject private var volumeMonitor = VolumeButtonMonitor()

    @State private var searchText = ""
    @State private var peekName = ""
    @State private var peekClearWork: DispatchWorkItem?
    @State private var showingLists = false
    @State private var showingSetup = false
    @State private var listsTapCount = 0
    @State private var listsOpenWork: DispatchWorkItem?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Contacts")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        listsButton
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        hiddenTrickButton
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsSearchBar {
                        searchBar
                    }
                }
                .task {
                    await store.prepare()
                }
                .onAppear {
                    updatePeekMonitoring()
                }
                .onDisappear {
                    volumeMonitor.stop()
                    cancelPeek()
                    searchFocused = false
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshForForeground()
                        updatePeekMonitoring()
                    } else {
                        volumeMonitor.stop()
                    }
                }
                .onChange(of: trickEngine.peekEnabled) { _, _ in
                    updatePeekMonitoring()
                }
                .onChange(of: store.accessState) { _, _ in
                    updatePeekMonitoring()
                }
                .onChange(of: store.selectedGroupID) { _, _ in
                    searchText = ""
                    searchFocused = false
                    cancelPeek()
                }
                .onChange(of: searchText) { _, newValue in
                    if !newValue.isEmpty {
                        cancelPeek()
                    }
                }
                .onChange(of: showingLists) { _, _ in
                    updatePeekMonitoring()
                }
                .onChange(of: showingSetup) { _, _ in
                    updatePeekMonitoring()
                }
                .sheet(isPresented: $showingLists, onDismiss: {
                    updatePeekMonitoring()
                }) {
                    ListsView(store: store)
                        .environmentObject(trickEngine)
                }
                .sheet(isPresented: $showingSetup, onDismiss: {
                    updatePeekMonitoring()
                }) {
                    SetupView()
                        .environmentObject(trickEngine)
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.accessState == .notDetermined || store.accessState == .requesting {
            ProgressView("Loading Contacts")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
        } else if store.accessState == .denied || store.accessState == .restricted {
            accessDeniedView
        } else if let errorMessage = store.errorMessage, store.contacts.isEmpty {
            ContentUnavailableView {
                Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    store.retry()
                }
            }
        } else {
            contactsContent
        }
    }

    private var contactsContent: some View {
        VStack(spacing: 0) {
            if store.accessState == .limited {
                limitedAccessBanner
            }

            List {
                ForEach(contactSections) { section in
                    Section {
                        ForEach(section.contacts) { contact in
                            NavigationLink {
                                ContactDetailView(contact: contact)
                            } label: {
                                contactRow(contact)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                endSearchInteraction()
                            })
                        }
                    } header: {
                        Text(section.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if store.isLoading && filteredContacts.isEmpty {
                    ProgressView()
                } else if contactSections.isEmpty {
                    emptyState
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                if !searchText.isEmpty, let phone = contact.primaryPhone?.value {
                    Text(formatPhone(phone))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSearching {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("No contacts match your search.")
            }
        } else {
            ContentUnavailableView {
                Label("No Contacts", systemImage: "person.crop.circle")
            } description: {
                Text("Contacts you add or sync will appear here.")
            }
        }
    }

    // MARK: - Access views

    private var accessDeniedView: some View {
        ContentUnavailableView {
            Label("No Access to Contacts", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text(store.accessState == .restricted
                 ? "Contact access is restricted on this device."
                 : "Allow access in Settings to see your contacts.")
        } actions: {
            if store.accessState == .denied {
                Button("Open Settings") {
                    openSettings()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var limitedAccessBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .foregroundStyle(.tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Access")
                    .font(.subheadline.weight(.semibold))
                Text("Only selected contacts are shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Manage") {
                openSettings()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: - Toolbar

    private var listsButton: some View {
        Button {
            registerListsTap()
        } label: {
            Text("Lists")
        }
    }

    private var hiddenTrickButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.tint)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if trickEngine.isArmed {
                    trickEngine.disarm()
                } else {
                    trickEngine.arm()
                }
            }
            .accessibilityLabel(Text("Add Contact"))
            .accessibilityAddTraits(.isButton)
    }

    private func registerListsTap() {
        listsTapCount += 1
        listsOpenWork?.cancel()

        if listsTapCount >= 3 {
            listsTapCount = 0
            listsOpenWork = nil
            showingSetup = true
            return
        }

        let work = DispatchWorkItem {
            guard listsTapCount < 3 else { return }
            listsTapCount = 0
            listsOpenWork = nil
            showingLists = true
        }
        listsOpenWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    // MARK: - Search

    private var showsSearchBar: Bool {
        store.accessState.canRead && !(store.errorMessage != nil && store.contacts.isEmpty)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("", text: $searchText, prompt: searchPrompt)
                .font(.body)
                .foregroundStyle(.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit {
                    searchFocused = false
                }
                .accessibilityLabel(Text("Search"))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background {
            Capsule()
                .fill(Color(uiColor: .tertiarySystemFill))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
    }

    private var searchPrompt: Text {
        if peekName.isEmpty {
            return Text("Search")
        }
        return Text(verbatim: peekName)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchDigits: String {
        searchText.filter(\.isNumber)
    }

    private var filteredContacts: [Contact] {
        let fakes = trickEngine.searchTrickArmed && isSearching
            ? trickEngine.forcedSearchContacts(matchingDigits: searchDigits)
            : []

        return ContactSearch.results(
            contacts: store.contacts,
            query: searchText,
            forcedContacts: fakes,
            triggerDigits: trickEngine.searchTriggerDigits,
            searchTrickArmed: trickEngine.searchTrickArmed
        )
    }

    private var contactSections: [ContactListSection] {
        ContactListSection.make(from: filteredContacts)
    }

    // MARK: - Peek

    private func updatePeekMonitoring() {
        let shouldMonitor = scenePhase == .active
            && trickEngine.peekEnabled
            && store.accessState.canRead
            && !showingLists
            && !showingSetup

        guard shouldMonitor else {
            volumeMonitor.stop()
            return
        }

        volumeMonitor.onPress = {
            performPeek()
        }
        volumeMonitor.start()
    }

    private func performPeek() {
        guard searchText.isEmpty else { return }

        let name = trickEngine.lastOpenedName
        guard !name.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        trickEngine.triggerPeekFeedback()
        cancelPeek()
        peekName = name

        let work = DispatchWorkItem {
            if peekName == name {
                peekName = ""
            }
        }
        peekClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func cancelPeek() {
        peekClearWork?.cancel()
        peekClearWork = nil
        peekName = ""
    }

    private func endSearchInteraction() {
        searchFocused = false
        cancelPeek()
    }
}

// MARK: - Sections

private struct ContactListSection: Identifiable {
    let title: String
    let contacts: [Contact]

    var id: String { title }

    static func make(from contacts: [Contact]) -> [ContactListSection] {
        let collation = UILocalizedIndexedCollation.current()
        var buckets: [Int: [Contact]] = [:]

        for contact in contacts {
            let item = ContactCollationItem(contact: contact)
            let index = collation.section(
                for: item,
                collationStringSelector: #selector(getter: ContactCollationItem.collationName)
            )
            buckets[index, default: []].append(contact)
        }

        return buckets.keys.sorted().map { index in
            let sorted = (buckets[index] ?? []).sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }
            return ContactListSection(
                title: collation.sectionTitles[index],
                contacts: sorted
            )
        }
    }
}

private final class ContactCollationItem: NSObject {
    let contact: Contact

    init(contact: Contact) {
        self.contact = contact
        super.init()
    }

    @objc var collationName: String { contact.name }
}
