import AppKit
import DakaCore
import Foundation

final class StatsWindowController: NSWindowController {
    private var records: [DailyRecord]
    private var targetDurationSeconds: TimeInterval
    private var monthlyAverageTargetSeconds: TimeInterval
    private var monthlySummaries: [MonthlyWorkdaySummary] = []
    private var holidayYears: [Int: ChinaHolidayYear] = [:]
    private let onSave: (DailyRecord) -> Bool
    private let tableView = NSTableView()
    private let monthlyTableView = NSTableView()
    private let tabControl = NSSegmentedControl(labels: ["表格", "趋势", "热力图", "月度"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentContainer = NSView()
    private let tableContainer = NSView()
    private let monthlyContainer = NSView()
    private let trendChartView = TrendChartView()
    private let heatmapView = HeatmapView()
    private let summary = NSTextField(labelWithString: "")
    private let addLeaveButton = NSButton(title: "添加请假日", target: nil, action: nil)
    private let excludeButton = NSButton(title: "不计入统计", target: nil, action: nil)
    private let editButton = NSButton(title: "编辑时间", target: nil, action: nil)
    private let chinaCalendar = ChinaWorkdayCalendar()

    init(
        records: [DailyRecord],
        targetDurationSeconds: TimeInterval,
        monthlyAverageTargetSeconds: TimeInterval,
        onSave: @escaping (DailyRecord) -> Bool
    ) {
        self.records = records.sorted { $0.date > $1.date }
        self.targetDurationSeconds = targetDurationSeconds
        self.monthlyAverageTargetSeconds = monthlyAverageTargetSeconds
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Daka 统计"
        window.minSize = NSSize(width: 700, height: 480)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)
        setupUI()
        refreshMonthlySummaries(fetchRemote: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(records: [DailyRecord], targetDurationSeconds: TimeInterval, monthlyAverageTargetSeconds: TimeInterval) {
        self.records = records.sorted { $0.date > $1.date }
        self.targetDurationSeconds = targetDurationSeconds
        self.monthlyAverageTargetSeconds = monthlyAverageTargetSeconds
        summary.stringValue = summaryText
        refreshCharts()
        refreshMonthlySummaries(fetchRemote: true)
        tableView.reloadData()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let overviewPanel = RoundedPanelView()
        root.addArrangedSubview(overviewPanel)

        let overviewStack = NSStackView()
        overviewStack.orientation = .vertical
        overviewStack.spacing = 5
        overviewStack.translatesAutoresizingMaskIntoConstraints = false
        overviewPanel.addSubview(overviewStack)
        pin(overviewStack, to: overviewPanel, insets: NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))

        let overviewTitle = NSTextField(labelWithString: "统计概览")
        overviewTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        overviewTitle.textColor = .labelColor
        overviewStack.addArrangedSubview(overviewTitle)

        summary.font = .systemFont(ofSize: 12, weight: .regular)
        summary.textColor = .secondaryLabelColor
        summary.lineBreakMode = .byWordWrapping
        summary.maximumNumberOfLines = 0
        summary.stringValue = summaryText
        overviewStack.addArrangedSubview(summary)

        tabControl.selectedSegment = 0
        tabControl.segmentStyle = .rounded
        tabControl.controlSize = .large
        tabControl.target = self
        tabControl.action = #selector(tabChanged)
        root.addArrangedSubview(tabControl)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.style = .inset
        tableView.rowSizeStyle = .medium
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.target = self
        tableView.doubleAction = #selector(editSelectedRecord)

        addColumn(id: "date", title: "日期", width: 120)
        addColumn(id: "first", title: "首次", width: 120)
        addColumn(id: "last", title: "最后", width: 120)
        addColumn(id: "span", title: "跨度", width: 100)
        addColumn(id: "progress", title: "完成率", width: 90)
        addColumn(id: "stats", title: "统计", width: 80)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(contentContainer)
        contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 330).isActive = true

        setupTableContainer()
        setupMonthlyContainer()
        setupChartContainers()
        showPanel(tableContainer)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.alignment = .centerY
        root.addArrangedSubview(footer)

        let spacer = NSView()
        footer.addArrangedSubview(spacer)

        addLeaveButton.target = self
        addLeaveButton.action = #selector(addLeaveDay)
        styleFooterButton(addLeaveButton)
        footer.addArrangedSubview(addLeaveButton)

        excludeButton.target = self
        excludeButton.action = #selector(toggleSelectedRecordExcluded)
        excludeButton.isEnabled = false
        styleFooterButton(excludeButton)
        footer.addArrangedSubview(excludeButton)

        editButton.target = self
        editButton.action = #selector(editSelectedRecord)
        editButton.isEnabled = false
        styleFooterButton(editButton)
        footer.addArrangedSubview(editButton)
    }

    private func setupTableContainer() {
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(tableContainer)
        pin(tableContainer, to: contentContainer)

        let panel = RoundedPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(panel)
        pin(panel, to: tableContainer)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scrollView)
        pin(scrollView, to: panel, insets: NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
    }

    private func setupMonthlyContainer() {
        monthlyContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(monthlyContainer)
        pin(monthlyContainer, to: contentContainer)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        monthlyContainer.addSubview(stack)
        pin(stack, to: monthlyContainer)

        monthlyTableView.delegate = self
        monthlyTableView.dataSource = self
        monthlyTableView.style = .inset
        monthlyTableView.rowSizeStyle = .medium
        monthlyTableView.backgroundColor = .clear
        monthlyTableView.usesAlternatingRowBackgroundColors = false
        monthlyTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        addMonthlyColumn(id: "month", title: "月份", width: 90)
        addMonthlyColumn(id: "workdays", title: "工作日", width: 80)
        addMonthlyColumn(id: "recorded", title: "有记录", width: 80)
        addMonthlyColumn(id: "total", title: "总时长", width: 100)
        addMonthlyColumn(id: "average", title: "日均", width: 100)
        addMonthlyColumn(id: "status", title: "达标", width: 90)

        let scrollView = NSScrollView()
        scrollView.documentView = monthlyTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let panel = RoundedPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scrollView)
        pin(scrollView, to: panel, insets: NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
        stack.addArrangedSubview(panel)
    }

    private func setupChartContainers() {
        trendChartView.records = records
        trendChartView.targetDurationSeconds = targetDurationSeconds
        heatmapView.records = records
        heatmapView.targetDurationSeconds = targetDurationSeconds

        for view in [trendChartView, heatmapView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(view)
            pin(view, to: contentContainer)
            view.isHidden = true
        }
    }

    private var summaryText: String {
        let workdayRecords = recordsForVisibleWorkdays()
        let included = workdayRecords.filter { !$0.excludedFromStats }
        let completed = included.filter { $0.firstMatchedAt != nil && $0.lastMatchedAt != nil }
        let excludedCount = workdayRecords.count - included.count
        let calendarNotice = monthlySummaries.contains { !$0.usesChinaCalendarData }
            ? "；标有“估算”的月份暂未取得中国节假日日历，仅按周一至周五计算"
            : ""
        return "共 \(workdayRecords.count) 天工作日记录，\(excludedCount) 天不计入，\(completed.count) 天有有效时间，日目标 \(DakaFormatters.duration(targetDurationSeconds))，月均目标 \(DakaFormatters.duration(monthlyAverageTargetSeconds))\(calendarNotice)"
    }

    private func addColumn(id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    private func addMonthlyColumn(id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        monthlyTableView.addTableColumn(column)
    }

    @objc private func editSelectedRecord() {
        let row = tableView.selectedRow
        let visibleRecords = recordsForVisibleWorkdays()
        guard row >= 0, row < visibleRecords.count,
              let recordIndex = records.firstIndex(where: { $0.date == visibleRecords[row].date }) else {
            return
        }

        let original = records[recordIndex]
        guard let updated = RecordEditor.run(record: original) else {
            return
        }

        guard onSave(updated) else {
            return
        }
        records[recordIndex] = updated
        refreshAfterRecordsChanged(selectedDate: updated.date)
    }

    @objc private func addLeaveDay() {
        guard let dateKey = LeaveDayPicker.run() else {
            return
        }

        let updated: DailyRecord
        if let recordIndex = records.firstIndex(where: { $0.date == dateKey }) {
            var record = records[recordIndex]
            record.excludedFromStats = true
            updated = record
        } else {
            updated = DailyRecord(date: dateKey, excludedFromStats: true)
        }

        guard onSave(updated) else {
            return
        }
        records.removeAll { $0.date == dateKey }
        records.append(updated)
        refreshAfterRecordsChanged(selectedDate: dateKey)
    }

    @objc private func toggleSelectedRecordExcluded() {
        let row = tableView.selectedRow
        let visibleRecords = recordsForVisibleWorkdays()
        guard row >= 0, row < visibleRecords.count,
              let recordIndex = records.firstIndex(where: { $0.date == visibleRecords[row].date }) else {
            return
        }

        var updated = records[recordIndex]
        updated.excludedFromStats.toggle()
        guard onSave(updated) else {
            return
        }
        records[recordIndex] = updated
        refreshAfterRecordsChanged(selectedDate: updated.date)
    }

    @objc private func tabChanged() {
        switch tabControl.selectedSegment {
        case 1:
            showPanel(trendChartView)
            updateRecordButtons(enabled: false)
        case 2:
            showPanel(heatmapView)
            updateRecordButtons(enabled: false)
        case 3:
            showPanel(monthlyContainer)
            updateRecordButtons(enabled: false)
        default:
            showPanel(tableContainer)
            updateRecordButtons(enabled: tableView.selectedRow >= 0)
        }
    }

    private func showPanel(_ selected: NSView) {
        for view in [tableContainer, trendChartView, heatmapView, monthlyContainer] {
            view.isHidden = view !== selected
        }
    }

    private func refreshCharts() {
        let visibleRecords = recordsForVisibleWorkdays()
        trendChartView.records = visibleRecords
        trendChartView.targetDurationSeconds = targetDurationSeconds
        heatmapView.records = visibleRecords
        heatmapView.targetDurationSeconds = targetDurationSeconds
    }

    private func refreshAfterRecordsChanged(selectedDate: String? = nil) {
        records.sort { $0.date > $1.date }
        tableView.reloadData()
        summary.stringValue = summaryText
        refreshCharts()
        refreshMonthlySummaries(fetchRemote: false)

        let visibleRecords = recordsForVisibleWorkdays()
        if let selectedDate, let index = visibleRecords.firstIndex(where: { $0.date == selectedDate }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        updateRecordButtons(enabled: tableView.selectedRow >= 0 && tabControl.selectedSegment == 0)
    }

    private func updateRecordButtons(enabled: Bool) {
        editButton.isEnabled = enabled
        excludeButton.isEnabled = enabled

        let visibleRecords = recordsForVisibleWorkdays()
        guard enabled, tableView.selectedRow >= 0, tableView.selectedRow < visibleRecords.count else {
            excludeButton.title = "不计入统计"
            return
        }

        excludeButton.title = visibleRecords[tableView.selectedRow].excludedFromStats ? "恢复计入统计" : "不计入统计"
    }

    private func recordsForVisibleWorkdays() -> [DailyRecord] {
        records.filter { record in
            guard let year = ChinaWorkdayCalendar.year(from: record.date) else {
                return false
            }

            return chinaCalendar.isWorkday(dateKey: record.date, holidayYear: holidayYears[year])
        }
    }

    private func refreshMonthlySummaries(fetchRemote: Bool) {
        let years = requiredCalendarYears()
        holidayYears.merge(chinaCalendar.loadCachedYears(years)) { _, cached in cached }
        monthlySummaries = MonthlyWorkdaySummarizer.summaries(
            records: records,
            targetSeconds: monthlyAverageTargetSeconds,
            holidayYears: holidayYears,
            calendar: chinaCalendar
        )
        monthlyTableView.reloadData()
        summary.stringValue = summaryText
        refreshCharts()
        tableView.reloadData()
        updateRecordButtons(enabled: tableView.selectedRow >= 0 && tabControl.selectedSegment == 0)

        guard fetchRemote, !years.isEmpty else {
            return
        }

        chinaCalendar.refreshYears(years) { [weak self] refreshed in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.holidayYears.merge(refreshed) { _, remote in remote }
                self.monthlySummaries = MonthlyWorkdaySummarizer.summaries(
                    records: self.records,
                    targetSeconds: self.monthlyAverageTargetSeconds,
                    holidayYears: self.holidayYears,
                    calendar: self.chinaCalendar
                )
                self.monthlyTableView.reloadData()
                self.summary.stringValue = self.summaryText
                self.refreshCharts()
                self.tableView.reloadData()
                self.updateRecordButtons(enabled: self.tableView.selectedRow >= 0 && self.tabControl.selectedSegment == 0)
            }
        }
    }

    private func requiredCalendarYears() -> Set<Int> {
        var years = Set(records.compactMap { ChinaWorkdayCalendar.year(from: $0.date) })
        years.insert(Calendar.current.component(.year, from: Date()))
        return years
    }

    private func styleFooterButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 13, weight: .medium)
    }

