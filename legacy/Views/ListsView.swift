import SwiftUI

struct ListsView: View {
    @ObservedObject var store: ContactStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    selectionRow(
                        title: NSLocalizedString("All Contacts", comment: "All contacts list"),
                        isSelected: store.selectedGroupID == nil
                    ) {
                        store.selectGroup(nil)
                        dismiss()
                    }
                } footer: {
                    if store.accessState == .limited {
                        Text("Only selected contacts are available. Manage access in Settings.")
                    }
                }

                if !store.groups.isEmpty {
                    Section {
                        ForEach(store.groups) { group in
                            selectionRow(
                                title: group.name,
                                isSelected: store.selectedGroupID == group.id
                            ) {
                                store.selectGroup(group.id)
                                dismiss()
                            }
                        }
                    } header: {
                        Text("Lists")
                    } footer: {
                        Text("Lists are managed by the accounts on this device.")
                    }
                }
            }
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func selectionRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
