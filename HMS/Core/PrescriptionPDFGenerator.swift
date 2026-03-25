import Foundation
import UIKit
import PDFKit

class PrescriptionPDFGenerator {
    
    // Page dimensions (A4 size)
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 40.0
    
    private let primaryColor = UIColor(red: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)
    
    func generatePDF(
        note: ConsultationNote,
        labTests: [LabTestRequest],
        prescribedMedicines: [PrescribedMedicine] = [],
        patientAge: String? = nil,
        patientGender: String? = nil
    ) -> URL? {
        let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Prescription_\(note.patientName.replacingOccurrences(of: " ", with: "_")).pdf")
        
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextTitle: "Prescription - \(note.patientName)",
            kCGPDFContextAuthor: note.doctorName
        ]
        format.documentInfo = metadata as [String: Any]
        
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        do {
            try renderer.writePDF(to: outputFileURL) { context in
                context.beginPage()
                
                var currentY: CGFloat = margin
                
                // 1. Draw Header (Hospital Info)
                currentY = drawHeader(currentY: currentY, context: context)
                
                // 2. Draw Patient & Doctor Details
                currentY = drawDetails(currentY: currentY, note: note, patientAge: patientAge, patientGender: patientGender, context: context)
                
                // 3. Draw Consultation Notes / Findings
                if !note.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    currentY = drawSectionHeader(title: "Clinical Notes & Findings", currentY: currentY, context: context)
                    currentY = drawText(text: note.notes, currentY: currentY, context: context)
                }
                
                // 4. Draw Prescription (Rx) text
                if !note.prescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    currentY = drawRxSection(currentY: currentY, context: context)
                    currentY = drawText(text: note.prescription, currentY: currentY, context: context)
                }
                
                // 5. Draw Prescribed Medicines Table
                if !prescribedMedicines.isEmpty {
                    currentY = drawMedicinesTable(medicines: prescribedMedicines, currentY: currentY, context: context)
                }
                
                // 6. Draw Lab Tests — ONLY if there are actual test names
                let allTestNames = labTests.flatMap { $0.testNames }
                if !allTestNames.isEmpty {
                    currentY = drawSectionHeader(title: "Recommended Lab Tests", currentY: currentY, context: context)
                    let testsText = allTestNames.map { "• \($0)" }.joined(separator: "\n")
                    currentY = drawText(text: testsText, currentY: currentY, context: context)
                }
                
