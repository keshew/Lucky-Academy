

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
}

// Core/AppStore.swift
import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState

    private let store = DefaultsStore()

    init() {
        self.state = store.load()
    }

    func commit(_ mutate: (inout AppState) -> Void) {
        var copy = state
        mutate(&copy)
        copy.inventory.clamp()
        state = copy
        store.save(state)
    }

    func hardReset() {
        store.reset()
        state = AppState()
    }

    // MARK: - Helpers
    func canClaimDaily(now: Date = Date()) -> Bool {
        guard let iso = state.lastDailyClaimISO,
              let last = ISO8601DateFormatter().date(from: iso) else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }

    func claimDaily() {
        let iso = ISO8601DateFormatter().string(from: Date())
        commit { s in
            s.lastDailyClaimISO = iso
            s.inventory.coins += 200
            s.inventory.gems += 5
            s.path.energy = min(s.path.maxEnergy, s.path.energy + 5)
        }
    }
}

// Core/Haptics.swift
import UIKit

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// UI/Theme.swift
import SwiftUI

enum Theme {
    static let bg = LinearGradient(
        colors: [Color.black, Color(red: 0.08, green: 0.05, blue: 0.18)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.12)
    static let text = Color.white
    static let subtext = Color.white.opacity(0.75)
    static let accent = Color.cyan
}

// UI/Components/MPCard.swift
import SwiftUI

struct MPCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// UI/Components/MPButton.swift
import SwiftUI

struct MPButton: View {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
            .background(isEnabled ? Theme.accent.opacity(0.25) : Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isEnabled ? Theme.accent.opacity(0.35) : Theme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!isEnabled)
    }
}

// UI/Components/MPProgressBar.swift
import SwiftUI

struct MPProgressBar: View {
    let value: Double // 0..1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 999)
                    .fill(Theme.accent.opacity(0.55))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 10)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// UI/Components/MPChip.swift
import SwiftUI

struct MPChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accent.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Theme.subtext)
                Text(value).font(.headline).foregroundStyle(.white)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// UI/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            PathTabView()
                .tabItem { Label("Path", systemImage: "map") }

            GamesTabView()
                .tabItem { Label("Games", systemImage: "gamecontroller") }

            CollectionTabView()
                .tabItem { Label("Collection", systemImage: "sparkle.magnifyingglass") }

            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}

// UI/Tabs/Path/PathViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class PathViewModel: ObservableObject {
    @Published var toast: String? = nil

    private var toastTask: Task<Void, Never>?

    func showToast(_ msg: String) {
        toast = msg
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            self.toast = nil
        }
    }
}

// UI/Tabs/Path/PathTabView.swift
import SwiftUI

struct PathTabView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var vm = PathViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Mythic Path").font(.title2).bold().foregroundStyle(.white)
                                Spacer()
                                Text("Step \(store.state.path.step)/\(store.state.path.maxSteps)")
                                    .foregroundStyle(Theme.subtext)
                            }

                            MPProgressBar(value: Double(store.state.path.step) / Double(max(1, store.state.path.maxSteps)))

                            HStack(spacing: 10) {
                                MPChip(title: "Coins", value: "\(store.state.inventory.coins)", systemImage: "circle.grid.cross")
                                MPChip(title: "Gems", value: "\(store.state.inventory.gems)", systemImage: "diamond.fill")
                                MPChip(title: "Keys", value: "\(store.state.inventory.keys)", systemImage: "key.fill")
                            }
                        }
                    }

                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Energy").font(.headline).foregroundStyle(.white)
                            MPProgressBar(value: Double(store.state.path.energy) / Double(max(1, store.state.path.maxEnergy)))
                            Text("\(store.state.path.energy)/\(store.state.path.maxEnergy)")
                                .foregroundStyle(Theme.subtext)

                            MPButton("Advance One Step", systemImage: "arrow.right.circle.fill", isEnabled: store.state.path.energy > 0) {
                                store.commit { s in
                                    guard s.path.energy > 0 else { return }
                                    s.path.energy -= 1
                                    s.path.step = min(s.path.maxSteps, s.path.step + 1)
                                    s.inventory.coins += 25
                                    if s.path.step % 5 == 0 { s.inventory.keys += 1 }
                                }
                                Haptics.success()
                                vm.showToast("Progress saved. +25 Coins")
                            }
                        }
                    }

                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Reward").font(.headline).foregroundStyle(.white)
                            Text("Claim a daily bonus to boost your progress.")
                                .foregroundStyle(Theme.subtext)

                            let canClaim = store.canClaimDaily()
                            MPButton(canClaim ? "Claim Daily Bonus" : "Already Claimed Today",
                                     systemImage: "gift.fill",
                                     isEnabled: canClaim) {
                                store.claimDaily()
                                Haptics.success()
                                vm.showToast("Daily claimed. +200 Coins, +5 Gems")
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }

            if let toast = vm.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.subheadline).bold()
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: vm.toast)
            }
        }
    }

    private var header: some View {
        MPCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back").foregroundStyle(Theme.subtext)
                    Text("Collect relics. Unlock rewards.")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

// UI/Tabs/Games/GamesViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class GamesViewModel: ObservableObject {
    @Published var selected: MiniGame? = nil
    @Published var sheetTitle: String = ""
}

