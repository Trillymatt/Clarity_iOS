# Clarity Widgets Implementation Guide

## ✅ Files Created

1. **WidgetDataManager.swift** (Main App) - Manages data sharing with widget
2. **WidgetDataUpdater.swift** (Main App) - Computes and updates widget data
3. **Clarity_Widgets.swift** (Widget Extension) - Widget UI implementation

---

## 🔧 Setup Steps

### Step 1: Add App Groups Capability

**Both the main app AND the widget extension need the same App Group:**

1. Select the **Clarity** target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **App Groups**
4. Click **+** and add: `group.com.clarity.app`
5. Select the **Clarity Widgets** target
6. Repeat steps 2-4 with the **exact same** group identifier

> [!IMPORTANT]
> Both targets must use the **identical** App Group identifier: `group.com.clarity.app`

### Step 2: Add WidgetDataManager.swift to Widget Target

1. In Xcode, select `WidgetDataManager.swift`
2. In the **File Inspector** (right panel), under **Target Membership**
3. Check **both** `Clarity` AND `Clarity Widgets`

This allows both targets to access the shared data structure.

### Step 3: Integrate Widget Updates in Main App

Add widget updates when data changes. Open `DashboardView.swift` (or wherever you calculate the Clarity score) and add:

```swift
.onAppear {
    // Update widget when dashboard appears
    WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
}
```

**Recommended places to update widgets:**
- **DashboardView**: When it appears
- **When task is completed**: In `TaskRow.toggleCompletion()`
- **When habit is checked in**: In habit check-in logic
- **Periodically**: Every time Clarity Score is recalculated

Example in TaskRow.swift:
```swift
private func toggleCompletion() {
    withAnimation {
        task.isCompleted.toggle()
        // ... existing code ...
    }
    try? context.save()
    
    // Update widget
    if let profile = /* get user profile */ {
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: profile.email)
    }
}
```

### Step 4: Test the Widget

1. **Run the widget scheme**:
   - In Xcode, select **Clarity Widgets** scheme (top toolbar)
   - Choose a simulator or device
   - Click Run (or Cmd+R)

2. **Add widget to home screen**:
   - Long-press on home screen
   - Tap **+** button (top left)
   - Search for "Clarity"
   - Choose Small, Medium, or Large size
   - Tap **Add Widget**

3. **Test data updates**:
   - Complete a task in the main app
   - Widget should update within a few seconds

---

## 🎨 Widget Sizes

### Small (2x2)
- Clarity Score (large number)
- Task completion count
- Minimal, quick glance

### Medium (4x2)
- Clarity Score with circular progress
- Task stats
- Primary habit progress

### Large (4x4)
- Full dashboard view
- Clarity Score badge
- Detailed task info
- Detailed habit info
- Last updated timestamp

---

## 🐛 Troubleshooting

### Widget shows placeholder data
- Ensure App Groups are configured identically on both targets
- Run the main app first to generate data
- Check that `WidgetDataManager.swift` is added to Clarity Widgets target

### Widget not updating
- Verify `WidgetDataUpdater.updateWidgetData()` is being called
- Check console for error messages about App Group access
- Try: `WidgetCenter.shared.reloadAllTimelines()` to force refresh

### Compilation errors in widget
- Make sure `WidgetDataManager.swift` has target membership for both Clarity and Clarity Widgets
- Ensure shared types (like Color extensions) are available to widget target

### Widget displays but shows errors
- Check the App Group identifier matches exactly: `group.com.clarity.app`
- Verify UserDefaults suite name in `WidgetDataManager` matches the App Group

---

## 🚀 Next Steps

1. ✅ Add App Groups capability to both targets
2. ✅ Add WidgetDataManager.swift to widget target membership
3. ✅ Integrate `WidgetDataUpdater.updateWidgetData()` calls in the main app
4. ✅ Test all three widget sizes
5. Consider adding deep linking (tap widget to open specific view in app)

---

## 💡 Optional Enhancements

- **Deep Links**: Make tapping the widget open specific screens
- **Interactive Widgets**: Add buttons for quick actions (iOS 17+)
- **Lock Screen Widgets**: Create smaller circular/rectangular widgets for lock screen
- **Live Activities**: Show real-time progress for ongoing tasks
- **Smart Stack**: Configure widget relevance for better placement
