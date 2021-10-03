//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-10-03.
//

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
import RenderKit
import Resolution
import PixelColor
import MapKit

final public class MapsPIX: PIXResource, NODEResolution, PIXViewable {

    override public var shaderName: String { return "contentResourcePIX" }
        
    public enum MapType: String, Enumable {
        case standard
        case mutedStandard
        case satellite
        case satelliteFlyover
        case hybrid
        case hybridFlyover
        public var index: Int {
            switch self {
            case .standard:
                return 0
            case .mutedStandard:
                return 1
            case .satellite:
                return 2
            case .satelliteFlyover:
                return 3
            case .hybrid:
                return 4
            case .hybridFlyover:
                return 5
            }
        }
        public var name: String {
            switch self {
            case .standard:
                return "Standard"
            case .mutedStandard:
                return "Muted Standard"
            case .satellite:
                return "Satellite"
            case .satelliteFlyover:
                return "Satellite Flyover"
            case .hybrid:
                return "Hybrid"
            case .hybridFlyover:
                return "Hybrid Flyover"
            }
        }
        public var typeName: String {
            rawValue
        }
        var mapType: MKMapType {
            switch self {
            case .standard:
                return .standard
            case .mutedStandard:
                return .mutedStandard
            case .satellite:
                return .satellite
            case .satelliteFlyover:
                return .satelliteFlyover
            case .hybrid:
                return .hybrid
            case .hybridFlyover:
                return .hybridFlyover
            }
        }
    }
    
    // MARK: - Properties
    
    @LiveResolution("resolution") public var resolution: Resolution = ._128
    @LiveEnum("mapType") public var mapType: MapType = .standard
    @LiveFloat("latitude", range: -90...90, increment: 45) public var latitude: CGFloat = 0
    @LiveFloat("longitude", range: -180...180, increment: 45) public var longitude: CGFloat = 0
    @LiveFloat("span", range: 0...180, increment: 45) public var span: CGFloat = 180
    @LiveBool("showsBuildings") public var showsBuildings: Bool = false
    @LiveBool("showsPointsOfInterest") public var showsPointsOfInterest: Bool = false

    // MARK: - Property Helpers
    
    public override var liveList: [LiveWrap] {
        [_resolution, _mapType, _latitude, _longitude, _span, _showsBuildings, _showsPointsOfInterest]
    }
    
    // MARK: - Life Cycle
    
    public init(at resolution: Resolution = .auto(render: PixelKit.main.render)) {
        self.resolution = resolution
        super.init(name: "Maps", typeName: "pix-content-resource-maps")
        setNeedsBuffer()
    }
    
    public required init() {
        super.init(name: "Maps", typeName: "pix-content-resource-maps")
        setNeedsBuffer()
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        setNeedsBuffer()
    }
    
    // MARK: Live
    
    public override func liveValueChanged() {
        super.liveValueChanged()
        
        setNeedsBuffer()
    }
    
    // MARK: Buffer
    
    func setNeedsBuffer() {

        PixelKit.main.logger.log(node: self, .detail, .resource, "Set Needs Buffer.")

        let mapSnapshotOptions = MKMapSnapshotter.Options()

        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let span = MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        let region = MKCoordinateRegion(center: center, span: span)
        guard region.isValid else { return }
        mapSnapshotOptions.region = region

        mapSnapshotOptions.size = CGSize(width: resolution.width / Resolution.scale,
                                         height: resolution.height / Resolution.scale)

        mapSnapshotOptions.showsBuildings = showsBuildings
        mapSnapshotOptions.pointOfInterestFilter = showsPointsOfInterest ? .includingAll : .excludingAll
        mapSnapshotOptions.mapType = mapType.mapType

        let snapShotter = MKMapSnapshotter(options: mapSnapshotOptions)

        snapShotter.start() { [weak self] snapshot, error in
            
            guard let snapshot = snapshot else {
                return
            }
            
            let image: UINSImage = snapshot.image
            
            do {
                
                let texture: MTLTexture = try Texture.loadTexture(from: image, device: PixelKit.main.render.metalDevice)
                
                self?.resourceTexture = texture
                
                self?.applyResolution { [weak self] in
                    self?.render()
                }
                
            } catch {
                PixelKit.main.logger.log(node: self, .error, .resource, "Texture Load Failed.", e: error)
            }
            
        }
        
    }
    
}
