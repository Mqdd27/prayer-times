import SwiftUI
import CoreLocation
import MapKit
import UserNotifications
import ServiceManagement

// MARK: - Prayer time calculation (Kemenag RI: Fajr 20°, Isya 18°, Ashar Syafi'i, +2 min ihtiyat)

struct City: Hashable { let name: String; let lat: Double; let lng: Double; let tz: String }

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

let cities: [City] = [
    ("Banda Aceh", 5.55, 95.32, "Asia/Jakarta"), ("Medan", 3.59, 98.67, "Asia/Jakarta"),
    ("Padang", -0.95, 100.35, "Asia/Jakarta"), ("Pekanbaru", 0.51, 101.45, "Asia/Jakarta"),
    ("Batam", 1.13, 104.05, "Asia/Jakarta"), ("Tanjung Pinang", 0.92, 104.45, "Asia/Jakarta"),
    ("Jambi", -1.61, 103.61, "Asia/Jakarta"), ("Palembang", -2.99, 104.76, "Asia/Jakarta"),
    ("Bengkulu", -3.80, 102.27, "Asia/Jakarta"), ("Pangkal Pinang", -2.13, 106.11, "Asia/Jakarta"),
    ("Bandar Lampung", -5.43, 105.26, "Asia/Jakarta"), ("Serang", -6.12, 106.15, "Asia/Jakarta"),
    ("Tangerang", -6.18, 106.63, "Asia/Jakarta"), ("Jakarta", -6.21, 106.85, "Asia/Jakarta"),
    ("Depok", -6.40, 106.82, "Asia/Jakarta"), ("Bekasi", -6.24, 107.00, "Asia/Jakarta"),
    ("Bogor", -6.60, 106.80, "Asia/Jakarta"), ("Bandung", -6.91, 107.61, "Asia/Jakarta"),
    ("Cirebon", -6.73, 108.55, "Asia/Jakarta"), ("Tasikmalaya", -7.33, 108.22, "Asia/Jakarta"),
    ("Semarang", -6.97, 110.42, "Asia/Jakarta"), ("Solo", -7.57, 110.82, "Asia/Jakarta"),
    ("Yogyakarta", -7.80, 110.36, "Asia/Jakarta"), ("Purwokerto", -7.42, 109.23, "Asia/Jakarta"),
    ("Surabaya", -7.25, 112.75, "Asia/Jakarta"), ("Malang", -7.98, 112.63, "Asia/Jakarta"),
    ("Kediri", -7.82, 112.01, "Asia/Jakarta"), ("Jember", -8.17, 113.70, "Asia/Jakarta"),
    ("Pontianak", -0.03, 109.33, "Asia/Pontianak"), ("Palangka Raya", -2.21, 113.92, "Asia/Pontianak"),
    ("Denpasar", -8.65, 115.22, "Asia/Makassar"), ("Mataram", -8.58, 116.12, "Asia/Makassar"),
    ("Kupang", -10.18, 123.61, "Asia/Makassar"), ("Banjarmasin", -3.32, 114.59, "Asia/Makassar"),
    ("Balikpapan", -1.27, 116.83, "Asia/Makassar"), ("Samarinda", -0.50, 117.15, "Asia/Makassar"),
    ("Tanjung Selor", 2.84, 117.37, "Asia/Makassar"), ("Makassar", -5.15, 119.43, "Asia/Makassar"),
    ("Palu", -0.90, 119.87, "Asia/Makassar"), ("Kendari", -3.97, 122.51, "Asia/Makassar"),
    ("Gorontalo", 0.54, 123.06, "Asia/Makassar"), ("Manado", 1.47, 124.84, "Asia/Makassar"),
    ("Mamuju", -2.68, 118.89, "Asia/Makassar"), ("Ambon", -3.70, 128.18, "Asia/Jayapura"),
    ("Ternate", 0.79, 127.38, "Asia/Jayapura"), ("Sorong", -0.88, 131.26, "Asia/Jayapura"),
    ("Manokwari", -0.86, 134.06, "Asia/Jayapura"), ("Jayapura", -2.53, 140.72, "Asia/Jayapura"),
    ("Merauke", -8.49, 140.40, "Asia/Jayapura"),
    ("Kuala Lumpur", 3.14, 101.69, "Asia/Kuala_Lumpur"), ("Singapore", 1.35, 103.82, "Asia/Singapore"),
    ("Bandar Seri Begawan", 4.90, 114.94, "Asia/Brunei"), ("Makkah", 21.42, 39.83, "Asia/Riyadh"),
    ("Madinah", 24.47, 39.61, "Asia/Riyadh"), ("Istanbul", 41.01, 28.98, "Europe/Istanbul"),
    ("Cairo", 30.04, 31.24, "Africa/Cairo"), ("Dubai", 25.20, 55.27, "Asia/Dubai"),
    ("Tokyo", 35.68, 139.69, "Asia/Tokyo"), ("Sydney", -33.87, 151.21, "Australia/Sydney"),
    ("London", 51.51, -0.13, "Europe/London"), ("Amsterdam", 52.37, 4.90, "Europe/Amsterdam"),
    ("New York", 40.71, -74.01, "America/New_York"),
].map { City(name: $0.0, lat: $0.1, lng: $0.2, tz: $0.3) }

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
        let matches = query.isEmpty ? cities : cities.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return (query.isEmpty ? [.auto] : []) + matches.map(Option.city) + results.map(Option.remote)
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
            TextField("Search city…", text: $model.query)
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
        let (title, icon, selected): (String, String, Bool) = switch o {
        case .auto: ("Automatic (GPS)", "location.fill", model.isAuto)
        case .city(let c): (c.name, "mappin", !model.isAuto && model.location.name == c.name)
        case .remote(let r): ([r.title, r.subtitle].filter { !$0.isEmpty }.joined(separator: ", "), "globe", false)
        }
        return Button { model.choose(o) } label: {
            HStack {
                Image(systemName: icon).font(.caption).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer()
                if case .remote(let r) = o, model.resolving == r { ProgressView().controlSize(.small) }
                if selected { Image(systemName: "checkmark").font(.caption) }
            }
            .padding(.vertical, 5).padding(.horizontal, 6)
            .background(highlighted ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
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
