import Foundation
#if canImport(CarPlay)
import CarPlay
import UIKit
import AIRoadTripToursCore
import AIRoadTripToursServices

/// CarPlay scene delegate for audio tour interface.
@available(iOS 14.0, *)
@MainActor
public class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private let locationService = LocationService()
    private var appState: AppState?
    private var nearbyPOIs: [POI] = []
    private var isLoadingPOIs = false

    // MARK: - Scene Lifecycle

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Request location permissions
        locationService.requestLocationPermission()

        // Set up initial templates
        setupRootTemplate()

        // Load nearby POIs
        Task {
            await loadNearbyPOIs()
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.mapTemplate = nil
    }

    // MARK: - Template Setup

    private func setupRootTemplate() {
        guard let interfaceController = interfaceController else { return }

        // Create tab bar with main sections
        let discoverTemplate = createDiscoverTemplate()
        let toursTemplate = createToursTemplate()
        let nowPlayingTemplate = createNowPlayingTemplate()

        let tabBarTemplate = CPTabBarTemplate(templates: [
            discoverTemplate,
            toursTemplate,
            nowPlayingTemplate
        ])

        interfaceController.setRootTemplate(tabBarTemplate, animated: true) { success, error in
            if let error = error {
                print("Error setting CarPlay root template: \(error)")
            }
        }
    }

    // MARK: - Discover Template

    private func createDiscoverTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: "Nearby POIs",
            sections: [createNearbyPOIsSection()]
        )
        template.tabImage = UIImage(systemName: "map")
        template.showsTabBadge = false
        return template
    }

    private func createNearbyPOIsSection() -> CPListSection {
        if isLoadingPOIs {
            return CPListSection(items: [
                CPListItem(
                    text: "Loading nearby points of interest...",
                    detailText: nil
                )
            ])
        }

        if nearbyPOIs.isEmpty {
            return CPListSection(items: [
                CPListItem(
                    text: "No nearby POIs found",
                    detailText: "Drive to explore new locations"
                )
            ])
        }

        let items = nearbyPOIs.prefix(12).map { poi -> CPListItem in
            let item = CPListItem(
                text: poi.name,
                detailText: poi.description ?? poi.category.rawValue
            )

            // Add handler for selecting POI
            item.handler = { [weak self] item, completion in
                self?.handlePOISelection(poi: poi)
                completion()
            }

            // Set accessory based on whether POI is selected
            if let appState = appState, appState.selectedPOIs.contains(poi) {
                item.accessoryType = .cloud // Using cloud as "selected" indicator
            }

            return item
        }

        return CPListSection(items: Array(items))
    }

    // MARK: - Tours Template

    private func createToursTemplate() -> CPListTemplate {
        let sections = createToursSection()
        let template = CPListTemplate(
            title: "Tours",
            sections: sections
        )
        template.tabImage = UIImage(systemName: "list.bullet")
        template.showsTabBadge = false
        return template
    }

    private func createToursSection() -> [CPListSection] {
        var sections: [CPListSection] = []

        // Active tour section
        if let appState = appState,
           #available(iOS 17.0, *),
           appState.audioTourManager.isPrepared {
            let activeItem = CPListItem(
                text: "Active Tour",
                detailText: "\(appState.audioTourManager.currentPOIs.count) POIs"
            )
            activeItem.handler = { [weak self] _, completion in
                self?.showActiveTour()
                completion()
            }
            sections.append(CPListSection(items: [activeItem]))
        }

        // Quick start section
        if let appState = appState, !appState.selectedPOIs.isEmpty {
            let startItem = CPListItem(
                text: "Start Tour with \(appState.selectedPOIs.count) Selected POIs",
                detailText: "Tap to begin audio tour"
            )
            startItem.handler = { [weak self] _, completion in
                Task {
                    await self?.startQuickTour()
                    completion()
                }
            }
            sections.append(CPListSection(items: [startItem]))
        }

        // Empty state
        if sections.isEmpty {
            let emptyItem = CPListItem(
                text: "No tours available",
                detailText: "Select POIs from Discover to create a tour"
            )
            sections.append(CPListSection(items: [emptyItem]))
        }

        return sections
    }

    // MARK: - Now Playing Template

    private func createNowPlayingTemplate() -> CPNowPlayingTemplate {
        let template = CPNowPlayingTemplate.shared
        template.tabImage = UIImage(systemName: "speaker.wave.3")
        template.showsTabBadge = false

        // CarPlay will show now playing controls automatically
        // using the MPNowPlayingInfoCenter we set in NarrationAudio.swift

        return template
    }

    // MARK: - Map Template

    private func createMapTemplate() -> CPMapTemplate {
        let mapTemplate = CPMapTemplate()
        mapTemplate.showPanningInterface = false

        // Add trip preview if we have POIs
        if let appState = appState, !appState.selectedPOIs.isEmpty {
            updateMapWithTripPreview(mapTemplate: mapTemplate, pois: Array(appState.selectedPOIs))
        }

        self.mapTemplate = mapTemplate
        return mapTemplate
    }

    private func updateMapWithTripPreview(mapTemplate: CPMapTemplate, pois: [POI]) {
        // Create trip preview with POI destinations
        let destinations = pois.prefix(5).map { poi -> CPTrip in
            let item = MKMapItem(
                placemark: MKPlacemark(
                    coordinate: CLLocationCoordinate2D(
                        latitude: poi.location.latitude,
                        longitude: poi.location.longitude
                    )
                )
            )
            item.name = poi.name
            return CPTrip(origin: item, destination: item, routeChoices: [])
        }

        // Note: Full trip implementation would require route calculations
        // For now, we're setting up the structure
    }

    // MARK: - Data Loading

    private func loadNearbyPOIs() async {
        guard let appState = appState,
              let userLocation = locationService.currentLocation else {
            return
        }

        isLoadingPOIs = true
        refreshDiscoverTemplate()

        do {
            nearbyPOIs = try await appState.poiRepository.findNearby(
                location: userLocation,
                radiusMiles: 25.0,
                categories: nil
            )
            isLoadingPOIs = false
            refreshDiscoverTemplate()
        } catch {
            print("Error loading nearby POIs for CarPlay: \(error)")
            isLoadingPOIs = false
            nearbyPOIs = []
            refreshDiscoverTemplate()
        }
    }

    private func refreshDiscoverTemplate() {
        guard let interfaceController = interfaceController else { return }

        // Find and update the Discover tab
        if let tabBar = interfaceController.rootTemplate as? CPTabBarTemplate,
           let discoverTemplate = tabBar.templates.first as? CPListTemplate {
            discoverTemplate.updateSections([createNearbyPOIsSection()])
        }
    }

    private func refreshToursTemplate() {
        guard let interfaceController = interfaceController else { return }

        // Find and update the Tours tab
        if let tabBar = interfaceController.rootTemplate as? CPTabBarTemplate,
           tabBar.templates.count > 1,
           let toursTemplate = tabBar.templates[1] as? CPListTemplate {
            toursTemplate.updateSections(createToursSection())
        }
    }

    // MARK: - Actions

    private func handlePOISelection(poi: POI) {
        guard let appState = appState else { return }

        // Toggle POI selection
        if appState.selectedPOIs.contains(poi) {
            appState.selectedPOIs.remove(poi)
        } else {
            appState.selectedPOIs.insert(poi)
        }

        // Refresh templates to show updated selection
        refreshDiscoverTemplate()
        refreshToursTemplate()
    }

    private func startQuickTour() async {
        guard let appState = appState,
              let userLocation = locationService.currentLocation,
              !appState.selectedPOIs.isEmpty else {
            return
        }

        // Optimize route
        let optimizer = RouteOptimizer()
        let optimizedPOIs = await optimizer.optimizeRoute(
            startingFrom: userLocation,
            visiting: Array(appState.selectedPOIs)
        )

        // Start tour
        if #available(iOS 17.0, *) {
            await appState.audioTourManager.startTour(
                pois: optimizedPOIs,
                userInterests: appState.currentUser?.interests ?? []
            )

            // Show map template
            showMapTemplate()

            // Refresh tours template
            refreshToursTemplate()
        }
    }

    private func showActiveTour() {
        showMapTemplate()
    }

    private func showMapTemplate() {
        guard let interfaceController = interfaceController else { return }

        let mapTemplate = createMapTemplate()
        interfaceController.pushTemplate(mapTemplate, animated: true) { success, error in
            if let error = error {
                print("Error showing map template: \(error)")
            }
        }
    }

    // MARK: - Public Interface

    public func setAppState(_ appState: AppState) {
        self.appState = appState

        // Refresh templates with actual data
        if interfaceController != nil {
            Task {
                await loadNearbyPOIs()
            }
        }
    }

    public func updateNowPlaying(narration: Narration?, poi: POI?) {
        // CarPlay automatically displays now playing info from MPNowPlayingInfoCenter
        // which we already set up in NarrationAudio.swift
        // No additional work needed here
    }

    public func refreshAllTemplates() {
        refreshDiscoverTemplate()
        refreshToursTemplate()
    }
}
#endif
