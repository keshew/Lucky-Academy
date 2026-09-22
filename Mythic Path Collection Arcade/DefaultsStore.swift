
// Core/DefaultsStore.swift
import Foundation

final class DefaultsStore {
    private let defaults: UserDefaults
    private let key = "mp_app_state_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppState {
        guard let data = defaults.data(forKey: key) else { return AppState() }
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            // Corrupted data → reset gracefully
            return AppState()
        }
    }

    func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            // ignore save error in production skeleton
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