// UI/Tabs/Games/GamesTabView.swift
import SwiftUI

struct GamesTabView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var vm = GamesViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mini Games").font(.title2).bold().foregroundStyle(.white)
                            Text("Play short sessions to earn rewards. No risk, pure progress.")
                                .foregroundStyle(Theme.subtext)
                        }
                    }

                    ForEach(MiniGame.allCases) { game in
                        MPCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: game.systemImage)
                                        .foregroundStyle(Theme.accent)
                                    Text(game.rawValue).font(.headline).foregroundStyle(.white)
                                    Spacer()
                                }
                                Text(game.subtitle).foregroundStyle(Theme.subtext)

                                MPButton("Open", systemImage: "play.fill") {
                                    vm.selected = game
                                }
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
        }
        .sheet(item: $vm.selected) { game in
            NavigationStack {
                switch game {
                case .portalPick:
                    PortalPickView()
                case .perfectPulse:
                    PerfectPulseView()
                case .relicMerge:
                    RelicMergeView()
                }
            }
            .presentationDetents([.large])
        }
    }
}

// UI/Tabs/Games/PortalPickView.swift
import SwiftUI

struct PortalPickView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickedIndex: Int? = nil
    @State private var message: String = "Pick one portal to claim your reward."

    private let portals = ["A", "B", "C", "D", "E"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Portal Pick").font(.title2).bold().foregroundStyle(.white)
                            Text(message).foregroundStyle(Theme.subtext)
                        }
                    }

                    MPCard {
                        VStack(spacing: 12) {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(portals.indices, id: \.self) { i in
                                    Button {
                                        guard pickedIndex == nil else { return }
                                        pickedIndex = i
                                        grantReward(for: i)
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color.white.opacity(0.06))
                                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke, lineWidth: 1))

                                            VStack(spacing: 8) {
                                                Image(systemName: "circle.hexagongrid.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(pickedIndex == i ? Theme.accent : Color.white.opacity(0.8))
                                                Text("Portal \(portals[i])")
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.vertical, 18)
                                        }
                                    }
                                }
                            }

                            MPButton("Reset", systemImage: "arrow.counterclockwise", isEnabled: pickedIndex != nil) {
                                pickedIndex = nil
                                message = "Pick one portal to claim your reward."
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
        }
        .navigationTitle("Portal Pick")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func grantReward(for index: Int) {
        // Deterministic reward (safe for stores): based on index + current step
        let step = store.state.path.step
        let seed = (index + 1) * 31 + step * 7

        let coins = 80 + (seed % 90)
        let gems = (seed % 5 == 0) ? 2 : 0
        let key = (seed % 11 == 0) ? 1 : 0

        store.commit { s in
            s.inventory.coins += coins
            s.inventory.gems += gems
            s.inventory.keys += key
        }

        Haptics.success()
        var parts: [String] = ["+\(coins) Coins"]
        if gems > 0 { parts.append("+\(gems) Gems") }
        if key > 0 { parts.append("+\(key) Key") }
        message = "Reward claimed: " + parts.joined(separator: ", ") + "."
    }
}

