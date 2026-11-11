import SwiftUI
import CoreLocation
import MapKit
import UserNotifications
import ServiceManagement

// MARK: - Prayer time calculation (Kemenag RI: Fajr 20°, Isya 18°, Ashar Syafi'i, +2 min ihtiyat)

struct City: Hashable { let name: String; let lat: Double; let lng: Double; let tz: String; var country = "" }

enum Prayer: String, CaseIterable {
    case shubuh = "Fajr", dhuhur = "Dhuhr", ashar = "Asr", maghrib = "Maghrib", isya = "Isha"
    var icon: String {
        switch self {
        case .shubuh: "sunrise"
        case .dhuhur: "sun.max"
        case .ashar: "sun.min"
        case .maghrib: "sunset"
        case .isya: "moon.stars"
        }
    }
}

func prayerTimes(lat: Double, lng: Double, tz: TimeZone, day: Date) -> [(Prayer, Date)] {
    let rad = Double.pi / 180
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    let c = cal.dateComponents([.year, .month, .day], from: day)
    var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
    let midnightUTC = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
    let jd = midnightUTC.timeIntervalSince1970 / 86400 + 2440587.5

    // Sun position at local noon
    let d = jd + 0.5 - lng / 360 - 2451545.0
    let g = (357.529 + 0.98560028 * d) * rad
    let q = 280.459 + 0.98564736 * d
    let L = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad
    let e = (23.439 - 0.00000036 * d) * rad
    var ra = atan2(cos(e) * sin(L), cos(L)) / rad / 15
    ra = (ra + 24).truncatingRemainder(dividingBy: 24)
    var eqt = q / 15 - ra
    eqt -= 24 * (eqt / 24).rounded()
    let decl = asin(sin(e) * sin(L))
    let phi = lat * rad

    let noon = 12 - lng / 15 - eqt  // UTC hours
    func hourAngle(_ altitude: Double) -> Double {
        acos((sin(altitude * rad) - sin(phi) * sin(decl)) / (cos(phi) * cos(decl))) / rad / 15
    }
    let asrAlt = atan(1 / (1 + tan(abs(phi - decl)))) / rad
    let sunrise = noon - hourAngle(-0.833), sunset = noon + hourAngle(-0.833)
    // High latitudes: sun may never reach -20°/-18° → angle-based fallback (portion of the night)
    let night = 24 - (sunset - sunrise)
    var fajr = noon - hourAngle(-20), isha = noon + hourAngle(-18)
    if fajr.isNaN || sunrise - fajr > night * 20 / 60 { fajr = sunrise - night * 20 / 60 }
    if isha.isNaN || isha - sunset > night * 18 / 60 { isha = sunset + night * 18 / 60 }
    let hours: [(Prayer, Double)] = [
        (.shubuh, fajr),
        (.dhuhur, noon),
        (.ashar, noon + hourAngle(asrAlt)),
        (.maghrib, sunset),
        (.isya, isha),
    ]
    return hours.map { ($0.0, midnightUTC.addingTimeInterval(($0.1 + 2.0 / 60) * 3600)) }
}

// MARK: - Cities

