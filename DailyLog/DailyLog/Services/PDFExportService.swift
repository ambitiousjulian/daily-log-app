import UIKit
import PDFKit
import CoreData

class PDFExportService {

    static func generatePDF(
        logs: [ParentingLog],
        context: NSManagedObjectContext
    ) -> Data {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
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

            // --- Page 1: Title & Summary ---
            startNewPage()

            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let headerFont = UIFont.boldSystemFont(ofSize: 16)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let smallFont = UIFont.systemFont(ofSize: 10)
            let boldBodyFont = UIFont.boldSystemFont(ofSize: 12)

            // Title
            let titleHeight = drawText(
                "PARENTING ACTIVITY REPORT",
                at: CGPoint(x: margin, y: currentY),
                font: titleFont
            )
            currentY += titleHeight + 8

            // Generated date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let generatedText = "Generated: \(dateFormatter.string(from: Date()))"
            let genHeight = drawText(
                generatedText,
                at: CGPoint(x: margin, y: currentY),
                font: smallFont,
                color: .gray
            )
            currentY += genHeight + 4

            // Date range
            if let oldest = logs.last?.timestamp, let newest = logs.first?.timestamp {
                let rangeText = "Period: \(dateFormatter.string(from: oldest)) — \(dateFormatter.string(from: newest))"
                let rangeHeight = drawText(
                    rangeText,
                    at: CGPoint(x: margin, y: currentY),
                    font: smallFont,
                    color: .gray
                )
                currentY += rangeHeight + 16
            } else {
                currentY += 16
            }

            drawHorizontalLine(y: currentY)
            currentY += 16

            // Summary section
            let summaryHeight = drawText(
                "Summary",
                at: CGPoint(x: margin, y: currentY),
                font: headerFont
            )
            currentY += summaryHeight + 10

            let totalText = "Total Activities: \(logs.count)"
            currentY += drawText(totalText, at: CGPoint(x: margin, y: currentY), font: bodyFont) + 6

            // Breakdown by category
            var categoryCounts: [String: Int] = [:]
            for log in logs {
                let cat = log.category ?? "unknown"
                categoryCounts[cat, default: 0] += 1
            }

            for category in LogCategory.allCases {
                let count = categoryCounts[category.rawValue] ?? 0
                if count > 0 {
                    let line = "\(category.emoji) \(category.displayName): \(count)"
                    let h = drawText(line, at: CGPoint(x: margin + 16, y: currentY), font: bodyFont)
                    currentY += h + 4
                }
            }

            currentY += 16
            drawHorizontalLine(y: currentY)
            currentY += 16

            // --- Timeline Section ---
            let timeHeight = drawText(
                "Timeline",
                at: CGPoint(x: margin, y: currentY),
                font: headerFont
            )
            currentY += timeHeight + 12

            // Group logs by day
            let calendar = Calendar.current
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

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

            // Render each day
            for (day, dayLogs) in groupedLogs {
                checkPageBreak(needed: 40)

                // Day header
                let dayHeight = drawText(
                    day,
                    at: CGPoint(x: margin, y: currentY),
                    font: boldBodyFont
                )
                currentY += dayHeight + 8

                for log in dayLogs {
                    let neededHeight: CGFloat = 30
                        + (log.note != nil && !(log.note?.isEmpty ?? true) ? 20 : 0)
                        + (log.photoData != nil ? 110 : 0)

                    checkPageBreak(needed: neededHeight)

                    guard let ts = log.timestamp else { continue }
                    let cat = LogCategory(rawValue: log.category ?? "") ?? .activity
                    let timeStr = timeFormatter.string(from: ts)

                    // Time + Category line
                    var entryLine = "\(timeStr) — \(cat.emoji) \(cat.displayName)"
                    if let sub = log.subcategory, !sub.isEmpty {
                        entryLine += " (\(sub))"
                    }
                    if let amount = log.amount, amount != 0 {
                        entryLine += " — $\(amount)"
                    }

                    let entryHeight = drawText(
                        entryLine,
                        at: CGPoint(x: margin + 8, y: currentY),
                        font: bodyFont
                    )
                    currentY += entryHeight + 2

                    // Note
                    if let note = log.note, !note.isEmpty {
                        let noteHeight = drawText(
                            note,
                            at: CGPoint(x: margin + 24, y: currentY),
                            font: smallFont,
                            color: .darkGray,
                            maxWidth: contentWidth - 24
                        )
                        currentY += noteHeight + 2
                    }

                    // Photo
                    if let photoData = log.photoData, let image = UIImage(data: photoData) {
                        checkPageBreak(needed: 110)
                        let maxPhotoWidth: CGFloat = 100
                        let maxPhotoHeight: CGFloat = 100
                        let aspectRatio = image.size.width / image.size.height
                        let photoWidth: CGFloat
                        let photoHeight: CGFloat
                        if aspectRatio > 1 {
                            photoWidth = min(maxPhotoWidth, image.size.width)
                            photoHeight = photoWidth / aspectRatio
                        } else {
                            photoHeight = min(maxPhotoHeight, image.size.height)
                            photoWidth = photoHeight * aspectRatio
                        }
                        let photoRect = CGRect(
                            x: margin + 24,
                            y: currentY,
                            width: photoWidth,
                            height: photoHeight
                        )
                        image.draw(in: photoRect)
                        currentY += photoHeight + 4
                    }

                    currentY += 8
                }

                currentY += 8
            }
        }

        return data
    }
}
