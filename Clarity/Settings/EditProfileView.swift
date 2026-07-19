import SwiftUI
import SwiftData
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let profile: UserProfile
    
    @State private var name: String
    @State private var email: String
    @State private var showRestartAlert = false
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    init(profile: UserProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _email = State(initialValue: profile.email)
        _selectedImageData = State(initialValue: profile.profileImageData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                photoSection
                personalInfoSection
                disclaimerSection
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("Restart Now") {
                    restartApp()
                }
            } message: {
                Text("Changing your email requires a quick restart to update your session.")
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            withAnimation {
                                selectedImageData = data
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Extracted Views
    
    @ViewBuilder
    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    profileImage
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Change Photo")
                            .font(.caption)
                            .foregroundStyle(Color.clarityBlue)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }
    
    @ViewBuilder
    private var profileImage: some View {
        if let data = selectedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(LinearGradient.clarityPrimary)
        }
    }
    
    @ViewBuilder
    private var personalInfoSection: some View {
        Section("Personal Info") {
            TextField("Name", text: $name)
                .textContentType(.name)
            
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
        }
    }
    
    @ViewBuilder
    private var disclaimerSection: some View {
        Section {
            Text("Changing your email address will require the app to restart to update your session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveChanges()
            }
            .disabled(name.isEmpty || email.isEmpty)
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        let emailChanged = profile.email != email
        
        profile.name = name
        profile.email = email
        profile.profileImageData = selectedImageData
        
        try? context.save()
        
        if emailChanged {
            AuthManager.shared.saveLastUserEmail(email)
            showRestartAlert = true
        } else {
            dismiss()
        }
    }
    
    private func restartApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentView())
            window.makeKeyAndVisible()
        }
    }
}

