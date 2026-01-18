import Foundation
import MapKit
import CoreLocation

enum JourneyError: LocalizedError {
    case noRouteFound
    case invalidLocations
    case networkError(Error)
    case transitNotAvailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "Aucun itinéraire trouvé"
        case .invalidLocations:
            return "Positions invalides"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .transitNotAvailable:
            return "Transports en commun non disponibles pour cet itinéraire"
        case .unknown:
            return "Une erreur inattendue s'est produite"
        }
    }
}

actor JourneyService {
    static let shared = JourneyService()
    
    private init() {}
    
    func calculateTransitJourney(
        from departure: CLLocationCoordinate2D,
        to arrival: CLLocationCoordinate2D,
        departureName: String,
        arrivalName: String,
        timeOption: JourneyTimeOption = .leaveNow
    ) async throws -> Journey {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: departure))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: arrival))
        request.transportType = .transit
        request.requestsAlternateRoutes = false
        
        switch timeOption {
        case .leaveNow:
            request.departureDate = Date()
        case .departAt(let date):
            request.departureDate = date
        case .arriveBy(let date):
            request.arrivalDate = date
        }
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw JourneyError.noRouteFound
            }
            
            return parseRoute(
                route,
                departureName: departureName,
                arrivalName: arrivalName,
                departureCoordinate: departure,
                arrivalCoordinate: arrival
            )
        } catch let error as MKError {
            if error.code == .directionsNotFound {
                throw JourneyError.transitNotAvailable
            }
            throw JourneyError.networkError(error)
        } catch let error as JourneyError {
            throw error
        } catch {
            throw JourneyError.networkError(error)
        }
    }
    
    func calculateWalkingJourney(
        from departure: CLLocationCoordinate2D,
        to arrival: CLLocationCoordinate2D,
        departureName: String,
        arrivalName: String
    ) async throws -> Journey {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: departure))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: arrival))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw JourneyError.noRouteFound
            }
            
            return parseWalkingRoute(
                route,
                departureName: departureName,
                arrivalName: arrivalName,
                departureCoordinate: departure,
                arrivalCoordinate: arrival
            )
        } catch let error as JourneyError {
            throw error
        } catch {
            throw JourneyError.networkError(error)
        }
    }
    
    func calculateDrivingJourney(
        from departure: CLLocationCoordinate2D,
        to arrival: CLLocationCoordinate2D,
        departureName: String,
        arrivalName: String
    ) async throws -> Journey {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: departure))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: arrival))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw JourneyError.noRouteFound
            }
            
            return parseDrivingRoute(
                route,
                departureName: departureName,
                arrivalName: arrivalName,
                departureCoordinate: departure,
                arrivalCoordinate: arrival
            )
        } catch let error as JourneyError {
            throw error
        } catch {
            throw JourneyError.networkError(error)
        }
    }
    
    func calculateBikingJourney(
        from departure: CLLocationCoordinate2D,
        to arrival: CLLocationCoordinate2D,
        departureName: String,
        arrivalName: String
    ) async throws -> Journey {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: departure))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: arrival))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw JourneyError.noRouteFound
            }
            
            return parseBikingRoute(
                route,
                departureName: departureName,
                arrivalName: arrivalName,
                departureCoordinate: departure,
                arrivalCoordinate: arrival
            )
        } catch let error as JourneyError {
            throw error
        } catch {
            throw JourneyError.networkError(error)
        }
    }
    
    private func parseRoute(
        _ route: MKRoute,
        departureName: String,
        arrivalName: String,
        departureCoordinate: CLLocationCoordinate2D,
        arrivalCoordinate: CLLocationCoordinate2D
    ) -> Journey {
        let polylineCoords = extractPolylineCoordinates(from: route.polyline)
        var steps: [JourneyStep] = []
        var currentTime = Date()
        
        for step in route.steps {
            guard !step.instructions.isEmpty else { continue }
            
            let stepPolyline = extractPolylineCoordinates(from: step.polyline)
            let transportMode = detectTransportMode(from: step)
            let stepType = detectStepType(from: step)
            
            let stepDuration = route.expectedTravelTime / Double(max(route.steps.count, 1))
            
            let journeyStep = JourneyStep(
                type: stepType,
                instructions: step.instructions,
                distance: step.distance,
                duration: stepDuration,
                polylinePoints: stepPolyline,
                transportMode: transportMode,
                lineName: extractLineName(from: step),
                lineColor: nil,
                direction: extractDirection(from: step),
                departureStopName: nil,
                arrivalStopName: nil,
                departureTime: currentTime,
                arrivalTime: currentTime.addingTimeInterval(stepDuration),
                numberOfStops: nil
            )
            
            steps.append(journeyStep)
            currentTime = currentTime.addingTimeInterval(stepDuration)
        }
        
        if steps.isEmpty {
            let walkStep = JourneyStep(
                type: .walk,
                instructions: "Se rendre à destination",
                distance: route.distance,
                duration: route.expectedTravelTime,
                polylinePoints: polylineCoords,
                transportMode: .walk,
                departureTime: Date(),
                arrivalTime: Date().addingTimeInterval(route.expectedTravelTime)
            )
            steps.append(walkStep)
        }
        
        return Journey(
            id: UUID(),
            departure: JourneyLocation(name: departureName, coordinate: departureCoordinate),
            arrival: JourneyLocation(name: arrivalName, coordinate: arrivalCoordinate),
            steps: steps,
            totalDuration: route.expectedTravelTime,
            totalDistance: route.distance,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(route.expectedTravelTime),
            polylinePoints: polylineCoords
        )
    }
    
    private func parseWalkingRoute(
        _ route: MKRoute,
        departureName: String,
        arrivalName: String,
        departureCoordinate: CLLocationCoordinate2D,
        arrivalCoordinate: CLLocationCoordinate2D
    ) -> Journey {
        let polylineCoords = extractPolylineCoordinates(from: route.polyline)
        
        let walkStep = JourneyStep(
            type: .walk,
            instructions: "Marcher vers \(arrivalName)",
            distance: route.distance,
            duration: route.expectedTravelTime,
            polylinePoints: polylineCoords,
            transportMode: .walk,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(route.expectedTravelTime)
        )
        
        return Journey(
            id: UUID(),
            departure: JourneyLocation(name: departureName, coordinate: departureCoordinate),
            arrival: JourneyLocation(name: arrivalName, coordinate: arrivalCoordinate),
            steps: [walkStep],
            totalDuration: route.expectedTravelTime,
            totalDistance: route.distance,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(route.expectedTravelTime),
            polylinePoints: polylineCoords
        )
    }
    
    private func parseDrivingRoute(
        _ route: MKRoute,
        departureName: String,
        arrivalName: String,
        departureCoordinate: CLLocationCoordinate2D,
        arrivalCoordinate: CLLocationCoordinate2D
    ) -> Journey {
        let polylineCoords = extractPolylineCoordinates(from: route.polyline)
        
        let driveStep = JourneyStep(
            type: .drive,
            instructions: "Conduire vers \(arrivalName)",
            distance: route.distance,
            duration: route.expectedTravelTime,
            polylinePoints: polylineCoords,
            transportMode: nil,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(route.expectedTravelTime)
        )
        
        return Journey(
            id: UUID(),
            departure: JourneyLocation(name: departureName, coordinate: departureCoordinate),
            arrival: JourneyLocation(name: arrivalName, coordinate: arrivalCoordinate),
            steps: [driveStep],
            totalDuration: route.expectedTravelTime,
            totalDistance: route.distance,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(route.expectedTravelTime),
            polylinePoints: polylineCoords
        )
    }
    
    private func parseBikingRoute(
        _ route: MKRoute,
        departureName: String,
        arrivalName: String,
        departureCoordinate: CLLocationCoordinate2D,
        arrivalCoordinate: CLLocationCoordinate2D
    ) -> Journey {
        let polylineCoords = extractPolylineCoordinates(from: route.polyline)
        
        let bikeSpeed = 15.0 / 3.6
        let bikeDuration = route.distance / bikeSpeed
        
        let bikeStep = JourneyStep(
            type: .bike,
            instructions: "Vélo vers \(arrivalName)",
            distance: route.distance,
            duration: bikeDuration,
            polylinePoints: polylineCoords,
            transportMode: .bike,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(bikeDuration)
        )
        
        return Journey(
            id: UUID(),
            departure: JourneyLocation(name: departureName, coordinate: departureCoordinate),
            arrival: JourneyLocation(name: arrivalName, coordinate: arrivalCoordinate),
            steps: [bikeStep],
            totalDuration: bikeDuration,
            totalDistance: route.distance,
            departureTime: Date(),
            arrivalTime: Date().addingTimeInterval(bikeDuration),
            polylinePoints: polylineCoords
        )
    }
    
    private func extractPolylineCoordinates(from polyline: MKPolyline) -> [CoordinatePoint] {
        let pointCount = polyline.pointCount
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates.map { CoordinatePoint($0) }
    }
    
    private func detectTransportMode(from step: MKRoute.Step) -> JourneyTransportMode? {
        let instructions = step.instructions.lowercased()
        
        if instructions.contains("métro") || instructions.contains("metro") {
            return .metro
        } else if instructions.contains("tram") || instructions.contains("tramway") {
            return .tram
        } else if instructions.contains("bus") {
            return .bus
        } else if instructions.contains("train") || instructions.contains("ter") || instructions.contains("tgv") {
            return .train
        } else if instructions.contains("ferry") || instructions.contains("bateau") {
            return .ferry
        } else if instructions.contains("marche") || instructions.contains("pied") || instructions.contains("walk") {
            return .walk
        }
        
        if step.transportType == .walking {
            return .walk
        }
        
        return nil
    }
    
    private func detectStepType(from step: MKRoute.Step) -> JourneyStepType {
        if step.transportType == .walking {
            return .walk
        }
        
        let instructions = step.instructions.lowercased()
        if instructions.contains("prendre") || instructions.contains("monter") ||
           instructions.contains("métro") || instructions.contains("bus") ||
           instructions.contains("tram") || instructions.contains("train") {
            return .transit
        }
        
        return .walk
    }
    
    private func extractLineName(from step: MKRoute.Step) -> String? {
        let instructions = step.instructions
        
        let patterns = [
            "ligne ([A-Z0-9]+)",
            "Ligne ([A-Z0-9]+)",
            "([ABCD]) direction",
            "([T][0-9]+)",
            "([C][0-9]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: instructions, options: [], range: NSRange(instructions.startIndex..., in: instructions)),
               let range = Range(match.range(at: 1), in: instructions) {
                return String(instructions[range])
            }
        }
        
        return nil
    }
    
    private func extractDirection(from step: MKRoute.Step) -> String? {
        let instructions = step.instructions
        
        if let directionRange = instructions.range(of: "direction ", options: .caseInsensitive) {
            let afterDirection = instructions[directionRange.upperBound...]
            if let endRange = afterDirection.firstIndex(where: { $0 == "." || $0 == "," }) {
                return String(afterDirection[..<endRange]).trimmingCharacters(in: .whitespaces)
            }
            return String(afterDirection).trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
}
