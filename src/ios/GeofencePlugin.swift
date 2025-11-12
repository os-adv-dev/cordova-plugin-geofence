//
//  GeofencePlugin.swift
//  ionic-geofence
//
//  Created by tomasz on 07/10/14.
//
//

import Foundation
import AudioToolbox
import WebKit
import SQLite

let TAG = "GeofencePlugin"
let iOS8 = floor(NSFoundationVersionNumber) > floor(NSFoundationVersionNumber_iOS_7_1)
let iOS7 = floor(NSFoundationVersionNumber) <= floor(NSFoundationVersionNumber_iOS_7_1)

func log(_ message: String){
    NSLog("%@ - %@", TAG, message)
}

func log(_ messages: [String]) {
    for message in messages {
        log(message);
    }
}

@available(iOS 8.0, *)
@objc(HWPGeofencePlugin) class GeofencePlugin : CDVPlugin {
    lazy var geoNotificationManager = GeoNotificationManager()
    let priority = DispatchQueue.GlobalQueuePriority.default

    override func pluginInitialize () {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GeofencePlugin.didReceiveLocalNotification(_:)),
            name: NSNotification.Name(rawValue: "CDVLocalNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GeofencePlugin.didReceiveTransition(_:)),
            name: NSNotification.Name(rawValue: "handleTransition"),
            object: nil
        )
    }

    @objc
    func initialize(_ command: CDVInvokedUrlCommand) {
        log(">>>> Plugin initialization empty")

        // Use the existing geoNotificationManager instance instead of creating a new one
        geoNotificationManager.registerPermissions()

        let result: CDVPluginResult
        result = CDVPluginResult(status: CDVCommandStatus_OK)

        commandDelegate!.send(result, callbackId: command.callbackId)
    }
    
    @objc
    func requestPermissions(_ command: CDVInvokedUrlCommand) {
        log("Plugin requestPermissions")

        if iOS8 {
            promptForNotificationPermission()
        }

        // Use the existing geoNotificationManager instance instead of creating a new one
        geoNotificationManager.registerPermissions()

        let (ok, warnings, errors) = geoNotificationManager.checkRequirements()

        log(warnings)
        log(errors)

        let result: CDVPluginResult

        if ok {
            result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: warnings.joined(separator: "\n"))
        } else {
            result = CDVPluginResult(
                status: CDVCommandStatus_ILLEGAL_ACCESS_EXCEPTION,
                messageAs: (errors + warnings).joined(separator: "\n")
            )
        }

        commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc
    func deviceReady(_ command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc
    func ping(_ command: CDVInvokedUrlCommand) {
        log("Ping")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    func promptForNotificationPermission() {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(
            types: [UIUserNotificationType.sound, UIUserNotificationType.alert, UIUserNotificationType.badge],
            categories: nil
            )
        )
    }

    @objc
    func addOrUpdate(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            // do some task
            for geo in command.arguments {
                self.geoNotificationManager.addOrUpdateGeoNotification(JSON(geo))
            }
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc
    func getWatched(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            let watched = self.geoNotificationManager.getWatchedGeoNotifications()

            guard let jsonData = try? JSONSerialization.data(withJSONObject: watched, options: []),
                  let watchedJsonString = String(data: jsonData, encoding: .utf8) else {
                DispatchQueue.main.async {
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Failed to serialize watched geonotifications")
                    self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
                }
                return
            }

            DispatchQueue.main.async {
                print("📤 Sending GeoNotifications JSON to JS/OutSystems:\n\(watchedJsonString)")
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: watchedJsonString)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc
    func remove(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            for id in command.arguments {
                self.geoNotificationManager.removeGeoNotification(id as! String)
            }
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc
    func removeAll(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            self.geoNotificationManager.removeAllGeoNotifications()
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc
    func didReceiveTransition (_ notification: Notification) {
        log("didReceiveTransition")
        if let geoNotificationString = notification.object as? String {

            let js = "setTimeout('geofence.onTransitionReceived([" + geoNotificationString + "])',0)"

            evaluateJs(js)
        }
    }

    @objc
    func didReceiveLocalNotification (_ notification: Notification) {
        log("didReceiveLocalNotification")
        if UIApplication.shared.applicationState != UIApplication.State.active {
            var data = "undefined"
            if let uiNotification = notification.object as? UILocalNotification {
                if let notificationData = uiNotification.userInfo?["geofence.notification.data"] as? String {
                    data = notificationData
                }
                let js = "setTimeout('geofence.onNotificationClicked(" + data + ")',0)"

                evaluateJs(js)
            }
        }
    }
    
    @objc
    func getAuthorizationStatus(_ command: CDVInvokedUrlCommand) {
        log("getAuthorizationStatus")
        let authStatus = CLLocationManager.authorizationStatus()

        var statusString: String
          switch authStatus {
          case .notDetermined:
              statusString = "notDetermined"
          case .restricted:
              statusString = "restricted"
          case .denied:
              statusString = "denied"
          case .authorizedAlways:
              statusString = "authorizedAlways"
          case .authorizedWhenInUse:
              statusString = "authorizedWhenInUse"
          @unknown default:
              statusString = "unknown"
          }

          let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: statusString)
          commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    func evaluateJs (_ script: String) {
        if let webView = webView {
            if let uiWebView = webView as? UIWebView {
                uiWebView.stringByEvaluatingJavaScript(from: script)
            } else if let wkWebView = webView as? WKWebView {
                wkWebView.evaluateJavaScript(script, completionHandler: nil)
            }
        } else {
            log("webView is nil")
        }
    }
}

// class for faking crossing geofences
@available(iOS 8.0, *)
class GeofenceFaker {
    let priority = DispatchQueue.GlobalQueuePriority.default
    let geoNotificationManager: GeoNotificationManager

    init(manager: GeoNotificationManager) {
        geoNotificationManager = manager
    }

    func start() {
        DispatchQueue.global(priority: priority).async {
            while (true) {
                log("FAKER")
                let notify = arc4random_uniform(4)
                if notify == 0 {
                    log("FAKER notify chosen, need to pick up some region")
                    let geos = self.geoNotificationManager.getWatchedGeoNotifications()
                    if !geos.isEmpty {
                        let index = Int(arc4random_uniform(UInt32(geos.count)))
                        let geo = geos[index]
                        
                        if let id = geo["id"] as? String {
                            DispatchQueue.main.async {
                                if let region = self.geoNotificationManager.getMonitoredRegion(id) {
                                    log("FAKER Trigger didEnterRegion")
                                    self.geoNotificationManager.locationManager(
                                        self.geoNotificationManager.locationManager,
                                        didEnterRegion: region
                                    )
                                }
                            }
                        } else {
                            log("❌ Couldn't extract 'id' from geo object")
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }

    func stop() {

    }
}

@available(iOS 8.0, *)
class GeoNotificationManager : NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    let store = GeoNotificationStore.shared

    // Debouncing: track last transition time for each region
    private var lastTransitionTimes: [String: Date] = [:]
    private let transitionDebounceInterval: TimeInterval = 5.0 // 5 seconds

    override init() {
        log("GeoNotificationManager init")
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest


        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("📁 Documents folder path: \(documentsPath.path)")
        }
    }

    func registerPermissions() {
        if iOS8 {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func addOrUpdateGeoNotification(_ geoNotification: JSON) {
        log(">>>>>>>> GeoNotificationManager addOrUpdate")

        let notificatioNId = geoNotification["id"].stringValue
        log("⚠️ Adding geofence with ID: \(notificatioNId)")
        
        let (_, warnings, errors) = checkRequirements()

        log(warnings)
        log(errors)

        let location = CLLocationCoordinate2DMake(
            geoNotification["latitude"].doubleValue,
            geoNotification["longitude"].doubleValue
        )
        log("AddOrUpdate geo: \(geoNotification)")
        let radius = geoNotification["radius"].doubleValue as CLLocationDistance
        let id = geoNotification["id"].stringValue

        let region = CLCircularRegion(center: location, radius: radius, identifier: id)

        var transitionType = 0
        if let i = geoNotification["transitionType"].int {
            transitionType = i
        }
        region.notifyOnEntry = 0 != transitionType & 1
        region.notifyOnExit = 0 != transitionType & 2

        //store
        store.addOrUpdate(geoNotification)
        locationManager.startMonitoring(for: region)
    }

    // TODO Make notification settings synchronous
    func checkRequirements() -> (Bool, [String], [String]) {
        var errors = [String]()
        var warnings = [String]()

        if (!CLLocationManager.isMonitoringAvailable(for: CLRegion.self)) {
            errors.append(">>>>>>>> Geofencing not available")
        }

        if (!CLLocationManager.locationServicesEnabled()) {
            errors.append(">>>>>>>> Error: Locationservices not enabled")
        }

        let authStatus = CLLocationManager.authorizationStatus()

        if (authStatus != CLAuthorizationStatus.authorizedAlways) {
            errors.append("Warning: Location always permissions not granted")
        }

        if (iOS8) {
            DispatchQueue.main.async { // Due to async, the return of checkRequirements is not ok
                if let notificationSettings = UIApplication.shared.currentUserNotificationSettings {
                    if notificationSettings.types == UIUserNotificationType() {
                        errors.append("Error: notification permission missing")
                    } else {
                        if !notificationSettings.types.contains(.sound) {
                            warnings.append("Warning: notification settings - sound permission missing")
                        }

                        if !notificationSettings.types.contains(.alert) {
                            warnings.append("Warning: notification settings - alert permission missing")
                        }

                        if !notificationSettings.types.contains(.badge) {
                            warnings.append("Warning: notification settings - badge permission missing")
                        }
                    }
                } else {
                    errors.append("Error: notification permission missing")
                }
            }
        }

        let ok = (errors.count == 0)

        return (ok, warnings, errors)
    }

    func getWatchedGeoNotifications() -> [[String: Any]] {
        return store.getAll()
    }

    func getMonitoredRegion(_ id: String) -> CLRegion? {
        for object in locationManager.monitoredRegions {
            let region = object

            if (region.identifier == id) {
                return region
            }
        }
        return nil
    }

    func removeGeoNotification(_ id: String) {
        store.remove(id)
        let region = getMonitoredRegion(id)
        if (region != nil) {
            log(">>>>>>>> Stoping monitoring region \(id)")
            locationManager.stopMonitoring(for: region!)
        }
    }

    func removeAllGeoNotifications() {
        store.clear()
        for object in locationManager.monitoredRegions {
            let region = object
            log(">>>>>>>> Stoping monitoring region \(region.identifier)")
            locationManager.stopMonitoring(for: region)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        log(">>>>>>>> update location")
        guard let newLocation = locations.last else { return }

        log(">>>>📍 Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("fail with error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        log(">>>>>>>> deferred fail error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        log(">>>>>>>> Entering region \(region.identifier)")
        log("⚠️ Total monitored regions: \(locationManager.monitoredRegions.count)")
        log("🔢 DEBUG: didEnterRegion called - Total monitored: \(locationManager.monitoredRegions.count)")
        log("📍 DEBUG: Monitored regions: \(locationManager.monitoredRegions.map { $0.identifier })")
        handleTransition(region, transitionType: 1)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        log("Exiting region \(region.identifier)")
        handleTransition(region, transitionType: 2)
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if region is CLCircularRegion {
            let lat = (region as! CLCircularRegion).center.latitude
            let lng = (region as! CLCircularRegion).center.longitude
            let radius = (region as! CLCircularRegion).radius

            log(">>>>>>>> Starting monitoring for region \(region) lat \(lat) lng \(lng) of radius \(radius)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        log(">>>>>>>> State for region " + region.identifier)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        log(">>>>>>>> Monitoring region " + region!.identifier + " failed \(error)" )
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var statusString: String
        switch status {
          case .notDetermined:
              statusString = "notDetermined"
          case .restricted:
              statusString = "restricted"
          case .denied:
              statusString = "denied"
          case .authorizedAlways:
              statusString = "authorizedAlways"
          case .authorizedWhenInUse:
              statusString = "authorizedWhenInUse"
          @unknown default:
              statusString = "unknown"
          }

          log("Location authorization changed to: \(statusString)")

          if status == .authorizedAlways || status == .authorizedWhenInUse {
              log("✅ Authorized, starting updates")
              locationManager.startUpdatingLocation()
          } else {
              log("❌ Not authorized: \(status.rawValue)")
          }
    }

    func handleTransition(_ region: CLRegion!, transitionType: Int) {
        // Debouncing: prevent duplicate transitions within short time
        let transitionKey = "\(region.identifier)_\(transitionType)"
        let now = Date()

        if let lastTime = lastTransitionTimes[transitionKey] {
            let timeSinceLastTransition = now.timeIntervalSince(lastTime)
            if timeSinceLastTransition < transitionDebounceInterval {
                log("⏭️ Skipping duplicate transition for \(region.identifier) (only \(timeSinceLastTransition)s since last)")
                return
            }
        }

        // Update last transition time
        lastTransitionTimes[transitionKey] = now

        if var geoNotification = store.findById(region.identifier) {
            geoNotification["transitionType"].int = transitionType

            // Log transition type
            let transitionTypeName = (transitionType == 1 ? "ENTER" : "EXIT")
            log("🚦 Transition Type: \(transitionTypeName) for region \(region.identifier)")

            // Check if has URL to post (API call)
            if geoNotification["url"].isExists() {
                log("Should post to " + geoNotification["url"].stringValue)
                let url = URL(string: geoNotification["url"].stringValue)!

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                let payload: [String: Any] = [
                                "geofenceId": geoNotification["id"].stringValue,
                                "transition": (geoNotification["transitionType"].intValue == 1 ? "ENTER" : "EXIT"),
                                "date": dateFormatter.string(from: Date()),
                                "userId": geoNotification["userId"].stringValue
                            ]
                let jsonData = try! JSONSerialization.data(withJSONObject: payload, options: [])

                // Log payload being sent
                if let payloadString = String(data: jsonData, encoding: .utf8) {
                    log("📤 Sending payload: \(payloadString)")
                }

                var request = URLRequest(url: url)
                request.httpMethod = "post"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(geoNotification["authorization"].stringValue, forHTTPHeaderField: "Authorization")
                request.httpBody = jsonData

                let task = URLSession.shared.dataTask(with: request) { _, response, error in
                    if let error = error {
                        print("❌ Network error:", error)
                        // Show error notification
                        if geoNotification["notification"].isExists() {
                            self.notifyAboutError(geoNotification)
                        }
                        return
                    }

                    guard let http = response as? HTTPURLResponse else {
                        print("⚠️ No HTTPURLResponse")
                        // Show error notification
                        if geoNotification["notification"].isExists() {
                            self.notifyAboutError(geoNotification)
                        }
                        return
                    }

                    if (200...299).contains(http.statusCode) {
                        // API Success - show normal notification
                        if let payloadString = String(data: jsonData, encoding: .utf8) {
                            print("✅ POST OK (\(http.statusCode)) - Payload: \(payloadString)")
                        } else {
                            print("✅ POST OK (\(http.statusCode))")
                        }

                        if geoNotification["notification"].isExists() {
                            self.notifyAbout(geoNotification)
                        }
                    } else {
                        // API Error - show error notification
                        print("⚠️ POST returned status \(http.statusCode)")
                        if geoNotification["notification"].isExists() {
                            self.notifyAboutError(geoNotification)
                        }
                    }
                }

                task.resume()
            } else {
                // No API call - show notification immediately
                if geoNotification["notification"].isExists() {
                    notifyAbout(geoNotification)
                }
            }
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: "handleTransition"), object: geoNotification.rawString(String.Encoding.utf8.rawValue, options: []))
        }
    }

    func notifyAbout(_ geo: JSON) {
        log("Creating notification")
        let notification = UILocalNotification()
        notification.timeZone = TimeZone.current
        let dateTime = Date()
        notification.fireDate = dateTime
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.alertBody = geo["notification"]["text"].stringValue
        if let json = geo["notification"]["data"] as JSON? {
            notification.userInfo = ["geofence.notification.data": json.rawString(String.Encoding.utf8.rawValue, options: [])!]
        }
        UIApplication.shared.scheduleLocalNotification(notification)

        if let vibrate = geo["notification"]["vibrate"].array {
            if (!vibrate.isEmpty && vibrate[0].intValue > 0) {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }

    func notifyAboutError(_ geo: JSON) {
        log("Creating error notification")
        let notification = UILocalNotification()
        notification.timeZone = TimeZone.current
        let dateTime = Date()
        notification.fireDate = dateTime
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.alertBody = geo["notification"]["errorMessage"].stringValue
        UIApplication.shared.scheduleLocalNotification(notification)

        if let vibrate = geo["notification"]["vibrate"].array {
            if (!vibrate.isEmpty && vibrate[0].intValue > 0) {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}

class GeoNotificationStore {
    static let shared = GeoNotificationStore()

    private var db: Connection!
    private let geoNotifications = Table("GeoNotifications")
    private let id = SQLite.Expression<String>("id")
    private let data = SQLite.Expression<String>("data")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/GeoNotifications.sqlite3")
            try db.run(geoNotifications.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(data)
            })
            print("✅ GeoNotifications database created or opened successfully")
        } catch {
            print("❌ Error setting up GeoNotifications database: \(error)")
        }
    }

    func addOrUpdate(_ geoNotification: JSON) {
        let geoId = geoNotification["id"].stringValue
        if findById(geoId) != nil {
            update(geoNotification)
        } else {
            add(geoNotification)
        }
    }

    func add(_ geoNotification: JSON) {
        let geoId = geoNotification["id"].stringValue
        
        guard let rawData = try? geoNotification.rawData(),
              let jsonString = String(data: rawData, encoding: .utf8) else {
            print("❌ Failed to serialize JSON for GeoNotification \(geoId)")
            return
        }
        
        do {
            print("💾 Will insert JSON:\n\(jsonString)")
            
            try db.run(geoNotifications.insert(
                id <- geoId,
                data <- jsonString
            ))

            print("✅ GeoNotification \(geoId) inserted successfully")
        } catch {
            print("❌ Error inserting GeoNotification \(geoId): \(error)")
        }
    }

    func update(_ geoNotification: JSON) {
        let geoId = geoNotification["id"].stringValue
        guard let rawData = try? geoNotification.rawData(),
              let jsonString = String(data: rawData, encoding: .utf8) else {
            print("❌ Failed to serialize JSON for GeoNotification \(geoId)")
            return
        }

        let item = geoNotifications.filter(id == geoId)
        do {
            try db.run(item.update(data <- jsonString))
            print("✅ GeoNotification \(geoId) updated")
        } catch {
            print("❌ Error updating GeoNotification \(geoId): \(error)")
        }
    }

    func findById(_ geoId: String) -> JSON? {
        let item = geoNotifications.filter(id == geoId)
        do {
            if let row = try db.pluck(item) {
                let jsonString = row[data]
                if let jsonData = jsonString.data(using: .utf8) {
                    return try JSON(data: jsonData)
                }
            }
        } catch {
            print("❌ Error fetching GeoNotification \(geoId): \(error)")
        }
        return nil
    }

    func getAll() -> [[String: Any]] {
        var results = [[String: Any]]()
        
        for row in try! db.prepare(geoNotifications) {
            let jsonString = row[data]
            print("📦 Fetched JSON string: \(jsonString)")

            if let jsonData = jsonString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let jsonDict = jsonObject as? [String: Any] {
                results.append(jsonDict)
            } else {
                print("❌ Couldn't deserialize json string")
            }
        }
        return results
    }

    func remove(_ geoId: String) {
        let item = geoNotifications.filter(id == geoId)
        do {
            try db.run(item.delete())
            print("✅ GeoNotification \(geoId) removed")
        } catch {
            print("❌ Error deleting GeoNotification \(geoId): \(error)")
        }
    }

    func clear() {
        do {
            try db.run(geoNotifications.delete())
            print("✅ All GeoNotifications deleted")
        } catch {
            print("❌ Error deleting all GeoNotifications: \(error)")
        }
    }
}