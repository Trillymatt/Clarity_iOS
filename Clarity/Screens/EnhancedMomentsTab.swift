import SwiftUI
import SwiftData

// MARK: - Enhanced Moments Tab
struct EnhancedMomentsTab: View {
    @Environment(\.modelContext) private var context
    let userEmail: String
    @Query private var moments: [LifeMoment]
    
    init(userEmail: String) {
        self.userEmail = userEmail
        _moments = Query(filter: #Predicate { $0.ownerEmail == userEmail }, sort: \LifeMoment.date, order: .reverse)
    }
    
    @State private var showAdd = false
    @State private var prefillTitle = ""
    @State private var selectedImage: Data? = nil // For full screen image viewing
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Spacer for nav bar
                        Color.clear.frame(height: 90)
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Journal")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("Capture your journey")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if moments.isEmpty {
                            EmptyJournalState()
                        } else {
                            LazyVStack(spacing: 40) {
                                ForEach(groupedByDay(moments: moments), id: \.key) { day, items in
                                    JournalDaySection(date: day, moments: items, onImageTap: { data in
                                        selectedImage = data
                                    }, onDelete: { moment in
                                        deleteMoment(moment)
                                    })
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(LinearGradient.clarityPrimary)
                        .clipShape(Circle())
                        .shadow(color: Color.clarityPurple.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(24)
            }
            .sheet(isPresented: $showAdd) {
                AddMomentSheet(userEmail: userEmail, prefillTitle: prefillTitle)
            }
            // Full Screen Image Viewer overlay
            .overlay {
                if let imageData = selectedImage, let uiImage = UIImage(data: imageData) {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding()
                        
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation { selectedImage = nil }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
    }
    
    private func groupedByDay(moments: [LifeMoment]) -> [(key: Date, value: [LifeMoment])] {
        let groups = Dictionary(grouping: moments) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }
    
    private func deleteMoment(_ moment: LifeMoment) {
        context.delete(moment)
        try? context.save()
    }
}

// MARK: - Subviews

struct JournalDaySection: View {
    let date: Date
    let moments: [LifeMoment]
    let onImageTap: (Data) -> Void
    let onDelete: (LifeMoment) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline Date Column
            VStack(spacing: 4) {
                Text(date, format: .dateTime.day())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(date, format: .dateTime.month())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                // Vertical Line
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
            }
            .frame(width: 50)
            .padding(.top, 4)
            
            // Content Column
            VStack(spacing: 24) {
                ForEach(moments) { moment in
                    JournalEntryCard(moment: moment, onImageTap: onImageTap)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(moment)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

struct JournalEntryCard: View {
    let moment: LifeMoment
    let onImageTap: (Data) -> Void
    @State private var showEdit = false
    
    var moodEmoji: String {
        guard let score = moment.moodScore else { return "💭" }
        switch score {
        case 0..<0.2: return "😢"
        case 0.2..<0.4: return "😕"
        case 0.4..<0.6: return "😐"
        case 0.6..<0.8: return "🙂"
        default: return "😄"
        }
    }
    
    var body: some View {
        Button(action: { showEdit = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Time & Mood
                HStack {
                    Text(moment.date, format: .dateTime.hour().minute())
                        .font(.caption.bold())
                        .foregroundStyle(Color.clarityPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clarityPurple.opacity(0.1))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(moodEmoji)
                        .font(.title3)
                }
                
                // Title
                Text(moment.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                // Note Preview
                if let note = moment.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                
                // Images Carousel
                if let images = moment.imagesData, !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(images, id: \.self) { data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            onImageTap(data)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color.clarityCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.03), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Enable internal tap gestures
        .sheet(isPresented: $showEdit) {
            AddMomentSheet(userEmail: moment.ownerEmail, momentToEdit: moment)
        }
    }
}

struct EmptyJournalState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(Color.clarityPurple.opacity(0.3))
            
            Text("Your story starts here")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            
            Text("Tap the + button to capture your first moment, thought, or photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