let cities: [City] = ([
    ("Banda Aceh", "Indonesia", 5.55, 95.32, "Asia/Jakarta"), ("Medan", "Indonesia", 3.59, 98.67, "Asia/Jakarta"),
    ("Padang", "Indonesia", -0.95, 100.35, "Asia/Jakarta"), ("Pekanbaru", "Indonesia", 0.51, 101.45, "Asia/Jakarta"),
    ("Batam", "Indonesia", 1.13, 104.05, "Asia/Jakarta"), ("Tanjung Pinang", "Indonesia", 0.92, 104.45, "Asia/Jakarta"),
    ("Jambi", "Indonesia", -1.61, 103.61, "Asia/Jakarta"), ("Palembang", "Indonesia", -2.99, 104.76, "Asia/Jakarta"),
    ("Bengkulu", "Indonesia", -3.8, 102.27, "Asia/Jakarta"), ("Pangkal Pinang", "Indonesia", -2.13, 106.11, "Asia/Jakarta"),
    ("Bandar Lampung", "Indonesia", -5.43, 105.26, "Asia/Jakarta"), ("Serang", "Indonesia", -6.12, 106.15, "Asia/Jakarta"),
    ("Tangerang", "Indonesia", -6.18, 106.63, "Asia/Jakarta"), ("Jakarta", "Indonesia", -6.21, 106.85, "Asia/Jakarta"),
    ("Depok", "Indonesia", -6.4, 106.82, "Asia/Jakarta"), ("Bekasi", "Indonesia", -6.24, 107.0, "Asia/Jakarta"),
    ("Bogor", "Indonesia", -6.6, 106.8, "Asia/Jakarta"), ("Bandung", "Indonesia", -6.91, 107.61, "Asia/Jakarta"),
    ("Cirebon", "Indonesia", -6.73, 108.55, "Asia/Jakarta"), ("Tasikmalaya", "Indonesia", -7.33, 108.22, "Asia/Jakarta"),
    ("Semarang", "Indonesia", -6.97, 110.42, "Asia/Jakarta"), ("Solo", "Indonesia", -7.57, 110.82, "Asia/Jakarta"),
    ("Yogyakarta", "Indonesia", -7.8, 110.36, "Asia/Jakarta"), ("Purwokerto", "Indonesia", -7.42, 109.23, "Asia/Jakarta"),
    ("Surabaya", "Indonesia", -7.25, 112.75, "Asia/Jakarta"), ("Malang", "Indonesia", -7.98, 112.63, "Asia/Jakarta"),
    ("Kediri", "Indonesia", -7.82, 112.01, "Asia/Jakarta"), ("Jember", "Indonesia", -8.17, 113.7, "Asia/Jakarta"),
    ("Pontianak", "Indonesia", -0.03, 109.33, "Asia/Pontianak"), ("Palangka Raya", "Indonesia", -2.21, 113.92, "Asia/Pontianak"),
    ("Denpasar", "Indonesia", -8.65, 115.22, "Asia/Makassar"), ("Mataram", "Indonesia", -8.58, 116.12, "Asia/Makassar"),
    ("Kupang", "Indonesia", -10.18, 123.61, "Asia/Makassar"), ("Banjarmasin", "Indonesia", -3.32, 114.59, "Asia/Makassar"),
    ("Balikpapan", "Indonesia", -1.27, 116.83, "Asia/Makassar"), ("Samarinda", "Indonesia", -0.5, 117.15, "Asia/Makassar"),
    ("Tanjung Selor", "Indonesia", 2.84, 117.37, "Asia/Makassar"), ("Makassar", "Indonesia", -5.15, 119.43, "Asia/Makassar"),
    ("Palu", "Indonesia", -0.9, 119.87, "Asia/Makassar"), ("Kendari", "Indonesia", -3.97, 122.51, "Asia/Makassar"),
    ("Gorontalo", "Indonesia", 0.54, 123.06, "Asia/Makassar"), ("Manado", "Indonesia", 1.47, 124.84, "Asia/Makassar"),
    ("Mamuju", "Indonesia", -2.68, 118.89, "Asia/Makassar"), ("Ambon", "Indonesia", -3.7, 128.18, "Asia/Jayapura"),
    ("Ternate", "Indonesia", 0.79, 127.38, "Asia/Jayapura"), ("Sorong", "Indonesia", -0.88, 131.26, "Asia/Jayapura"),
    ("Manokwari", "Indonesia", -0.86, 134.06, "Asia/Jayapura"), ("Jayapura", "Indonesia", -2.53, 140.72, "Asia/Jayapura"),
    ("Merauke", "Indonesia", -8.49, 140.4, "Asia/Jayapura"), ("Kuala Lumpur", "Malaysia", 3.14, 101.69, "Asia/Kuala_Lumpur"),
    ("Johor Bahru", "Malaysia", 1.49, 103.74, "Asia/Kuala_Lumpur"), ("George Town", "Malaysia", 5.41, 100.33, "Asia/Kuala_Lumpur"),
    ("Kota Kinabalu", "Malaysia", 5.98, 116.07, "Asia/Kuching"), ("Kuching", "Malaysia", 1.55, 110.34, "Asia/Kuching"),
    ("Singapore", "Singapore", 1.35, 103.82, "Asia/Singapore"), ("Bandar Seri Begawan", "Brunei", 4.9, 114.94, "Asia/Brunei"),
    ("Bangkok", "Thailand", 13.76, 100.5, "Asia/Bangkok"), ("Pattani", "Thailand", 6.87, 101.25, "Asia/Bangkok"),
    ("Manila", "Philippines", 14.6, 120.98, "Asia/Manila"), ("Davao", "Philippines", 7.19, 125.46, "Asia/Manila"),
    ("Ho Chi Minh City", "Vietnam", 10.82, 106.63, "Asia/Ho_Chi_Minh"), ("Hanoi", "Vietnam", 21.03, 105.85, "Asia/Ho_Chi_Minh"),
    ("Phnom Penh", "Cambodia", 11.56, 104.92, "Asia/Phnom_Penh"), ("Yangon", "Myanmar", 16.84, 96.17, "Asia/Yangon"),
    ("Dhaka", "Bangladesh", 23.81, 90.41, "Asia/Dhaka"), ("Chittagong", "Bangladesh", 22.36, 91.78, "Asia/Dhaka"),
    ("New Delhi", "India", 28.61, 77.21, "Asia/Kolkata"), ("Mumbai", "India", 19.08, 72.88, "Asia/Kolkata"),
    ("Hyderabad", "India", 17.39, 78.49, "Asia/Kolkata"), ("Kolkata", "India", 22.57, 88.36, "Asia/Kolkata"),
    ("Bengaluru", "India", 12.97, 77.59, "Asia/Kolkata"), ("Chennai", "India", 13.08, 80.27, "Asia/Kolkata"),
    ("Srinagar", "India", 34.08, 74.8, "Asia/Kolkata"), ("Karachi", "Pakistan", 24.86, 67.01, "Asia/Karachi"),
    ("Lahore", "Pakistan", 31.55, 74.34, "Asia/Karachi"), ("Islamabad", "Pakistan", 33.68, 73.05, "Asia/Karachi"),
    ("Peshawar", "Pakistan", 34.01, 71.58, "Asia/Karachi"), ("Kabul", "Afghanistan", 34.56, 69.21, "Asia/Kabul"),
    ("Colombo", "Sri Lanka", 6.93, 79.86, "Asia/Colombo"), ("Malé", "Maldives", 4.18, 73.51, "Indian/Maldives"),
    ("Kathmandu", "Nepal", 27.72, 85.32, "Asia/Kathmandu"), ("Tashkent", "Uzbekistan", 41.3, 69.24, "Asia/Tashkent"),
    ("Samarkand", "Uzbekistan", 39.65, 66.96, "Asia/Samarkand"), ("Almaty", "Kazakhstan", 43.24, 76.89, "Asia/Almaty"),
    ("Astana", "Kazakhstan", 51.17, 71.45, "Asia/Almaty"), ("Bishkek", "Kyrgyzstan", 42.87, 74.59, "Asia/Bishkek"),
    ("Dushanbe", "Tajikistan", 38.56, 68.77, "Asia/Dushanbe"), ("Ashgabat", "Turkmenistan", 37.96, 58.33, "Asia/Ashgabat"),
    ("Baku", "Azerbaijan", 40.41, 49.87, "Asia/Baku"), ("Beijing", "China", 39.9, 116.41, "Asia/Shanghai"),
    ("Shanghai", "China", 31.23, 121.47, "Asia/Shanghai"), ("Guangzhou", "China", 23.13, 113.26, "Asia/Shanghai"),
    ("Urumqi", "China", 43.83, 87.62, "Asia/Shanghai"), ("Hong Kong", "China", 22.32, 114.17, "Asia/Hong_Kong"),
    ("Taipei", "Taiwan", 25.03, 121.57, "Asia/Taipei"), ("Tokyo", "Japan", 35.68, 139.69, "Asia/Tokyo"),
    ("Osaka", "Japan", 34.69, 135.5, "Asia/Tokyo"), ("Seoul", "South Korea", 37.57, 126.98, "Asia/Seoul"),
    ("Makkah", "Saudi Arabia", 21.42, 39.83, "Asia/Riyadh"), ("Madinah", "Saudi Arabia", 24.47, 39.61, "Asia/Riyadh"),
    ("Riyadh", "Saudi Arabia", 24.71, 46.68, "Asia/Riyadh"), ("Jeddah", "Saudi Arabia", 21.49, 39.19, "Asia/Riyadh"),
    ("Dammam", "Saudi Arabia", 26.43, 50.1, "Asia/Riyadh"), ("Dubai", "United Arab Emirates", 25.2, 55.27, "Asia/Dubai"),
    ("Abu Dhabi", "United Arab Emirates", 24.45, 54.38, "Asia/Dubai"), ("Sharjah", "United Arab Emirates", 25.35, 55.42, "Asia/Dubai"),
    ("Doha", "Qatar", 25.29, 51.53, "Asia/Qatar"), ("Manama", "Bahrain", 26.23, 50.59, "Asia/Bahrain"),
    ("Kuwait City", "Kuwait", 29.38, 47.99, "Asia/Kuwait"), ("Muscat", "Oman", 23.59, 58.41, "Asia/Muscat"),
    ("Sanaa", "Yemen", 15.37, 44.19, "Asia/Aden"), ("Aden", "Yemen", 12.79, 45.02, "Asia/Aden"),
    ("Amman", "Jordan", 31.95, 35.93, "Asia/Amman"), ("Jerusalem", "Palestine", 31.78, 35.23, "Asia/Jerusalem"),
    ("Gaza", "Palestine", 31.5, 34.47, "Asia/Gaza"), ("Beirut", "Lebanon", 33.89, 35.5, "Asia/Beirut"),
    ("Damascus", "Syria", 33.51, 36.28, "Asia/Damascus"), ("Aleppo", "Syria", 36.2, 37.13, "Asia/Damascus"),
    ("Baghdad", "Iraq", 33.31, 44.36, "Asia/Baghdad"), ("Erbil", "Iraq", 36.19, 44.01, "Asia/Baghdad"),
    ("Tehran", "Iran", 35.69, 51.39, "Asia/Tehran"), ("Mashhad", "Iran", 36.3, 59.61, "Asia/Tehran"),
    ("Istanbul", "Türkiye", 41.01, 28.98, "Europe/Istanbul"), ("Ankara", "Türkiye", 39.93, 32.86, "Europe/Istanbul"),
    ("Cairo", "Egypt", 30.04, 31.24, "Africa/Cairo"), ("Alexandria", "Egypt", 31.2, 29.92, "Africa/Cairo"),
    ("Khartoum", "Sudan", 15.5, 32.56, "Africa/Khartoum"), ("Tripoli", "Libya", 32.89, 13.19, "Africa/Tripoli"),
    ("Tunis", "Tunisia", 36.81, 10.18, "Africa/Tunis"), ("Algiers", "Algeria", 36.75, 3.06, "Africa/Algiers"),
    ("Casablanca", "Morocco", 33.57, -7.59, "Africa/Casablanca"), ("Rabat", "Morocco", 34.02, -6.84, "Africa/Casablanca"),
    ("Marrakesh", "Morocco", 31.63, -8.01, "Africa/Casablanca"), ("Nouakchott", "Mauritania", 18.09, -15.98, "Africa/Nouakchott"),
    ("Dakar", "Senegal", 14.72, -17.47, "Africa/Dakar"), ("Bamako", "Mali", 12.64, -8.0, "Africa/Bamako"),
    ("Niamey", "Niger", 13.51, 2.11, "Africa/Niamey"), ("Lagos", "Nigeria", 6.52, 3.38, "Africa/Lagos"),
    ("Abuja", "Nigeria", 9.08, 7.4, "Africa/Lagos"), ("Kano", "Nigeria", 12.0, 8.59, "Africa/Lagos"),
    ("Accra", "Ghana", 5.6, -0.19, "Africa/Accra"), ("Addis Ababa", "Ethiopia", 9.03, 38.74, "Africa/Addis_Ababa"),
    ("Mogadishu", "Somalia", 2.05, 45.32, "Africa/Mogadishu"), ("Djibouti", "Djibouti", 11.59, 43.15, "Africa/Djibouti"),
    ("Nairobi", "Kenya", -1.29, 36.82, "Africa/Nairobi"), ("Mombasa", "Kenya", -4.04, 39.67, "Africa/Nairobi"),
    ("Dar es Salaam", "Tanzania", -6.79, 39.21, "Africa/Dar_es_Salaam"), ("Zanzibar", "Tanzania", -6.17, 39.2, "Africa/Dar_es_Salaam"),
    ("Johannesburg", "South Africa", -26.2, 28.05, "Africa/Johannesburg"), ("Cape Town", "South Africa", -33.92, 18.42, "Africa/Johannesburg"),
    ("London", "United Kingdom", 51.51, -0.13, "Europe/London"), ("Birmingham", "United Kingdom", 52.49, -1.89, "Europe/London"),
    ("Manchester", "United Kingdom", 53.48, -2.24, "Europe/London"), ("Dublin", "Ireland", 53.35, -6.26, "Europe/Dublin"),
    ("Paris", "France", 48.86, 2.35, "Europe/Paris"), ("Marseille", "France", 43.3, 5.37, "Europe/Paris"),
    ("Brussels", "Belgium", 50.85, 4.35, "Europe/Brussels"), ("Amsterdam", "Netherlands", 52.37, 4.9, "Europe/Amsterdam"),
    ("Rotterdam", "Netherlands", 51.92, 4.48, "Europe/Amsterdam"), ("Berlin", "Germany", 52.52, 13.4, "Europe/Berlin"),
    ("Frankfurt", "Germany", 50.11, 8.68, "Europe/Berlin"), ("Munich", "Germany", 48.14, 11.58, "Europe/Berlin"),
    ("Zurich", "Switzerland", 47.38, 8.54, "Europe/Zurich"), ("Vienna", "Austria", 48.21, 16.37, "Europe/Vienna"),
    ("Madrid", "Spain", 40.42, -3.7, "Europe/Madrid"), ("Barcelona", "Spain", 41.39, 2.17, "Europe/Madrid"),
    ("Lisbon", "Portugal", 38.72, -9.14, "Europe/Lisbon"), ("Rome", "Italy", 41.9, 12.5, "Europe/Rome"),
    ("Milan", "Italy", 45.46, 9.19, "Europe/Rome"), ("Athens", "Greece", 37.98, 23.73, "Europe/Athens"),
    ("Sarajevo", "Bosnia and Herzegovina", 43.86, 18.41, "Europe/Sarajevo"), ("Tirana", "Albania", 41.33, 19.82, "Europe/Tirane"),
    ("Pristina", "Kosovo", 42.66, 21.17, "Europe/Belgrade"), ("Warsaw", "Poland", 52.23, 21.01, "Europe/Warsaw"),
    ("Copenhagen", "Denmark", 55.68, 12.57, "Europe/Copenhagen"), ("Stockholm", "Sweden", 59.33, 18.07, "Europe/Stockholm"),
    ("Oslo", "Norway", 59.91, 10.75, "Europe/Oslo"), ("Helsinki", "Finland", 60.17, 24.94, "Europe/Helsinki"),
    ("Moscow", "Russia", 55.76, 37.62, "Europe/Moscow"), ("Kazan", "Russia", 55.8, 49.11, "Europe/Moscow"),
    ("Grozny", "Russia", 43.32, 45.69, "Europe/Moscow"), ("New York", "United States", 40.71, -74.01, "America/New_York"),
    ("Washington, D.C.", "United States", 38.91, -77.04, "America/New_York"), ("Detroit", "United States", 42.33, -83.05, "America/Detroit"),
    ("Chicago", "United States", 41.88, -87.63, "America/Chicago"), ("Houston", "United States", 29.76, -95.37, "America/Chicago"),
    ("Dallas", "United States", 32.78, -96.8, "America/Chicago"), ("Los Angeles", "United States", 34.05, -118.24, "America/Los_Angeles"),
    ("San Francisco", "United States", 37.77, -122.42, "America/Los_Angeles"), ("Seattle", "United States", 47.61, -122.33, "America/Los_Angeles"),
    ("Toronto", "Canada", 43.65, -79.38, "America/Toronto"), ("Montreal", "Canada", 45.5, -73.57, "America/Toronto"),
    ("Vancouver", "Canada", 49.28, -123.12, "America/Vancouver"), ("Mexico City", "Mexico", 19.43, -99.13, "America/Mexico_City"),
    ("São Paulo", "Brazil", -23.55, -46.63, "America/Sao_Paulo"), ("Buenos Aires", "Argentina", -34.6, -58.38, "America/Argentina/Buenos_Aires"),
    ("Sydney", "Australia", -33.87, 151.21, "Australia/Sydney"), ("Melbourne", "Australia", -37.81, 144.96, "Australia/Melbourne"),
    ("Brisbane", "Australia", -27.47, 153.03, "Australia/Brisbane"), ("Perth", "Australia", -31.95, 115.86, "Australia/Perth"),
    ("Auckland", "New Zealand", -36.85, 174.76, "Pacific/Auckland"),
] as [(String, String, Double, Double, String)])
    .map { City(name: $0.0, lat: $0.2, lng: $0.3, tz: $0.4, country: $0.1) }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