// UI/Tabs/Games/PerfectPulseView.swift
import SwiftUI

struct PerfectPulseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Double = 0
    @State private var scoreText: String = "Tap when the pulse is strongest."

    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                MPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Perfect Pulse").font(.title2).bold().foregroundStyle(.white)
                        Text(scoreText).foregroundStyle(Theme.subtext)
                    }
                }

                MPCard {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 210, height: 210)
                                .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))

                            Circle()
                                .fill(Theme.accent.opacity(0.18))
                                .frame(width: 120 + pulseValue * 90, height: 120 + pulseValue * 90)
                                .overlay(Circle().stroke(Theme.accent.opacity(0.35), lineWidth: 1))

                            Text("\(Int(pulseValue * 100))%")
                                .font(.title2).bold()
                                .foregroundStyle(.white)
                        }
                        .onReceive(timer) { _ in
                            phase += 0.035
                        }

                        MPButton("Tap", systemImage: "hand.tap.fill") {
                            evaluateTap()
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
        }
        .navigationTitle("Perfect Pulse")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var pulseValue: Double {
        // 0..1 sine wave
        let v = (sin(phase) + 1) / 2
        return v
    }

    private func evaluateTap() {
        // Skill-based: closer to 1.0 = better
        let accuracy = pulseValue
        let coins = Int(40 + accuracy * 120)
        let gems = accuracy > 0.92 ? 1 : 0

        store.commit { s in
            s.inventory.coins += coins
            if gems > 0 { s.inventory.gems += gems }
        }

        if accuracy > 0.92 { Haptics.success() } else { Haptics.light() }

        scoreText = "Accuracy: \(Int(accuracy * 100))%. Reward: +\(coins) Coins" + (gems > 0 ? ", +1 Gem." : ".")
    }
}

// UI/Tabs/Games/RelicMergeView.swift
import SwiftUI

struct RelicMergeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<String> = []
    @State private var info: String = "Select 2 relics to merge into a higher level."

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relic Merge").font(.title2).bold().foregroundStyle(.white)
                            Text(info).foregroundStyle(Theme.subtext)
                        }
                    }

                    let relics = store.state.collection.relics
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(relics) { relic in
                            Button {
                                toggle(relic.id)
                            } label: {
                                MPCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(relic.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: selectedIDs.contains(relic.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedIDs.contains(relic.id) ? Theme.accent : Theme.subtext)
                                        }
                                        Text(relic.rarity.rawValue)
                                            .foregroundStyle(Theme.subtext)
                                        Text("Level \(relic.level)")
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(selectedIDs.contains(relic.id) ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }

                    MPCard {
                        VStack(spacing: 12) {
                            MPButton("Merge Selected (2)", systemImage: "arrow.triangle.merge", isEnabled: selectedIDs.count == 2) {
                                mergeTwo()
                            }
                            MPButton("Clear Selection", systemImage: "xmark", isEnabled: !selectedIDs.isEmpty) {
                                selectedIDs.removeAll()
                                info = "Select 2 relics to merge into a higher level."
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
        }
        .navigationTitle("Relic Merge")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            if selectedIDs.count < 2 { selectedIDs.insert(id) }
            else { Haptics.warning() }
        }
    }

    private func mergeTwo() {
        let ids = Array(selectedIDs)
        guard ids.count == 2 else { return }

        store.commit { s in
            guard let i1 = s.collection.relics.firstIndex(where: { $0.id == ids[0] }),
                  let i2 = s.collection.relics.firstIndex(where: { $0.id == ids[1] }) else { return }

            // Upgrade first, reset second (simple and deterministic)
            s.collection.relics[i1].level += 1
            let newLevel = s.collection.relics[i1].level

            // Reward for merging
            s.inventory.coins += 60 + newLevel * 10
            if newLevel % 3 == 0 { s.inventory.gems += 1 }

            // Replace second with a fresh relic
            s.collection.relics[i2] = Relic.seed(Int.random(in: 0..<9999) % 12) // random seed is fine for a casual collection
        }

        Haptics.success()
        selectedIDs.removeAll()
        info = "Merge complete! Your relic leveled up and you earned a bonus."
    }
}

// UI/Tabs/Collection/CollectionViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class CollectionViewModel: ObservableObject {
    func rarityColor(_ r: RelicRarity) -> Color {
        switch r {
        case .common: return .white.opacity(0.7)
        case .rare: return .cyan.opacity(0.9)
        case .epic: return .purple.opacity(0.9)
        }
    }
}

