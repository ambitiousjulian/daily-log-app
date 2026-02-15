import UIKit
import PDFKit
import CoreData

class PDFExportService {

    static func generatePDF(
        logs: [ParentingLog],
        context: NSManagedObjectContext
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 32
        let contentWidth = pageWidth - (margin * 2)

        // Table column layout
        let colTime: CGFloat = 48
        let colActivity: CGFloat = 88
        let colDetail: CGFloat = 80
        let colNote: CGFloat = contentWidth - colTime - colActivity - colDetail
        let colXTime = margin
        let colXActivity = margin + colTime
        let colXDetail = margin + colTime + colActivity
        let colXNote = margin + colTime + colActivity + colDetail
        let cellPadH: CGFloat = 3
        let cellPadV: CGFloat = 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = renderer.pdfData { pdfContext in
            var currentY: CGFloat = 0

            func startNewPage() {
                pdfContext.beginPage()
                currentY = margin
            }

            func checkPageBreak(needed: CGFloat) {
                if currentY + needed > pageHeight - margin {
                    startNewPage()
                }
            }

            func measureText(_ text: String, font: UIFont, maxWidth: CGFloat) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                return (text as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height
            }

            @discardableResult
            func drawText(
                _ text: String,
                at point: CGPoint,
                font: UIFont,
                color: UIColor = .black,
                maxWidth: CGFloat
            ) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: point.x, y: point.y, width: maxWidth, height: boundingRect.height),
                    withAttributes: attributes
                )
                return boundingRect.height
            }

            func drawHorizontalLine(y: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }

            // Fonts
            let titleFont = UIFont.boldSystemFont(ofSize: 15)
            let headerFont = UIFont.boldSystemFont(ofSize: 10)
            let bodyFont = UIFont.systemFont(ofSize: 8.5)
            let smallFont = UIFont.systemFont(ofSize: 7.5)
            let boldSmall = UIFont.boldSystemFont(ofSize: 8.5)
            let tableHeaderFont = UIFont.boldSystemFont(ofSize: 7.5)

            // --- Header ---
            startNewPage()

            currentY += drawText(
                "PARENTING ACTIVITY REPORT",
                at: CGPoint(x: margin, y: currentY),
                font: titleFont,
                maxWidth: contentWidth
            ) + 3

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            var metaLine = "Generated \(dateFormatter.string(from: Date()))"
            if let oldest = logs.last?.timestamp, let newest = logs.first?.timestamp {
                metaLine += "  ·  \(dateFormatter.string(from: oldest)) — \(dateFormatter.string(from: newest))"
            }
            currentY += drawText(metaLine, at: CGPoint(x: margin, y: currentY), font: smallFont, color: .gray, maxWidth: contentWidth) + 5

            drawHorizontalLine(y: currentY)
            currentY += 6

            // --- Summary (two-column) ---
            currentY += drawText("Summary (\(logs.count) total)", at: CGPoint(x: margin, y: currentY), font: headerFont, maxWidth: contentWidth) + 3

            var categoryCounts: [String: Int] = [:]
            for log in logs {
                categoryCounts[log.category ?? "unknown", default: 0] += 1
            }

            let activeCats = LogCategory.allCases.filter { (categoryCounts[$0.rawValue] ?? 0) > 0 }
            let summaryColW = contentWidth / 3
            var col = 0

            for category in activeCats {
                let count = categoryCounts[category.rawValue] ?? 0
                let x = margin + CGFloat(col) * summaryColW
                let line = "\(category.emoji) \(category.displayName): \(count)"
                let h = drawText(line, at: CGPoint(x: x, y: currentY), font: bodyFont, maxWidth: summaryColW - 4)
                if col == 2 {
                    currentY += h + 1
                    col = 0
                } else {
                    col += 1
                }
            }
            if col > 0 { currentY += 10 }

            currentY += 4
            drawHorizontalLine(y: currentY)
            currentY += 6

            // --- Timeline as table ---
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            // Group by day
            var groupedLogs: [(String, [ParentingLog])] = []
            var currentDay = ""
            var currentGroup: [ParentingLog] = []

            for log in logs {
                guard let ts = log.timestamp else { continue }
                let dayString = dateFormatter.string(from: ts)
                if dayString != currentDay {
                    if !currentGroup.isEmpty {
                        groupedLogs.append((currentDay, currentGroup))
                    }
                    currentDay = dayString
                    currentGroup = [log]
                } else {
                    currentGroup.append(log)
                }
            }
            if !currentGroup.isEmpty {
                groupedLogs.append((currentDay, currentGroup))
            }

            // Draw table header
            func drawTableHeader() {
                let headerH: CGFloat = 12
                checkPageBreak(needed: headerH + 14)

                let headerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: headerH)
                UIColor(white: 0.88, alpha: 1).setFill()
                UIBezierPath(rect: headerRect).fill()

                let hY = currentY + 2
                drawText("TIME", at: CGPoint(x: colXTime + cellPadH, y: hY), font: tableHeaderFont, color: .darkGray, maxWidth: colTime - cellPadH * 2)
                drawText("ACTIVITY", at: CGPoint(x: colXActivity + cellPadH, y: hY), font: tableHeaderFont, color: .darkGray, maxWidth: colActivity - cellPadH * 2)
                drawText("DETAILS", at: CGPoint(x: colXDetail + cellPadH, y: hY), font: tableHeaderFont, color: .darkGray, maxWidth: colDetail - cellPadH * 2)
                drawText("NOTES", at: CGPoint(x: colXNote + cellPadH, y: hY), font: tableHeaderFont, color: .darkGray, maxWidth: colNote - cellPadH * 2)

                currentY += headerH
            }

            var rowIndex = 0

            for (day, dayLogs) in groupedLogs {
                // Day header bar
                checkPageBreak(needed: 24)
                let dayH: CGFloat = 13
                let dayRect = CGRect(x: margin, y: currentY, width: contentWidth, height: dayH)
                UIColor(white: 0.93, alpha: 1).setFill()
                UIBezierPath(roundedRect: dayRect, cornerRadius: 2).fill()
                drawText(day, at: CGPoint(x: margin + 4, y: currentY + 1.5), font: boldSmall, maxWidth: contentWidth - 8)
                currentY += dayH + 2

                // Table header after each day label
                drawTableHeader()
                rowIndex = 0

                for log in dayLogs {
                    guard let ts = log.timestamp else { continue }
                    let cat = LogCategory(rawValue: log.category ?? "") ?? .activity
                    let timeStr = timeFormatter.string(from: ts)

                    // Build cell texts
                    let activityText = "\(cat.emoji) \(cat.displayName)"
                    var detailText = ""
                    if let sub = log.subcategory, !sub.isEmpty {
                        detailText = sub
                    }
                    if let amount = log.amount, amount != 0 {
                        detailText += detailText.isEmpty ? "$\(amount)" : "\n$\(amount)"
                    }
                    if detailText.isEmpty { detailText = "—" }

                    let noteText = log.note ?? ""
                    let hasPhoto = log.photoData != nil

                    // Measure row height
                    let timeH = measureText(timeStr, font: bodyFont, maxWidth: colTime - cellPadH * 2)
                    let actH = measureText(activityText, font: bodyFont, maxWidth: colActivity - cellPadH * 2)
                    let detH = measureText(detailText, font: bodyFont, maxWidth: colDetail - cellPadH * 2)

                    let noteW = colNote - cellPadH * 2 - (hasPhoto ? 28 : 0)
                    let noteH = noteText.isEmpty ? 0 : measureText(noteText, font: smallFont, maxWidth: noteW)
                    let photoH: CGFloat = hasPhoto ? 24 : 0

                    let textMax = max(timeH, actH, detH, noteH, photoH)
                    let rowH = textMax + cellPadV * 2

                    checkPageBreak(needed: rowH)

                    // On page break, re-draw table header
                    if currentY == margin {
                        drawTableHeader()
                    }

                    // Alternating row background
                    if rowIndex % 2 == 1 {
                        let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: rowH)
                        UIColor(white: 0.97, alpha: 1).setFill()
                        UIBezierPath(rect: rowRect).fill()
                    }

                    let textY = currentY + cellPadV

                    // Time
                    drawText(timeStr, at: CGPoint(x: colXTime + cellPadH, y: textY), font: bodyFont, maxWidth: colTime - cellPadH * 2)

                    // Activity
                    drawText(activityText, at: CGPoint(x: colXActivity + cellPadH, y: textY), font: bodyFont, maxWidth: colActivity - cellPadH * 2)

                    // Details
                    drawText(detailText, at: CGPoint(x: colXDetail + cellPadH, y: textY), font: bodyFont, maxWidth: colDetail - cellPadH * 2)

                    // Photo thumbnail (tiny, inline in notes column)
                    var noteOffsetX: CGFloat = 0
                    if let photoData = log.photoData, let image = UIImage(data: photoData) {
                        let thumbSize: CGFloat = 24
                        let aspectRatio = image.size.width / image.size.height
                        let tw = aspectRatio > 1 ? thumbSize : thumbSize * aspectRatio
                        let th = aspectRatio > 1 ? thumbSize / aspectRatio : thumbSize
                        let photoRect = CGRect(
                            x: colXNote + cellPadH,
                            y: textY,
                            width: tw,
                            height: th
                        )
                        image.draw(in: photoRect)
                        noteOffsetX = 28
                    }

                    // Note
                    if !noteText.isEmpty {
                        drawText(noteText, at: CGPoint(x: colXNote + cellPadH + noteOffsetX, y: textY), font: smallFont, color: .darkGray, maxWidth: colNote - cellPadH * 2 - noteOffsetX)
                    }

                    // Thin separator line
                    let lineY = currentY + rowH
                    let linePath = UIBezierPath()
                    linePath.move(to: CGPoint(x: margin, y: lineY))
                    linePath.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
                    UIColor(white: 0.90, alpha: 1).setStroke()
                    linePath.lineWidth = 0.25
                    linePath.stroke()

                    currentY += rowH
                    rowIndex += 1
                }

                currentY += 4 // gap between days
            }
        }

        return data
    }
}
