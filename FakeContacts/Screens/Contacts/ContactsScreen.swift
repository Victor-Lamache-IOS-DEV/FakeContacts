import SwiftUI
import UIKit

struct ContactsScreen: View {
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
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("Contacts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        listsButton
                    }
                    ToolbarItem(placement: .principal) {
                        titleButton
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsSearchBar {
                        bottomBar
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
                    ListsSheet(store: store)
                        .environmentObject(trickEngine)
                }
                .sheet(isPresented: $showingSetup, onDismiss: {
                    updatePeekMonitoring()
                }) {
                    SetupScreen()
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
            contactsList
        }
    }

    private var contactsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if store.accessState == .limited {
                        limitedAccessBanner
                    }

                    if !isSearching, let myCard = trickEngine.myCardContact {
                        NavigationLink {
                            ContactDetailScreen(contact: myCard)
                        } label: {
                            MyCardRow(contact: myCard)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(contactSections) { section in
                        Section {
                            ForEach(Array(section.contacts.enumerated()), id: \.element.id) { index, contact in
                                NavigationLink {
                                    ContactDetailScreen(contact: contact)
                                } label: {
                                    ContactRow(contact: contact, phone: isSearching ? contact.primaryPhone?.value : nil)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    endSearchInteraction()
                                })

                                if index < section.contacts.count - 1 {
                                    rowSeparator
                                }
                            }
                        } header: {
                            SectionHeader(title: section.title)
                                .id(section.id)
                        }
                    }
                }
                .padding(.trailing, showsSectionIndex ? 24 : 0)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if store.isLoading && filteredContacts.isEmpty {
                    ProgressView()
                } else if contactSections.isEmpty {
                    emptyState
                }
            }
            .overlay(alignment: .trailing) {
                if showsSectionIndex {
                    SectionIndex(letters: indexLetters) { letterIndex in
                        scrollToLetter(letterIndex, proxy: proxy)
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, 68)
            .padding(.trailing, 16)
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
    }

    private var limitedAccessBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .foregroundStyle(Theme.link)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Access")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: - Toolbar and hidden triggers

    private var titleButton: some View {
        Text("Contacts")
            .font(.headline)
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                showingSetup = true
            }
    }

    private var listsButton: some View {
        Button {
            registerListsTap()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .semibold))
        }
        .accessibilityLabel(Text("Lists"))
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

    private func toggleArm() {
        if trickEngine.isArmed {
            trickEngine.disarm()
        } else {
            trickEngine.arm()
        }
    }

    // MARK: - Bottom bar

    private var showsSearchBar: Bool {
        store.accessState.canRead && !(store.errorMessage != nil && store.contacts.isEmpty)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            searchField

            PlusButton(isArmed: trickEngine.isArmed) {
                toggleArm()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("", text: $searchText, prompt: searchPrompt)
                .font(.body)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit {
                    searchFocused = false
                }
                .accessibilityLabel(Text("Search"))

            if searchText.isEmpty {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
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
        .padding(.horizontal, 18)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
    }

    private var searchPrompt: Text {
        if peekName.isEmpty {
            return Text("Search")
        }
        return Text(verbatim: peekName)
    }

    // MARK: - Search and sections

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

    private var showsSectionIndex: Bool {
        !isSearching && !contactSections.isEmpty
    }

    private var indexLetters: [String] {
        UILocalizedIndexedCollation.current().sectionTitles
    }

    private func scrollToLetter(_ letterIndex: Int, proxy: ScrollViewProxy) {
        guard let section = contactSections.first(where: { $0.collationIndex >= letterIndex })
            ?? contactSections.last else { return }
        proxy.scrollTo(section.id, anchor: .top)
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
