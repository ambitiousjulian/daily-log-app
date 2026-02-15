import UIKit
import PDFKit
import CoreData

class PDFExportService {

    static func generatePDF(
        logs: [ParentingLog],
        context: NSManagedObjectContext
    ) -> Data {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36       // 0.5 inch margins
        let contentWidth = pageWidth - (margin * 2)

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

            func drawText(
                _ text: String,
                at point: CGPoint,
                font: UIFont,
                color: UIColor = .black,
                maxWidth: CGFloat? = nil
            ) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let drawWidth = maxWidth ?? contentWidth
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: point.x, y: point.y, width: drawWidth, height: boundingRect.height),
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

            // --- Fonts ---
            let titleFont = UIFont.boldSystemFont(ofSize: 16)
            let headerFont = UIFont.boldSystemFont(ofSize: 11)
            let bodyFont = UIFont.systemFont(ofSize: 9.5)
            let smallFont = UIFont.systemFont(ofSize: 8)
            let boldSmall = UIFont.boldSystemFont(ofSize: 9.5)

            // --- Page 1: Header + Summary ---
            startNewPage()

            let titleHeight = drawText(
                "PARENTING ACTIVITY REPORT",
                at: CGPoint(x: margin, y: currentY),
                font: titleFont
            )
            currentY += titleHeight + 4

            // Generated date + range on one line where possible
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            var metaLine = "Generated \(dateFormatter.string(from: Date()))"
            if let oldest = logs.last?.timestamp, let newest = logs.first?.timestamp {
                metaLine += "  ·  \(dateFormatter.string(from: oldest)) — \(dateFormatter.string(from: newest))"
            }
            currentY += drawText(metaLine, at: CGPoint(x: margin, y: currentY), font: smallFont, color: .gray) + 6

            drawHorizontalLine(y: currentY)
            currentY += 8

            // Compact summary — single line per category, two columns
            currentY += drawText("Summary (\(logs.count) total)", at: CGPoint(x: margin, y: currentY), font: headerFont) + 4

            var categoryCounts: [String: Int] = [:]
            for log in logs {
                categoryCounts[log.category ?? "unknown", default: 0] += 1
            }

            let activeCats = LogCategory.allCases.filter { (categoryCounts[$0.rawValue] ?? 0) > 0 }
            let colWidth = contentWidth / 2
            var col = 0

            for category in activeCats {
                let count = categoryCounts[category.rawValue] ?? 0
                let x = margin + CGFloat(col) * colWidth
                let line = "\(category.emoji) \(category.displayName): \(count)"
                let h = drawText(line, at: CGPoint(x: x, y: currentY), font: bodyFont, maxWidth: colWidth - 8)
                if col == 1 {
                    currentY += h + 2
                    col = 0
                } else {
                    col = 1
                }
            }
            // If we ended on the left column, advance past the last row
            if col == 1 {
                currentY += 12
            }

            currentY += 6
            drawHorizontalLine(y: currentY)
            currentY += 8

            // --- Timeline ---
            currentY += drawText("Timeline", at: CGPoint(x: margin, y: currentY), font: headerFont) + 6

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            // Group logs by day
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

            for (day, dayLogs) in groupedLogs {
                checkPageBreak(needed: 28)

                // Day header — subtle background bar
                let dayHeight = drawText(day, at: CGPoint(x: margin + 4, y: currentY + 1), font: boldSmall)
                let barRect = CGRect(x: margin, y: currentY - 1, width: contentWidth, height: dayHeight + 3)
                UIColor(white: 0.93, alpha: 1).setFill()
                UIBezierPath(roundedRect: barRect, cornerRadius: 2).fill()
                // Re-draw text on top of bar
                _ = drawText(day, at: CGPoint(x: margin + 4, y: currentY + 1), font: boldSmall)
                currentY += dayHeight + 6

                for log in dayLogs {
                    guard let ts = log.timestamp else { continue }
                    let cat = LogCategory(rawValue: log.category ?? "") ?? .activity
                    let timeStr = timeFormatter.string(from: ts)
                    let hasNote = log.note != nil && !(log.note?.isEmpty ?? true)
                    let hasPhoto = log.photoData != nil

                    // Estimate height needed
                    let neededHeight: CGFloat = 14
                        + (hasNote ? 12 : 0)
                        + (hasPhoto ? 54 : 0)
                    checkPageBreak(needed: neededHeight)

                    // Build entry text: "9:41 AM — 🍼 Feeding (Bottle) — $12.50"
                    var entryLine = "\(timeStr)  \(cat.emoji) \(cat.displayName)"
                    if let sub = log.subcategory, !sub.isEmpty {
                        entryLine += " (\(sub))"
                    }
                    if let amount = log.amount, amount != 0 {
                        entryLine += " — $\(amount)"
                    }

                    let entryHeight = drawText(
                        entryLine,
                        at: CGPoint(x: margin + 6, y: currentY),
                        font: bodyFont
                    )
                    currentY += entryHeight + 1

                    // Note — compact, indented
                    if hasNote, let note = log.note {
                        let noteHeight = drawText(
                            note,
                            at: CGPoint(x: margin + 16, y: currentY),
                            font: smallFont,
                            color: .darkGray,
                            maxWidth: contentWidth - 16
                        )
                        currentY += noteHeight + 1
                    }

                    // Photo — small thumbnail (50x50 max)
                    if let photoData = log.photoData, let image = UIImage(data: photoData) {
                        checkPageBreak(needed: 54)
                        let maxDim: CGFloat = 50
                        let aspectRatio = image.size.width / image.size.height
                        let photoWidth: CGFloat
                        let photoHeight: CGFloat
                        if aspectRatio > 1 {
                            photoWidth = maxDim
                            photoHeight = maxDim / aspectRatio
                        } else {
                            photoHeight = maxDim
                            photoWidth = maxDim * aspectRatio
                        }
                        let photoRect = CGRect(
                            x: margin + 16,
                            y: currentY,
                            width: photoWidth,
                            height: photoHeight
                        )
                        image.draw(in: photoRect)
                        currentY += photoHeight + 2
                    }

                    currentY += 4  // gap between entries
                }

                currentY += 4  // gap between days
            }
        }

        return data
    }
}