    private func pin(_ child: NSView, to parent: NSView) {
        pin(child, to: parent, insets: NSEdgeInsetsZero)
    }

    private func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets) {
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

extension StatsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === monthlyTableView {
            return monthlySummaries.count
        }

        return recordsForVisibleWorkdays().count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else {
            return nil
        }

        if tableView === monthlyTableView {
            return monthlyCell(tableColumn: tableColumn, row: row)
        }

        let visibleRecords = recordsForVisibleWorkdays()
        guard row < visibleRecords.count else {
            return nil
        }
        let record = visibleRecords[row]
        let identifier = NSUserInterfaceItemIdentifier("statsCell")
        let field = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        field.identifier = identifier
        field.textColor = .labelColor

        switch tableColumn.identifier.rawValue {
        case "date":
            field.stringValue = record.date
        case "first":
            field.stringValue = DakaFormatters.shortTime(record.firstMatchedAt)
        case "last":
            field.stringValue = DakaFormatters.shortTime(record.lastMatchedAt)
        case "span":
            field.stringValue = DakaFormatters.duration(record.spanSeconds)
        case "progress":
            field.stringValue = DakaFormatters.percent(progress(for: record))
            field.textColor = color(for: record)
        case "stats":
            field.stringValue = record.excludedFromStats ? "不计入" : "计入"
            field.textColor = record.excludedFromStats ? .systemOrange : .secondaryLabelColor
        default:
            field.stringValue = ""
        }

        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let source = notification.object as? NSTableView, source === tableView else {
            return
        }

        updateRecordButtons(enabled: tableView.selectedRow >= 0 && tabControl.selectedSegment == 0)
    }

    private func monthlyCell(tableColumn: NSTableColumn, row: Int) -> NSView? {
        let summary = monthlySummaries[row]
        let identifier = NSUserInterfaceItemIdentifier("monthlyStatsCell")
        let field = monthlyTableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        field.identifier = identifier
        field.textColor = .labelColor

        switch tableColumn.identifier.rawValue {
        case "month":
            field.stringValue = summary.month
        case "workdays":
            field.stringValue = "\(summary.workdayCount)"
        case "recorded":
            field.stringValue = "\(summary.recordedWorkdayCount)"
        case "total":
            field.stringValue = DakaFormatters.duration(summary.totalSeconds)
        case "average":
            field.stringValue = DakaFormatters.duration(summary.averageSeconds)
        case "status":
            let result = summary.isPassing ? "达标" : "未达标"
            field.stringValue = summary.usesChinaCalendarData ? result : "\(result)（估算）"
            field.textColor = summary.isPassing ? .systemGreen : .systemRed
        default:
            field.stringValue = ""
        }

        return field
    }

    private func progress(for record: DailyRecord) -> Double {
        guard !record.excludedFromStats, let spanSeconds = record.spanSeconds, targetDurationSeconds > 0 else {
            return 0
        }

        return min(1, max(0, spanSeconds / targetDurationSeconds))
    }

    private func color(for record: DailyRecord) -> NSColor {
        guard !record.excludedFromStats else {
            return .systemOrange
        }

        switch ProgressStage.stage(spanSeconds: record.spanSeconds, targetSeconds: targetDurationSeconds) {
        case .empty:
            return .tertiaryLabelColor
        case .low:
            return .systemRed
        case .medium:
            return .systemOrange
        case .high:
            return .systemBlue
        case .complete:
            return .systemGreen
        }
    }
}