                // 7. Draw Footer (Signatures)
                drawFooter(context: context, doctorName: note.doctorName)
            }
            return outputFileURL
        } catch {
            print("Failed to generate PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawHeader(currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let hospitalName = "CureIt"
        let hospitalAddress = "Infosys, Mysore\nEmail: contact@cureit.com | Tel: +91 800 123 4567"
        
        let headerFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
        let addressFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        
        if let logo = UIImage(named: "CureIt_logo") {
            let logoWidth: CGFloat = 50
            let logoHeight: CGFloat = 50
            logo.draw(in: CGRect(x: margin, y: currentY, width: logoWidth, height: logoHeight))
            
            let nameX = margin + logoWidth + 12
            let hospitalNameString = NSAttributedString(string: hospitalName, attributes: [
                .font: headerFont,
                .foregroundColor: primaryColor
            ])
            hospitalNameString.draw(at: CGPoint(x: nameX, y: currentY + 4))
            
            let addressString = NSAttributedString(string: hospitalAddress, attributes: [
                .font: addressFont,
                .foregroundColor: UIColor.darkGray
            ])
            addressString.draw(at: CGPoint(x: nameX, y: currentY + 36))
            
            let headerBottom = currentY + logoHeight
            let lineY = headerBottom + 15
            context.cgContext.setStrokeColor(primaryColor.cgColor)
            context.cgContext.setLineWidth(2.0)
            context.cgContext.move(to: CGPoint(x: margin, y: lineY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
            context.cgContext.strokePath()
            
            return lineY + 15
        } else {
            let hospitalNameString = NSAttributedString(string: hospitalName, attributes: [
                .font: headerFont,
                .foregroundColor: primaryColor
            ])
            hospitalNameString.draw(at: CGPoint(x: margin, y: currentY))
            
            let addressString = NSAttributedString(string: hospitalAddress, attributes: [
                .font: addressFont,
                .foregroundColor: UIColor.darkGray
            ])
            addressString.draw(at: CGPoint(x: margin, y: currentY + 34))
            
            let lineY = currentY + 60
            context.cgContext.setStrokeColor(primaryColor.cgColor)
            context.cgContext.setLineWidth(2.0)
            context.cgContext.move(to: CGPoint(x: margin, y: lineY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
            context.cgContext.strokePath()
            
            return lineY + 15
        }
    }
    
    private func drawDetails(currentY: CGFloat, note: ConsultationNote, patientAge: String?, patientGender: String?, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let detailsFont = UIFont.systemFont(ofSize: 11)
        let boldFont = UIFont.boldSystemFont(ofSize: 11)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        let dateStr = formatter.string(from: note.createdAt ?? Date())
        
        let detailsRect = CGRect(x: margin, y: currentY, width: pageWidth - (margin * 2), height: 75)
        let path = UIBezierPath(roundedRect: detailsRect, cornerRadius: 8)
        primaryColor.withAlphaComponent(0.05).setFill()
        path.fill()
        
        let padding: CGFloat = 12
        var ptY = currentY + padding
        
        drawDetailRow(title: "Patient Name: ", value: note.patientName, x: margin + padding, y: ptY, boldFont: boldFont, regFont: detailsFont)
        ptY += 18
        if let age = patientAge {
            drawDetailRow(title: "Age: ", value: age, x: margin + padding, y: ptY, boldFont: boldFont, regFont: detailsFont)
            ptY += 18
        }
        drawDetailRow(title: "Patient ID: ", value: String(note.patientId.prefix(8).uppercased()), x: margin + padding, y: ptY, boldFont: boldFont, regFont: detailsFont)
        
        let rightColX = pageWidth / 2
        var drY = currentY + padding
        drawDetailRow(title: "Doctor: ", value: "Dr. " + note.doctorName, x: rightColX, y: drY, boldFont: boldFont, regFont: detailsFont)
        drY += 18
        drawDetailRow(title: "Date: ", value: dateStr, x: rightColX, y: drY, boldFont: boldFont, regFont: detailsFont)
        
        return currentY + 75 + 20
    }
    
    private func drawDetailRow(title: String, value: String, x: CGFloat, y: CGFloat, boldFont: UIFont, regFont: UIFont) {
        let titleAttr = NSAttributedString(string: title, attributes: [.font: boldFont])
        let valueAttr = NSAttributedString(string: value, attributes: [.font: regFont])
        
        titleAttr.draw(at: CGPoint(x: x, y: y))
        valueAttr.draw(at: CGPoint(x: x + titleAttr.size().width, y: y))
    }
    
    private func drawSectionHeader(title: String, currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        let rect = CGRect(x: margin, y: currentY, width: pageWidth - (margin * 2), height: 26)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        primaryColor.withAlphaComponent(0.12).setFill()
        path.fill()
        
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: primaryColor]
        let string = NSAttributedString(string: "  " + title.uppercased(), attributes: attributes)
        
        string.draw(in: CGRect(x: margin, y: currentY + 4, width: pageWidth - (margin * 2), height: 20))
        return currentY + 36
    }
    
    private func drawRxSection(currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let rxFont = UIFont.boldSystemFont(ofSize: 24)
        let rxString = NSAttributedString(string: "Rx", attributes: [.font: rxFont])
        rxString.draw(at: CGPoint(x: margin, y: currentY))
        
        return currentY + rxString.size().height + 10
    }
    
    // MARK: - Medicines Table
    
    private func drawMedicinesTable(medicines: [PrescribedMedicine], currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = currentY
        
        // Section Header
        y = drawSectionHeader(title: "Prescribed Medicines", currentY: y, context: context)
        
        let tableWidth = pageWidth - (margin * 2)
        let colWidths: [CGFloat] = [
            tableWidth * 0.05,  // #
            tableWidth * 0.33,  // Medicine Name
            tableWidth * 0.15,  // Type
            tableWidth * 0.22,  // Frequency
            tableWidth * 0.25   // Duration
        ]
        
        let headerFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let cellFont = UIFont.systemFont(ofSize: 10)
        let rowHeight: CGFloat = 22
        let headers = ["#", "Medicine", "Type", "Frequency", "Duration"]
        
        // Check page overflow for header + at least 1 row
        if y + rowHeight * 2 > pageHeight - 100 {
            context.beginPage()
            y = margin
        }
        
        // Draw header row background
        let headerRect = CGRect(x: margin, y: y, width: tableWidth, height: rowHeight)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 4)
        primaryColor.withAlphaComponent(0.15).setFill()
        headerPath.fill()
        
        // Draw header text
        var xOffset: CGFloat = margin
        for (i, header) in headers.enumerated() {
            let attr = NSAttributedString(string: header, attributes: [.font: headerFont, .foregroundColor: primaryColor])
            attr.draw(at: CGPoint(x: xOffset + 6, y: y + 5))
            xOffset += colWidths[i]
        }
        y += rowHeight
        
        // Draw rows
        for (index, med) in medicines.enumerated() {
            // Page overflow check
            if y + rowHeight > pageHeight - 100 {
                context.beginPage()
                y = margin
            }
            
            // Alternating row background
            if index % 2 == 0 {
                let rowRect = CGRect(x: margin, y: y, width: tableWidth, height: rowHeight)
                UIColor(white: 0.95, alpha: 1.0).setFill()
                UIBezierPath(rect: rowRect).fill()
            }
            
            let freqStr = med.timesPerDay == 1 ? "Once daily" :
                          med.timesPerDay == 2 ? "Twice daily" : "\(med.timesPerDay)x daily"
            let durationStr = "\(med.durationDays) day\(med.durationDays == 1 ? "" : "s")"
            
            let cells = [
                "\(index + 1)",
                med.medicineName,
                med.medicineType.displayName,
                freqStr,
                durationStr
            ]
            
            xOffset = margin
            for (i, text) in cells.enumerated() {
                let maxW = colWidths[i] - 10
                let truncated = truncateString(text, font: cellFont, maxWidth: maxW)
                let truncAttr = NSAttributedString(string: truncated, attributes: [.font: cellFont, .foregroundColor: UIColor.black])
                truncAttr.draw(at: CGPoint(x: xOffset + 6, y: y + 5))
                xOffset += colWidths[i]
            }
            y += rowHeight
        }
        
        // Bottom border
        context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: margin, y: y))
        context.cgContext.addLine(to: CGPoint(x: margin + tableWidth, y: y))
        context.cgContext.strokePath()
        
        return y + 20
    }
    
    private func truncateString(_ str: String, font: UIFont, maxWidth: CGFloat) -> String {
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        let size = (str as NSString).size(withAttributes: attr)
        if size.width <= maxWidth { return str }
        
        var truncated = str
        while truncated.count > 1 {
            truncated = String(truncated.dropLast())
            let newSize = ((truncated + "…") as NSString).size(withAttributes: attr)
            if newSize.width <= maxWidth {
                return truncated + "…"
            }
        }
        return str
    }
    
    private func drawText(text: String, currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        let maxWidth = pageWidth - (margin * 2)
        
        let bBox = string.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            context: nil
        )
        
        if currentY + bBox.height > pageHeight - 100 {
            context.beginPage()
            let newY = margin
            string.draw(in: CGRect(x: margin, y: newY, width: maxWidth, height: bBox.height))
            return newY + bBox.height + 20
        }
        
        string.draw(in: CGRect(x: margin, y: currentY, width: maxWidth, height: bBox.height))
        return currentY + bBox.height + 20
    }
    
    private func drawFooter(context: UIGraphicsPDFRendererContext, doctorName: String) {
        let signatureY = pageHeight - 120
        
        context.cgContext.setStrokeColor(UIColor.black.cgColor)
        context.cgContext.setLineWidth(1.0)
        context.cgContext.move(to: CGPoint(x: pageWidth - margin - 150, y: signatureY))
        context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: signatureY))
        context.cgContext.strokePath()
        
        let font = UIFont.systemFont(ofSize: 10)
        let docStr = NSAttributedString(string: "Dr. \(doctorName)", attributes: [.font: font])
        let docSize = docStr.size()
        let docX = (pageWidth - margin - 75) - (docSize.width / 2)
        docStr.draw(at: CGPoint(x: docX, y: signatureY + 5))
        
        let disclaimer = "This is a system generated document and does not require a physical signature."
        let disAttr = NSAttributedString(string: disclaimer, attributes: [.font: UIFont.italicSystemFont(ofSize: 8), .foregroundColor: UIColor.gray])
        let disSize = disAttr.size()
        disAttr.draw(at: CGPoint(x: (pageWidth - disSize.width) / 2, y: pageHeight - margin))
    }
}