// MARK: - State

enum Option: Hashable {
    case auto, city(City), remote(MKLocalSearchCompletion)
}

@MainActor
final class Model: NSObject, ObservableObject, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate, UNUserNotificationCenterDelegate {
    @AppStorage("savedCity") var savedCity = ""  // "" = auto, else "name|lat|lng|tz"
    @Published var location = City(name: "Locating…", lat: -6.21, lng: 106.85, tz: TimeZone.current.identifier) {
        didSet { scheduleNotifications() }
    }
    @Published var notify = UserDefaults.standard.object(forKey: "notify") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notify, forKey: "notify"); scheduleNotifications() }
    }
    @Published var openAtLogin = SMAppService.mainApp.status == .enabled
    @Published var now = Date()
    @Published var picking = false
    @Published var query = "" { didSet { completer.queryFragment = query; highlighted = 0; resolveFailed = false } }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var highlighted = 0
    @Published var locationDenied = false
    @Published var notificationsDenied = false
    @Published var loginNeedsApproval = false
    @Published var searchOffline = false
    @Published var resolving: MKLocalSearchCompletion?
    @Published var resolveFailed = false
    private var scheduledDay = 0
    private let lm = CLLocationManager()
    private let completer = MKLocalSearchCompleter()
    private var timer: Timer?

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyKilometer
        completer.delegate = self
        completer.resultTypes = .address
        startMinuteTimer()
        // Wake from sleep, clock or time zone change → refresh immediately
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in self.startMinuteTimer(); self.tick(forceLocation: true) }
        }
        for n in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { _ in
                Task { @MainActor in self.startMinuteTimer(); self.tick(forceLocation: true) }
            }
        }
        // Panel opens → app activates: re-check permissions the user may have changed in Settings.
        // Panel closes → app resigns: drop the half-finished city search so it reopens on the times.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in self.refreshPermissions() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in self.picking = false; self.query = "" }
        }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in self.refreshPermissions() }
        }
        apply()
    }

    /// Fires on each minute boundary so the menu bar flips right when a prayer starts.
    private func startMinuteTimer() {
        timer?.invalidate()
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0), matchingPolicy: .nextTime) ?? Date()
        let t = Timer(fire: next, interval: 60, repeats: true) { _ in Task { @MainActor in self.tick() } }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick(forceLocation: Bool = false) {
        now = Date()
        refreshPermissions()
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        if day != scheduledDay || forceLocation {
            scheduleNotifications()
            if isAuto { lm.requestLocation() }
        }
    }

    func refreshPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let denied = s.authorizationStatus == .denied
            Task { @MainActor in if self.notificationsDenied != denied { self.notificationsDenied = denied } }
        }
        let st = lm.authorizationStatus
        let login = SMAppService.mainApp.status
        if locationDenied != (isAuto && (st == .denied || st == .restricted)) { locationDenied.toggle() }
        if openAtLogin != (login == .enabled) { openAtLogin.toggle() }
        if loginNeedsApproval != (login == .requiresApproval) { loginNeedsApproval.toggle() }
    }

    func setOpenAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        openAtLogin = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        scheduledDay = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        guard notify else { return }
        let upcoming = (today + prayerTimes(lat: location.lat, lng: location.lng, tz: tz, day: Date().addingTimeInterval(86400)))
            .filter { $0.1 > Date() }
        for (p, d) in upcoming {
            let c = UNMutableNotificationContent()
            c.title = "Time for \(p.rawValue)"
            c.body = "\(p.rawValue) \(fmt(d)) · \(location.name)"
            c.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: d.timeIntervalSinceNow, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(p.rawValue)-\(Int(d.timeIntervalSince1970))", content: c, trigger: trigger))
        }
    }

    // Show banner even while the menu panel is open
    nonisolated func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    var isAuto: Bool { savedCity.isEmpty }

    var options: [Option] {
        let matches = query.isEmpty ? cities : cities.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.country.localizedCaseInsensitiveContains(query) }
        let known = Set(matches.map(\.name))
        let remote = results.filter { !known.contains($0.title) }  // skip online duplicates of built-in cities
        return (query.isEmpty ? [.auto] : []) + matches.map(Option.city) + remote.map(Option.remote)
    }

    func choose(_ o: Option) {
        switch o {
        case .auto: select(nil)
        case .city(let c): select(c)
        case .remote(let r): select(r); return  // closes itself once the city resolves
        }
        picking = false
        query = ""
    }

    func moveHighlight(_ delta: Int) {
        highlighted = max(0, min(options.count - 1, highlighted + delta))
    }

    func select(_ city: City?) {
        savedCity = city.map { "\($0.name)|\($0.lat)|\($0.lng)|\($0.tz)" } ?? ""
        apply()
    }

    func select(_ c: MKLocalSearchCompletion) {
        resolving = c
        resolveFailed = false
        MKLocalSearch(request: MKLocalSearch.Request(completion: c)).start { res, _ in
            let item = res?.mapItems.first
            let co = item?.placemark.coordinate
            let tz = item?.timeZone
            Task { @MainActor in
                self.resolving = nil
                guard let co else { self.resolveFailed = true; return }
                self.select(City(name: c.title, lat: co.latitude, lng: co.longitude, tz: (tz ?? .current).identifier))
                self.picking = false
                self.query = ""
            }
        }
    }

    private func apply() {
        let f = savedCity.split(separator: "|").map(String.init)
        if f.count == 4, let lat = Double(f[1]), let lng = Double(f[2]) {
            lm.stopMonitoringSignificantLocationChanges()
            location = City(name: f[0], lat: lat, lng: lng, tz: f[3])
        } else {
            lm.requestWhenInUseAuthorization()
            lm.requestLocation()
            // Travelling with a laptop → follow the user to the next city
            lm.startMonitoringSignificantLocationChanges()
        }
        refreshPermissions()
    }

    var tz: TimeZone { TimeZone(identifier: location.tz) ?? .current }
    var today: [(Prayer, Date)] { prayerTimes(lat: location.lat, lng: location.lng, tz: tz, day: now) }

    var next: (Prayer, Date) {
        today.first { $0.1 > now }
            ?? prayerTimes(lat: location.lat, lng: location.lng, tz: tz, day: now.addingTimeInterval(86400))[0]
    }

    /// Honors the system 12/24-hour setting, shown in the selected city's time zone.
    func fmt(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .autoupdatingCurrent, timeZone: tz))
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in
            guard self.isAuto else { return }
            self.locationDenied = false
            if self.location.name == "Locating…" || self.location.name.hasPrefix("Jakarta (") {
                self.location = City(name: "Current location", lat: loc.coordinate.latitude,
                                     lng: loc.coordinate.longitude, tz: TimeZone.current.identifier)
            }
            if let p = try? await CLGeocoder().reverseGeocodeLocation(loc).first, let name = p.locality ?? p.administrativeArea {
                self.location = City(name: name, lat: loc.coordinate.latitude,
                                     lng: loc.coordinate.longitude, tz: (p.timeZone ?? .current).identifier)
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Keep the last known city; only fall back when we never had one
            if self.isAuto && self.location.name == "Locating…" {
                self.location = City(name: "Jakarta (default)", lat: -6.21, lng: 106.85, tz: "Asia/Jakarta")
            }
            self.refreshPermissions()
        }
    }

    nonisolated func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        let r = c.results
        Task { @MainActor in self.searchOffline = false; self.results = self.query.isEmpty ? [] : Array(r.prefix(15)) }
    }

    nonisolated func completer(_ c: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = []; self.searchOffline = true }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Task { @MainActor in
            if self.isAuto { self.lm.requestLocation() }
            self.refreshPermissions()
        }
    }
}