// UI/Tabs/Collection/CollectionTabView.swift
import SwiftUI

struct CollectionTabView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var vm = CollectionViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relic Collection").font(.title2).bold().foregroundStyle(.white)
                            Text("Upgrade relics to complete sets and boost your progression.")
                                .foregroundStyle(Theme.subtext)
                        }
                    }

                    let relics = store.state.collection.relics
                    ForEach(relics) { relic in
                        MPCard {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 52, height: 52)
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                                    Image(systemName: "seal.fill")
                                        .foregroundStyle(vm.rarityColor(relic.rarity))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(relic.name).font(.headline).foregroundStyle(.white)
                                    Text("\(relic.rarity.rawValue) • Level \(relic.level)")
                                        .foregroundStyle(Theme.subtext)
                                }
                                Spacer()
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
        }
    }
}

// UI/Tabs/Settings/SettingsViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var confirmReset = false
}

// UI/Tabs/Settings/SettingsTabView.swift
import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Settings").font(.title2).bold().foregroundStyle(.white)
                            Text("This app is a casual mini-game collection with deterministic rewards and progression.")
                                .foregroundStyle(Theme.subtext)
                        }
                    }

                    MPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data").font(.headline).foregroundStyle(.white)
                            MPButton("Reset Progress", systemImage: "trash.fill") {
                                vm.confirmReset = true
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
        }
        .alert("Reset Progress?", isPresented: $vm.confirmReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                store.hardReset()
                Haptics.warning()
            }
        } message: {
            Text("This will clear local data stored in UserDefaults.")
        }
    }
}


import Foundation

enum MiniGame: String, Codable, CaseIterable, Identifiable {
    case portalPick = "Portal Pick"
    case perfectPulse = "Perfect Pulse"
    case relicMerge = "Relic Merge"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .portalPick: return "Choose a portal and claim a reward."
        case .perfectPulse: return "Tap on the beat for bonus accuracy."
        case .relicMerge: return "Merge relics to upgrade your collection."
        }
    }

    var systemImage: String {
        switch self {
        case .portalPick: return "sparkles"
        case .perfectPulse: return "waveform.path.ecg"
        case .relicMerge: return "square.stack.3d.up"
        }
    }
}

struct Inventory: Codable, Equatable {
    var coins: Int = 250
    var gems: Int = 15
    var keys: Int = 2

    mutating func clamp() {
        coins = max(0, coins)
        gems = max(0, gems)
        keys = max(0, keys)
    }
}

struct PathState: Codable, Equatable {
    var step: Int = 0
    var maxSteps: Int = 30
    var energy: Int = 10
    var maxEnergy: Int = 10
}

enum RelicRarity: String, Codable, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
}

struct Relic: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var rarity: RelicRarity
    var level: Int

    static func seed(_ i: Int) -> Relic {
        let rarities: [RelicRarity] = [.common, .rare, .epic]
        return Relic(
            id: "relic_\(i)",
            name: ["Astral Shard", "Neon Sigil", "Void Coin", "Crystal Rune", "Mythic Fragment", "Echo Prism"][i % 6] + " \(i+1)",
            rarity: rarities[i % rarities.count],
            level: 1
        )
    }
}

struct CollectionState: Codable, Equatable {
    var relics: [Relic] = (0..<12).map { Relic.seed($0) }
}

struct AppState: Codable, Equatable {
    var inventory: Inventory = .init()
    var path: PathState = .init()
    var collection: CollectionState = .init()
    var lastDailyClaimISO: String? = nil
}
