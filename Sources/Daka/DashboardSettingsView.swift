import AppKit
import DakaCore
import SwiftUI

struct DakaSettingsView: View {
    @ObservedObject var viewModel: DakaDashboardViewModel
    @StateObject private var draft: DakaSettingsDraft
    @State private var section: DakaSettingsSection = .goals

    init(
        viewModel: DakaDashboardViewModel,
        initialSection: DakaSettingsSection = .goals
    ) {
        self.viewModel = viewModel
        _draft = StateObject(
            wrappedValue: DakaSettingsDraft(config: viewModel.config)
        )
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if section != .runtime {
                Divider()
                saveBar
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("设置")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("目标、匹配条件、提醒和运行状态都在这里管理。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Picker("设置分类", selection: $section) {
                ForEach(DakaSettingsSection.allCases) { item in
                    Label(item.title, systemImage: item.icon)
                        .tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(height: 28)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .goals:
            goalsView
        case .conditions:
            conditionsView
        case .reminders:
            remindersView
        case .runtime:
            runtimeView
        }
    }

    private var goalsView: some View {
        settingsScroll {
            SettingsCard(
                title: "工作时长目标",
                subtitle: "用于今日进度、月均达标和休息日前提醒。"
            ) {
                SettingsTextField(
                    title: "每日目标",
                    detail: "单日完成进度的基准",
                    value: $draft.targetHours,
                    suffix: "小时"
                )
                SettingsDivider()
                SettingsTextField(
                    title: "月均目标",
                    detail: "统计工作日的平均跨度",
                    value: $draft.monthlyAverageTargetHours,
                    suffix: "小时"
                )
                SettingsDivider()
                SettingsTextField(
                    title: "每周目标",
                    detail: "休息日前提醒使用的周累计目标",
                    value: $draft.weeklyTargetHours,
                    suffix: "小时"
                )
            }
        }
    }

    private var conditionsView: some View {
        settingsScroll {
            SettingsCard(
                title: "匹配规则",
                subtitle: "满足规则后，Daka 才会更新当天的最后满足时间。"
            ) {
                SettingsTextField(
                    title: "检查间隔",
                    detail: "允许 10 到 86400 秒",
                    value: $draft.evaluationInterval,
                    suffix: "秒"
                )
                SettingsDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("条件关系")
                            .font(.system(size: 13, weight: .medium))
                        Text("所有条件都满足，或满足任意一个")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("条件关系", selection: $draft.matchMode) {
                        Text("全部满足").tag(MatchMode.all)
                        Text("任一满足").tag(MatchMode.any)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                .padding(.vertical, 12)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("条件")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(draft.conditions.count) 个条件")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        draft.addCondition()
                    } label: {
                        Label("添加条件", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                ForEach(draft.conditions.indices, id: \.self) { index in
                    ConditionEditorCard(
                        condition: $draft.conditions[index],
                        ssidOptions: draft.ssidOptions,
                        ssidLoading: draft.ssidLoading,
                        bluetoothOptions: draft.bluetoothOptions,
                        bluetoothLoading: draft.bluetoothLoading,
                        bluetoothAvailability: draft.bluetoothAvailability,
                        bluetoothScanCompleted: draft.bluetoothScanCompleted,
                        bluetoothMonitoring: draft.bluetoothMonitoring,
                        canRemove: draft.conditions.count > 1,
                        onRefreshSSIDs: {
                            draft.refreshSSIDs(
                                keeping: draft.conditions[index].primary
                            )
                        },
                        onRefreshBluetooth: {
                            draft.refreshBluetoothDevices()
                        },
                        onOpenBluetoothSettings: {
                            openBluetoothSettings()
                        },
                        onToggleBluetoothMonitoring: {
                            draft.toggleBluetoothMonitoring()
                        },
                        onRemove: {
                            draft.removeCondition(at: index)
                        }
                    )
                }
            }
        }
        .onDisappear {
            draft.stopBluetoothMonitoring()
        }
    }

    private var remindersView: some View {
        settingsScroll {
            SettingsCard(
                title: "休息日前提醒",
                subtitle: "根据中国工作日历和本周累计时长发送提醒。"
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用提醒")
                            .font(.system(size: 13, weight: .medium))
                        Text("关闭后两类提醒都不会出现")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $draft.restDayReminderEnabled)
                        .labelsHidden()
                }
                .padding(.vertical, 12)
                SettingsDivider()
                SettingsTextField(
                    title: "休息日前提醒",
                    detail: "格式 HH:mm，例如 09:30",
                    value: $draft.restDayReminderTime,
                    suffix: ""
                )
                SettingsDivider()
                SettingsTextField(
                    title: "前一天提醒",
                    detail: "格式 HH:mm，例如 18:00",
                    value: $draft.dayBeforeRestReminderTime,
                    suffix: ""
                )
            }

            SettingsCard(
                title: "提醒文案",
                subtitle: "留空会恢复默认文案。"
            ) {
                SettingsMessageEditor(
                    title: "休息日前文案",
                    value: $draft.restDayReminderMessage
                )
                SettingsDivider()
                SettingsMessageEditor(
                    title: "前一天文案",
                    value: $draft.dayBeforeRestReminderMessage
                )
            }
        }
    }

    private var runtimeView: some View {
        settingsScroll {
            SettingsCard(
                title: "运行状态",
                subtitle: "查看自动统计、权限和数据存储状态。"
            ) {
                SettingsActionRow(
                    icon: viewModel.statsPaused
                        ? "pause.circle.fill"
                        : "play.circle.fill",
                    title: "自动统计",
                    detail: viewModel.statsPaused ? "当前已暂停" : "正在运行",
                    tint: viewModel.statsPaused ? .orange : DakaTheme.green,
                    buttonTitle: viewModel.statsPaused ? "恢复" : "暂停",
                    action: viewModel.onTogglePause
                )

                if viewModel.config.rule.conditions.contains(where: {
                    if case .wifiConnected = $0 { return true }
                    return false
                }) {
                    SettingsDivider()
                    SettingsActionRow(
                        icon: "location.circle.fill",
                        title: "Wi-Fi 定位权限",
                        detail: viewModel.locationPermissionTitle,
                        tint: viewModel.locationPermissionNeedsAction
                            ? .orange
                            : DakaTheme.green,
                        buttonTitle: viewModel.locationPermissionNeedsAction
                            ? "打开系统设置"
                            : nil,
                        action: viewModel.onOpenLocationSettings
                    )
                }

                SettingsDivider()
                SettingsActionRow(
                    icon: viewModel.storageError == nil
                        ? "externaldrive.fill.badge.checkmark"
                        : "externaldrive.fill.badge.exclamationmark",
                    title: "数据存储",
                    detail: viewModel.storageError ?? "SQLite 正常",
                    tint: viewModel.storageError == nil
                        ? DakaTheme.green
                        : .red,
                    buttonTitle: viewModel.storageError == nil ? nil : "查看",
                    action: viewModel.onShowStorageError
                )
            }

            SettingsCard(
                title: "操作",
                subtitle: "菜单栏里的运行操作也可以在这里完成。"
            ) {
                if viewModel.canConfirmClockIn {
                    SettingsActionRow(
                        icon: "checkmark.circle.fill",
                        title: "确认今日已打卡",
                        detail: "确认后开始记录今天的首次满足时间",
                        tint: DakaTheme.blue,
                        buttonTitle: "确认",
                        action: viewModel.confirmClockIn
                    )
                    SettingsDivider()
                }
                SettingsActionRow(
                    icon: "power",
                    title: "退出 Daka",
                    detail: "停止菜单栏服务，登录后仍会自动启动",
                    tint: .secondary,
                    buttonTitle: "退出",
                    action: viewModel.onQuit
                )
            }
        }
    }

    private var saveBar: some View {
        HStack(spacing: 12) {
            if let message = draft.message {
                Label(
                    message,
                    systemImage: draft.hasError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(draft.hasError ? .red : DakaTheme.green)
            }

            Spacer()
            Button {
                save()
            } label: {
                Label("保存设置", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .frame(height: 58)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsScroll<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private func save() {
        do {
            let nextConfig = try draft.makeConfig()
            if viewModel.saveConfig(nextConfig) {
                draft.showSaved()
            } else {
                draft.showSaveFailed()
            }
        } catch {
            draft.show(error: error)
        }
    }

    private func openBluetoothSettings() {
        let urlString: String
        switch draft.bluetoothAvailability?.recoveryAction {
        case .openBluetoothSettings:
            urlString = "x-apple.systempreferences:com.apple.BluetoothSettings"
        case .openBluetoothPrivacySettings:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
        case nil:
            return
        }
        guard let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

enum DakaSettingsSection: String, CaseIterable, Identifiable {
    case goals
    case conditions
    case reminders
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goals: return "目标"
        case .conditions: return "条件"
        case .reminders: return "提醒"
        case .runtime: return "运行"
        }
    }

    var icon: String {
        switch self {
        case .goals: return "scope"
        case .conditions: return "switch.2"
        case .reminders: return "bell"
        case .runtime: return "bolt"
        }
    }
}

private final class DakaSettingsDraft: ObservableObject {
    @Published var evaluationInterval: String
    @Published var targetHours: String
    @Published var monthlyAverageTargetHours: String
    @Published var weeklyTargetHours: String
    @Published var matchMode: MatchMode
    @Published var conditions: [DakaConditionDraft]
    @Published var restDayReminderEnabled: Bool
    @Published var restDayReminderTime: String
    @Published var dayBeforeRestReminderTime: String
    @Published var restDayReminderMessage: String
    @Published var dayBeforeRestReminderMessage: String
    @Published var ssidOptions: [String] = []
    @Published var ssidLoading = false
    @Published var bluetoothOptions: [BluetoothDeviceOption] = []
    @Published var bluetoothLoading = false
    @Published var bluetoothAvailability: BluetoothAvailability?
    @Published var bluetoothScanCompleted = false
    @Published var bluetoothMonitoring = false
    @Published var message: String?
    @Published var hasError = false

    private let ruleName: String
    private var ssidLoadGeneration = 0
    private var bluetoothMonitorTimer: Timer?

    init(config: AppConfig) {
        ruleName = config.rule.name
        evaluationInterval = String(Int(config.evaluationIntervalSeconds))
        targetHours = DakaFormatters.decimalHours(
            config.targetDurationSeconds
        )
        monthlyAverageTargetHours = DakaFormatters.decimalHours(
            config.monthlyAverageTargetSeconds
        )
        weeklyTargetHours = DakaFormatters.decimalHours(
            config.weeklyTargetSeconds
        )
        matchMode = config.rule.matchMode
        conditions = config.rule.conditions.map(DakaConditionDraft.init)
        restDayReminderEnabled = config.restDayReminderEnabled
        restDayReminderTime = config.restDayReminderTime
        dayBeforeRestReminderTime = config.dayBeforeRestReminderTime
        restDayReminderMessage = config.restDayReminderMessage
        dayBeforeRestReminderMessage = config.dayBeforeRestReminderMessage
    }

    func addCondition() {
        let usedSingletons = Set(
            conditions.filter(\.kind.isSingleton).map(\.kind)
        )
        let kind =
            DakaConditionDraft.Kind.allCases.first {
                !$0.isSingleton || !usedSingletons.contains($0)
            } ?? .wifiConnected
        conditions.append(DakaConditionDraft(kind: kind))
        clearMessage()
    }

    func removeCondition(at index: Int) {
        guard conditions.indices.contains(index), conditions.count > 1 else {
            return
        }
        conditions.remove(at: index)
        clearMessage()
    }

    func refreshSSIDs(keeping selected: String) {
        ssidLoadGeneration += 1
        let generation = ssidLoadGeneration
        ssidLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = WiFiSSIDProvider.availableSSIDs(keeping: selected)
            DispatchQueue.main.async {
                guard
                    let self,
                    generation == self.ssidLoadGeneration
                else {
                    return
                }
                self.ssidOptions = options
                self.ssidLoading = false
            }
        }
    }

    func refreshBluetoothDevices() {
        scanBluetoothDevices(duration: 4, showsLoading: true)
    }

    func toggleBluetoothMonitoring() {
        if bluetoothMonitoring {
            stopBluetoothMonitoring()
        } else {
            startBluetoothMonitoring()
        }
    }

    func stopBluetoothMonitoring() {
        bluetoothMonitorTimer?.invalidate()
        bluetoothMonitorTimer = nil
        bluetoothMonitoring = false
    }

    private func startBluetoothMonitoring() {
        stopBluetoothMonitoring()
        bluetoothMonitoring = true
        scanBluetoothDevices(duration: 1.2, showsLoading: false)

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.scanBluetoothDevices(duration: 1.2, showsLoading: false)
        }
        bluetoothMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func scanBluetoothDevices(
        duration: TimeInterval,
        showsLoading: Bool
    ) {
        if showsLoading {
            bluetoothLoading = true
            bluetoothScanCompleted = false
        }
        bluetoothAvailability = nil

        BluetoothDeviceScanner.shared.discover(
            for: duration
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let options):
                self.bluetoothOptions = options
            case .failure(let availability):
                self.bluetoothOptions = []
                self.bluetoothAvailability = availability
                self.stopBluetoothMonitoring()
            }
            self.bluetoothScanCompleted = true
            if showsLoading {
                self.bluetoothLoading = false
            }
        }
    }

    func makeConfig() throws -> AppConfig {
        if let duplicate = duplicateSingletonKind() {
            throw DakaSettingsValidationError.message(
                "\(duplicate.title) 已经存在，不能重复添加。"
            )
        }

        let resolvedConditions = try conditions.map { draft in
            guard let condition = draft.condition else {
                throw DakaSettingsValidationError.message(
                    "\(draft.kind.title) 条件还没填完整。"
                )
            }
            return condition
        }
        guard !resolvedConditions.isEmpty else {
            throw DakaSettingsValidationError.message("至少需要一个条件。")
        }

        guard
            let interval = DakaInputValidator.evaluationInterval(
                evaluationInterval
            )
        else {
            throw DakaSettingsValidationError.message(
                "检查间隔必须是 10 到 86400 之间的整数秒。"
            )
        }
        guard
            let daily = DakaInputValidator.positiveNumber(
                targetHours,
                range: 0.25...24
            )
        else {
            throw DakaSettingsValidationError.message(
                "每日目标必须是 0.25 到 24 小时。"
            )
        }
        guard
            let monthly = DakaInputValidator.positiveNumber(
                monthlyAverageTargetHours,
                range: 0.25...24
            )
        else {
            throw DakaSettingsValidationError.message(
                "月均目标必须是 0.25 到 24 小时。"
            )
        }
        guard
            let weekly = DakaInputValidator.positiveNumber(
                weeklyTargetHours,
                range: 0.25...168
            )
        else {
            throw DakaSettingsValidationError.message(
                "每周目标必须是 0.25 到 168 小时。"
            )
        }
        guard
            let restTime = DakaInputValidator.normalizedTime(
                restDayReminderTime
            )
        else {
            throw DakaSettingsValidationError.message(
                "休息日前提醒时间格式应为 HH:mm。"
            )
        }
        guard
            let dayBeforeTime = DakaInputValidator.normalizedTime(
                dayBeforeRestReminderTime
            )
        else {
            throw DakaSettingsValidationError.message(
                "前一天提醒时间格式应为 HH:mm。"
            )
        }

        let restMessage = restDayReminderMessage.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let dayBeforeMessage = dayBeforeRestReminderMessage.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return AppConfig(
            rule: TimerRule(
                name: ruleName.isEmpty ? "Default" : ruleName,
                matchMode: matchMode,
                conditions: resolvedConditions
            ),
            evaluationIntervalSeconds: interval,
            targetDurationSeconds: daily * 60 * 60,
            monthlyAverageTargetSeconds: monthly * 60 * 60,
            restDayReminderEnabled: restDayReminderEnabled,
            weeklyTargetSeconds: weekly * 60 * 60,
            restDayReminderTime: restTime,
            dayBeforeRestReminderTime: dayBeforeTime,
            restDayReminderMessage: restMessage.isEmpty
                ? AppConfig.defaultRestDayReminderMessage
                : restMessage,
            dayBeforeRestReminderMessage: dayBeforeMessage.isEmpty
                ? AppConfig.defaultDayBeforeRestReminderMessage
                : dayBeforeMessage
        )
    }

    func showSaved() {
        message = "设置已保存并立即生效。"
        hasError = false
    }

    func showSaveFailed() {
        message = "设置保存失败，请检查数据存储状态。"
        hasError = true
    }

    func show(error: Error) {
        message = error.localizedDescription
        hasError = true
    }

    private func clearMessage() {
        message = nil
        hasError = false
    }

    private func duplicateSingletonKind() -> DakaConditionDraft.Kind? {
        var seen = Set<DakaConditionDraft.Kind>()
        for draft in conditions where draft.kind.isSingleton {
            if seen.contains(draft.kind) {
                return draft.kind
            }
            seen.insert(draft.kind)
        }
        return nil
    }
}

private struct DakaConditionDraft {
    enum Kind: String, CaseIterable, Hashable, Identifiable {
        case screenUnlocked
        case wifiConnected
        case bluetoothSignal
        case powerConnected
        case networkReachable
        case timeRange

        var id: String { rawValue }

        var title: String {
            switch self {
            case .screenUnlocked: return "屏幕已解锁"
            case .wifiConnected: return "连接 Wi-Fi"
            case .bluetoothSignal: return "蓝牙信号"
            case .powerConnected: return "插入电源"
            case .networkReachable: return "网络可达"
            case .timeRange: return "时间范围"
            }
        }

        var hint: String {
            switch self {
            case .screenUnlocked:
                return "屏幕未锁定且屏保未运行时满足。"
            case .wifiConnected:
                return "连接到指定 SSID 时满足，名称区分大小写和空格。"
            case .bluetoothSignal:
                return "设备最近可见且信号达到阈值时满足，数值越接近 0 表示越近。"
            case .powerConnected:
                return "Mac 接入外部电源时满足。"
            case .networkReachable:
                return "能够建立 TCP 连接时满足。"
            case .timeRange:
                return "当前时间落在范围内时满足，支持跨午夜。"
            }
        }

        var isSingleton: Bool {
            switch self {
            case .screenUnlocked, .powerConnected:
                return true
            case .wifiConnected, .bluetoothSignal, .networkReachable, .timeRange:
                return false
            }
        }
    }

    var kind: Kind
    var primary = ""
    var secondary = ""
    var tertiary = ""

    init(kind: Kind) {
        self.kind = kind
        if kind == .bluetoothSignal {
            secondary = "-65"
        }
    }

    init(_ condition: TimerCondition) {
        switch condition {
        case .screenUnlocked:
            kind = .screenUnlocked
        case .wifiConnected(let ssid):
            kind = .wifiConnected
            primary = ssid
        case .bluetoothSignal(let identifier, let name, let minimumRSSI):
            kind = .bluetoothSignal
            primary = identifier
            secondary = String(minimumRSSI)
            tertiary = name
        case .powerConnected:
            kind = .powerConnected
        case .networkReachable(let host, let port):
            kind = .networkReachable
            primary = host
            secondary = String(port)
        case .timeRange(let start, let end):
            kind = .timeRange
            primary = start
            secondary = end
        }
    }

    var condition: TimerCondition? {
        switch kind {
        case .screenUnlocked:
            return .screenUnlocked
        case .wifiConnected:
            let ssid = primary.trimmingCharacters(in: .whitespacesAndNewlines)
            return ssid.isEmpty ? nil : .wifiConnected(ssid: ssid)
        case .bluetoothSignal:
            let identifier = primary.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = tertiary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !identifier.isEmpty,
                !name.isEmpty,
                let minimumRSSI = DakaInputValidator.bluetoothRSSI(secondary)
            else {
                return nil
            }
            return .bluetoothSignal(
                identifier: identifier,
                name: name,
                minimumRSSI: minimumRSSI
            )
        case .powerConnected:
            return .powerConnected
        case .networkReachable:
            let host = primary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !host.isEmpty,
                let port = Int(secondary),
                (1...65_535).contains(port)
            else {
                return nil
            }
            return .networkReachable(host: host, port: port)
        case .timeRange:
            guard
                let start = DakaInputValidator.normalizedTime(primary),
                let end = DakaInputValidator.normalizedTime(secondary)
            else {
                return nil
            }
            return .timeRange(start: start, end: end)
        }
    }
}

private enum DakaSettingsValidationError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)

            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DakaTheme.cardFill)
                .shadow(color: DakaTheme.cardShadow, radius: 7, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DakaTheme.cardStroke, lineWidth: 1)
        )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 2)
    }
}