private final class RoundedPanelView: NSView {
    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)

        NSColor.controlBackgroundColor.withAlphaComponent(0.82).setFill()
        path.fill()

        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

enum LeaveDayPicker {
    static func run() -> String? {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.dateValue = Date()
        picker.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.frame = NSRect(x: 0, y: 0, width: 280, height: 44)
        container.addArrangedSubview(row(label: "日期", view: picker))

        let alert = NSAlert()
        alert.messageText = "添加请假日"
        alert.informativeText = "该日期会被标记为不计入统计；如果当天已有记录，会保留时间并改为不计入。"
        alert.accessoryView = container
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return ChinaWorkdayCalendar.dateFormatter.string(from: picker.dateValue)
    }

    private static func row(label: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 54).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(view)
        return row
    }
}

private enum RecordEditor {
    static func run(record: DailyRecord) -> DailyRecord? {
        let firstPicker = picker(date: record.firstMatchedAt ?? fallbackDate(record: record, hour: 9))
        let lastPicker = picker(date: record.lastMatchedAt ?? Date())

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.frame = NSRect(x: 0, y: 0, width: 300, height: 92)

        container.addArrangedSubview(row(label: "首次", view: firstPicker))
        container.addArrangedSubview(row(label: "最后", view: lastPicker))

        let alert = NSAlert()
        alert.messageText = "编辑 \(record.date)"
        alert.informativeText = "用于修正当天统计时间。"
        alert.accessoryView = container
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else {
            return nil
        }

        guard let updated = DailyRecordTimeEditor.updating(
            record,
            firstTime: firstPicker.dateValue,
            lastTime: lastPicker.dateValue
        ) else {
            let validationAlert = NSAlert()
            validationAlert.alertStyle = .warning
            validationAlert.messageText = "时间无效"
            validationAlert.informativeText = "首次和最后时间必须属于 \(record.date)，且最后时间不能早于首次时间。"
            validationAlert.runModal()
            return nil
        }
        return updated
    }

    private static func picker(date: Date) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.hourMinute]
        picker.dateValue = date
        picker.widthAnchor.constraint(equalToConstant: 120).isActive = true
        return picker
    }

    private static func row(label: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 54).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(view)
        return row
    }

    private static func fallbackDate(record: DailyRecord, hour: Int) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(record.date) \(String(format: "%02d", hour)):00") ?? Date()
    }
}
