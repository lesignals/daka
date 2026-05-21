import AppKit
import DakaCore
import Foundation

final class StatsWindowController: NSWindowController {
    private var records: [DailyRecord]
    private var targetDurationSeconds: TimeInterval
    private var monthlyAverageTargetSeconds: TimeInterval
    private var monthlySummaries: [MonthlyWorkdaySummary] = []
    private var holidayYears: [Int: ChinaHolidayYear] = [:]
    private let onSave: ([DailyRecord]) -> Void
    private let tableView = NSTableView()
    private let monthlyTableView = NSTableView()
    private let tabControl = NSSegmentedControl(labels: ["表格", "趋势", "热力图", "月度"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentContainer = NSView()
    private let tableContainer = NSView()
    private let monthlyContainer = NSView()
    private let trendChartView = TrendChartView()
    private let heatmapView = HeatmapView()
    private let summary = NSTextField(labelWithString: "")
    private let excludeButton = NSButton(title: "不计入统计", target: nil, action: nil)
    private let editButton = NSButton(title: "编辑时间", target: nil, action: nil)
    private let chinaCalendar = ChinaWorkdayCalendar()

    init(
        records: [DailyRecord],
        targetDurationSeconds: TimeInterval,
        monthlyAverageTargetSeconds: TimeInterval,
        onSave: @escaping ([DailyRecord]) -> Void
    ) {
        self.records = records.sorted { $0.date > $1.date }
        self.targetDurationSeconds = targetDurationSeconds
        self.monthlyAverageTargetSeconds = monthlyAverageTargetSeconds
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Daka 统计"
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

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        summary.font = .systemFont(ofSize: 13, weight: .medium)
        summary.stringValue = summaryText
        root.addArrangedSubview(summary)

        tabControl.selectedSegment = 0
        tabControl.target = self
        tabControl.action = #selector(tabChanged)
        root.addArrangedSubview(tabControl)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
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
        contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        setupTableContainer()
        setupMonthlyContainer()
        setupChartContainers()
        showPanel(tableContainer)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 10
        root.addArrangedSubview(footer)

        let spacer = NSView()
        footer.addArrangedSubview(spacer)

        excludeButton.target = self
        excludeButton.action = #selector(toggleSelectedRecordExcluded)
        excludeButton.isEnabled = false
        footer.addArrangedSubview(excludeButton)

        editButton.target = self
        editButton.action = #selector(editSelectedRecord)
        editButton.isEnabled = false
        footer.addArrangedSubview(editButton)
    }

    private func setupTableContainer() {
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(tableContainer)
        pin(tableContainer, to: contentContainer)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.addSubview(scrollView)
        pin(scrollView, to: tableContainer)
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
        monthlyTableView.usesAlternatingRowBackgroundColors = true
        monthlyTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        addMonthlyColumn(id: "month", title: "月份", width: 90)
        addMonthlyColumn(id: "workdays", title: "工作日", width: 80)
        addMonthlyColumn(id: "recorded", title: "有记录", width: 80)
        addMonthlyColumn(id: "total", title: "总时长", width: 100)
        addMonthlyColumn(id: "average", title: "日均", width: 100)
        addMonthlyColumn(id: "status", title: "达标", width: 70)

        let scrollView = NSScrollView()
        scrollView.documentView = monthlyTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(scrollView)
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
        return "共 \(workdayRecords.count) 天工作日记录，\(excludedCount) 天不计入，\(completed.count) 天有有效时间，日目标 \(DakaFormatters.duration(targetDurationSeconds))，月均目标 \(DakaFormatters.duration(monthlyAverageTargetSeconds))"
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

        records[recordIndex] = updated
        refreshAfterRecordsChanged(selectedDate: updated.date)
        onSave(records)
    }

    @objc private func toggleSelectedRecordExcluded() {
        let row = tableView.selectedRow
        let visibleRecords = recordsForVisibleWorkdays()
        guard row >= 0, row < visibleRecords.count,
              let recordIndex = records.firstIndex(where: { $0.date == visibleRecords[row].date }) else {
            return
        }

        records[recordIndex].excludedFromStats.toggle()
        refreshAfterRecordsChanged(selectedDate: records[recordIndex].date)
        onSave(records)
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

    private func pin(_ child: NSView, to parent: NSView) {
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
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
            field.stringValue = summary.isPassing ? "达标" : "未达标"
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

        var updated = record
        updated.firstMatchedAt = firstPicker.dateValue
        updated.lastMatchedAt = max(firstPicker.dateValue, lastPicker.dateValue)
        return updated
    }

    private static func picker(date: Date) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = date
        picker.widthAnchor.constraint(equalToConstant: 210).isActive = true
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