// MARK: - UI

func openSettings(_ pane: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:\(pane)")!)
}

struct Panel: View {
    @ObservedObject var model: Model
    @AppStorage("showIcon") var showIcon = true
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { model.picking.toggle(); model.query = "" } label: {
                HStack {
                    Text("Location:").foregroundStyle(.secondary)
                    Image(systemName: model.isAuto ? "location.fill" : "mappin").font(.caption)
                    Text(model.location.name).lineLimit(1).truncationMode(.tail)
                    Spacer()
                    Image(systemName: model.picking ? "chevron.up" : "chevron.down").font(.caption)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.location.name)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Location, \(model.location.name)")
            .accessibilityValue(model.picking ? "Expanded" : "Collapsed")
            .accessibilityHint("Choose a city or automatic location")
            .accessibilityAddTraits(.isButton)

            if model.locationDenied {
                warning("Location access is off. Using \(model.location.name).",
                        link: "Open Location Settings", pane: "com.apple.preference.security?Privacy_LocationServices")
            }

            if model.picking { picker } else { times }

            if model.loginNeedsApproval {
                warning("Allow Prayer Times to open at login.",
                        link: "Open Login Items Settings", pane: "com.apple.LoginItems-Settings.extension")
            }

            if model.notify && model.notificationsDenied {
                warning("Notifications are blocked for Prayer Times.",
                        link: "Open Notification Settings", pane: "com.apple.preference.notifications")
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show icon in menu bar", isOn: $showIcon)
                Toggle("Notify at prayer times", isOn: $model.notify)
                Toggle("Open at login", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
            }.toggleStyle(.checkbox).font(.callout)
            HStack {
                Text(model.now, format: .dateTime.weekday(.wide).day().month(.wide)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    .keyboardShortcut("q")
                    .padding(.vertical, 4).padding(.leading, 12).contentShape(Rectangle())
            }
        }
        .padding(16)
        .frame(width: 270)
        .environment(\.locale, Locale(identifier: "en_US"))
        .onAppear { model.refreshPermissions() }
    }

    func warning(_ text: String, link: String? = nil, pane: String = "") -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).fixedSize(horizontal: false, vertical: true)
                if let link { Button(link) { openSettings(pane) }.buttonStyle(.link) }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var times: some View {
        let next = model.next.0
        return VStack(spacing: 6) {
            ForEach(model.today, id: \.0) { p, d in
                let time = model.fmt(d)
                HStack {
                    Image(systemName: p.icon).frame(width: 20)
                    Text(p.rawValue).font(.title3)
                    Spacer()
                    Text(time).font(.title2.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(p == next ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(p.rawValue), \(time)")
                .accessibilityValue(p == next ? "Next prayer" : "")
            }
        }
    }

    var picker: some View {
        let options = model.options
        return VStack(spacing: 6) {
            TextField("Search city or country…", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if options.indices.contains(model.highlighted) { model.choose(options[model.highlighted]) } }
                .onKeyPress(.downArrow) { model.moveHighlight(1); return .handled }
                .onKeyPress(.upArrow) { model.moveHighlight(-1); return .handled }
                .accessibilityHint("Type to filter. Arrow keys move, Return selects.")
                .focused($searchFocused)
                .onAppear { DispatchQueue.main.async { searchFocused = true } }
            if model.resolveFailed {
                warning("Couldn't load that city. Check your connection and try again.")
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.element) { i, o in
                            row(o, highlighted: i == model.highlighted).id(i)
                                .onHover { if $0 { model.highlighted = i } }
                        }
                        if options.isEmpty {
                            Text(model.searchOffline ? "No matches. Searching worldwide needs an internet connection."
                                                     : "No matching cities")
                                .font(.callout).foregroundStyle(.secondary).padding(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .onChange(of: model.highlighted) { proxy.scrollTo(model.highlighted) }
            }.frame(height: 220)
        }
    }

    func row(_ o: Option, highlighted: Bool) -> some View {
        let (title, subtitle, icon, selected): (String, String, String, Bool) = switch o {
        case .auto: ("Automatic (GPS)", "", "location.fill", model.isAuto)
        case .city(let c): (c.name, c.country, "mappin", !model.isAuto && model.location.name == c.name)
        case .remote(let r): (r.title, r.subtitle, "globe", false)
        }
        return Button { model.choose(o) } label: {
            HStack {
                Image(systemName: icon).font(.caption).frame(width: 16)
                Text(title).lineLimit(1).layoutPriority(1)
                Text(subtitle).lineLimit(1).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if case .remote(let r) = o, model.resolving == r { ProgressView().controlSize(.small) }
                if selected { Image(systemName: "checkmark").font(.caption) }
            }
            .padding(.vertical, 5).padding(.horizontal, 6)
            .background(highlighted ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(subtitle.isEmpty ? title : "\(title), \(subtitle)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.isEmpty ? title : "\(title), \(subtitle)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

@main
struct PrayerTimesApp: App {
    @StateObject private var model = Model()
    @AppStorage("showIcon") var showIcon = true

    var body: some Scene {
        MenuBarExtra {
            Panel(model: model)
        } label: {
            let (p, d) = model.next
            if showIcon { Image(systemName: p.icon) }
            Text("\(p.rawValue) \(model.fmt(d))")
        }
        .menuBarExtraStyle(.window)
    }
}