private struct SettingsTextField: View {
    let title: String
    let detail: String
    @Binding var value: String
    let suffix: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            TextField("", text: $value)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 105)
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsMessageEditor: View {
    let title: String
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            TextEditor(text: $value)
                .font(.system(size: 12))
                .frame(minHeight: 54)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.1))
                )
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct ConditionEditorCard: View {
    @Binding var condition: DakaConditionDraft
    let ssidOptions: [String]
    let ssidLoading: Bool
    let bluetoothOptions: [BluetoothDeviceOption]
    let bluetoothLoading: Bool
    let bluetoothAvailability: BluetoothAvailability?
    let bluetoothScanCompleted: Bool
    let bluetoothMonitoring: Bool
    let canRemove: Bool
    let onRefreshSSIDs: () -> Void
    let onRefreshBluetooth: () -> Void
    let onOpenBluetoothSettings: () -> Void
    let onToggleBluetoothMonitoring: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("条件类型", selection: $condition.kind) {
                    ForEach(DakaConditionDraft.Kind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .disabled(!canRemove)
                .help("删除条件")
            }

            Text(condition.kind.hint)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            editor
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DakaTheme.cardFill)
                .shadow(color: DakaTheme.cardShadow, radius: 7, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DakaTheme.cardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var editor: some View {
        switch condition.kind {
        case .screenUnlocked, .powerConnected:
            EmptyView()
        case .wifiConnected:
            HStack(spacing: 10) {
                TextField("Wi-Fi 名称", text: $condition.primary)
                    .textFieldStyle(.roundedBorder)
                if !ssidOptions.isEmpty {
                    Picker("可见网络", selection: $condition.primary) {
                        if !ssidOptions.contains(condition.primary) {
                            Text(condition.primary.isEmpty ? "选择网络" : condition.primary)
                                .tag(condition.primary)
                        }
                        ForEach(ssidOptions, id: \.self) { ssid in
                            Text(ssid).tag(ssid)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                Button(action: onRefreshSSIDs) {
                    if ssidLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(ssidLoading)
            }
        case .bluetoothSignal:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Picker("蓝牙设备", selection: $condition.primary) {
                        if !condition.primary.isEmpty,
                            !bluetoothOptions.contains(where: {
                                $0.identifier == condition.primary
                            })
                        {
                            Text("\(condition.tertiary)（上次选择）")
                                .tag(condition.primary)
                        }
                        if condition.primary.isEmpty {
                            Text("请先扫描并选择设备").tag("")
                        }
                        ForEach(bluetoothOptions) { device in
                            Text(device.displayTitle).tag(device.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: condition.primary) { identifier in
                        if let device = bluetoothOptions.first(where: {
                            $0.identifier == identifier
                        }) {
                            condition.tertiary = device.name
                        }
                    }

                    Button(action: onRefreshBluetooth) {
                        if bluetoothLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("扫描", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(bluetoothLoading)
                }

                if let availability = bluetoothAvailability,
                    let message = availability.message
                {
                    HStack(spacing: 10) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DakaTheme.orange)
                        Spacer()
                        if availability.recoveryAction != nil {
                            Button(
                                recoveryButtonTitle(for: availability),
                                action: onOpenBluetoothSettings
                            )
                            .buttonStyle(.bordered)
                        }
                    }
                } else if bluetoothScanCompleted,
                    bluetoothOptions.isEmpty
                {
                    Label(
                        "未发现附近设备，请保持设备可发现后重试。",
                        systemImage: "info.circle"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }

                if !condition.primary.isEmpty {
                    bluetoothSignalStatus
                }

                HStack(spacing: 10) {
                    Text("最低信号")
                        .font(.system(size: 12, weight: .medium))
                    TextField("-65", text: $condition.secondary)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text("dBm（允许 -100 到 -20）")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        case .networkReachable:
            HStack(spacing: 10) {
                TextField("主机名或 IP", text: $condition.primary)
                    .textFieldStyle(.roundedBorder)
                TextField("端口", text: $condition.secondary)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
        case .timeRange:
            HStack(spacing: 10) {
                TextField("开始，例如 08:00", text: $condition.primary)
                    .textFieldStyle(.roundedBorder)
                Text("至")
                    .foregroundColor(.secondary)
                TextField("结束，例如 20:00", text: $condition.secondary)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var bluetoothSignalStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(bluetoothSignalColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bluetoothMonitoring ? "实时信号" : "最近信号")
                        .font(.system(size: 11, weight: .medium))
                    Text(
                        selectedBluetoothDevice.map { "\($0.rssi) dBm" }
                            ?? "等待设备广播"
                    )
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                if let device = selectedBluetoothDevice {
                    HStack(spacing: 4) {
                        Text(
                            device.rssi >= bluetoothThreshold
                                ? "已达到阈值"
                                : "未达到阈值"
                        )
                        Text("·")
                        Text(device.lastSeenAt, style: .relative)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(
                bluetoothMonitoring ? "停止监控" : "开始监控",
                action: onToggleBluetoothMonitoring
            )
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bluetoothSignalColor.opacity(0.09))
        )
    }

    private var selectedBluetoothDevice: BluetoothDeviceOption? {
        bluetoothOptions.first { $0.identifier == condition.primary }
    }

    private var bluetoothThreshold: Int {
        Int(condition.secondary) ?? -65
    }

    private var bluetoothSignalColor: Color {
        guard let device = selectedBluetoothDevice else {
            return .secondary
        }
        return device.rssi >= bluetoothThreshold
            ? DakaTheme.green
            : DakaTheme.orange
    }

    private func recoveryButtonTitle(
        for availability: BluetoothAvailability
    ) -> String {
        switch availability.recoveryAction {
        case .openBluetoothSettings:
            return "打开蓝牙设置"
        case .openBluetoothPrivacySettings:
            return "打开隐私设置"
        case nil:
            return "打开系统设置"
        }
    }
}
