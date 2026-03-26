import Foundation
import UIKit
import PDFKit

class InvoicePDFGenerator {
    
    // Page dimensions (A4 size)
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 40.0
    
    private let primaryColor = UIColor(red: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)
    
    func generatePDF(invoice: HMSInvoice) -> URL? {
        let safeName = invoice.patientName.replacingOccurrences(of: " ", with: "_")
        let invoiceID = String(invoice.firestoreId.prefix(8)).uppercased()
        let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt_\(safeName)_\(invoiceID).pdf")
        
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextTitle: "Payment Receipt - \(invoice.patientName)",
            kCGPDFContextAuthor: "CureIt Hospital"
        ]
        format.documentInfo = metadata as [String: Any]
        
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        do {
            try renderer.writePDF(to: outputFileURL) { context in
                context.beginPage()
                var currentY: CGFloat = margin
                
                // 1. Header
                currentY = drawHeader(currentY: currentY, context: context)
                
                // 2. Receipt Title
                currentY = drawReceiptTitle(currentY: currentY, context: context)
                
                // 3. Invoice Details
                currentY = drawDetails(currentY: currentY, invoice: invoice, invoiceID: invoiceID, context: context)
                
                // 4. Amount Breakdown (Table of items + Subtotal/Tax + Total Paid)
                currentY = drawAmountSection(currentY: currentY, invoice: invoice, context: context)
                
                // 5. Footer
                drawFooter(context: context)
            }
            return outputFileURL
        } catch {
            #if DEBUG
            print("Failed to generate PDF: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawHeader(currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let hospitalName = "CureIt"
        let hospitalAddress = "Infosys, Mysore\nEmail: contact@cureit.com | Tel: +91 800 123 4567"
        
        let headerFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
        let addressFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        
        // Logo
        if let logo = UIImage(named: "CureIt_logo") {
            let logoWidth: CGFloat = 50
            let logoHeight: CGFloat = 50
            logo.draw(in: CGRect(x: margin, y: currentY, width: logoWidth, height: logoHeight))
            
            let nameX = margin + logoWidth + 12
            let hospitalNameString = NSAttributedString(string: hospitalName, attributes: [
                .font: headerFont, .foregroundColor: primaryColor
            ])
            hospitalNameString.draw(at: CGPoint(x: nameX, y: currentY))
            
            let addressString = NSAttributedString(string: hospitalAddress, attributes: [
                .font: addressFont, .foregroundColor: UIColor.darkGray
            ])
            addressString.draw(at: CGPoint(x: nameX, y: currentY + 34))
            
            return currentY + logoHeight + 30
        } else {
            let hospitalNameString = NSAttributedString(string: hospitalName, attributes: [
                .font: headerFont, .foregroundColor: primaryColor
            ])
            hospitalNameString.draw(at: CGPoint(x: margin, y: currentY))
            
            let addressString = NSAttributedString(string: hospitalAddress, attributes: [
                .font: addressFont, .foregroundColor: UIColor.darkGray
            ])
            addressString.draw(at: CGPoint(x: margin, y: currentY + 34))
            
            return currentY + 60
        }
    }
    
    private func drawReceiptTitle(currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let text = NSAttributedString(string: "PAYMENT RECEIPT", attributes: [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ])
        
        let textSize = text.size()
        let xPosition = (pageWidth - textSize.width) / 2.0
        text.draw(at: CGPoint(x: xPosition, y: currentY))
        
        // Underline
        let lineY = currentY + textSize.height + 8
        drawLine(y: lineY, context: context)
        
        return lineY + 20
    }
    
    private func drawDetails(currentY: CGFloat, invoice: HMSInvoice, invoiceID: String, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let valueFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let labelColor = UIColor.darkGray
        let valueColor = UIColor.black
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        let dateToUse = invoice.paidAt ?? invoice.date
        
        let details = [
            ("Receipt No:", invoiceID),
            ("Date:", dateFormatter.string(from: dateToUse)),
            ("Patient Name:", invoice.patientName),
            ("Payment Type:", "Hospital Bill")
        ]
        
        var y = currentY
        let col1X = margin
        let col2X = margin + 100
        
        for detail in details {
            let labelStr = NSAttributedString(string: detail.0, attributes: [.font: labelFont, .foregroundColor: labelColor])
            labelStr.draw(at: CGPoint(x: col1X, y: y))
            
            let valueStr = NSAttributedString(string: detail.1, attributes: [.font: valueFont, .foregroundColor: valueColor])
            valueStr.draw(at: CGPoint(x: col2X, y: y))
            
            y += 22
        }
        
        y += 10
        drawLine(y: y, context: context)
        return y + 20
    }
    
    private func drawAmountSection(currentY: CGFloat, invoice: HMSInvoice, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let headerFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let rowFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let totalFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        // Table Header
        let descHeader = NSAttributedString(string: "Description", attributes: [.font: headerFont])
        let amtHeader = NSAttributedString(string: "Amount", attributes: [.font: headerFont])
        
        let rightMargin = pageWidth - margin
        
        descHeader.draw(at: CGPoint(x: margin, y: currentY))
        
        let amtSize = amtHeader.size()
        amtHeader.draw(at: CGPoint(x: rightMargin - amtSize.width, y: currentY))
        
        var y = currentY + 24
        
        // Loop over items
        for item in invoice.items {
            if y > pageHeight - 150 {
                context.beginPage()
                y = margin
            }
            
            let quantityStr = item.quantity > 1 ? "\(item.quantity)x " : ""
            let descStr = NSAttributedString(string: quantityStr + item.name, attributes: [.font: rowFont])
            let amtStr = NSAttributedString(string: formatCurrency(item.amount), attributes: [.font: rowFont])
            
            descStr.draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2 - 80, height: 40))
            
            let amtStrSize = amtStr.size()
            amtStr.draw(at: CGPoint(x: rightMargin - amtStrSize.width, y: y))
            
            y += 24
        }
        
        // Subtotal and Tax
        if invoice.tax > 0 {
            y += 10
            let subtotalStr = NSAttributedString(string: "Subtotal:", attributes: [.font: rowFont, .foregroundColor: UIColor.gray])
            let subtotalAmt = NSAttributedString(string: formatCurrency(invoice.subTotal), attributes: [.font: rowFont, .foregroundColor: UIColor.gray])
            subtotalStr.draw(at: CGPoint(x: rightMargin - 150, y: y))
            subtotalAmt.draw(at: CGPoint(x: rightMargin - subtotalAmt.size().width, y: y))
            
            y += 20
            let taxStr = NSAttributedString(string: "Tax (5%):", attributes: [.font: rowFont, .foregroundColor: UIColor.gray])
            let taxAmt = NSAttributedString(string: formatCurrency(invoice.tax), attributes: [.font: rowFont, .foregroundColor: UIColor.gray])
            taxStr.draw(at: CGPoint(x: rightMargin - 150, y: y))
            taxAmt.draw(at: CGPoint(x: rightMargin - taxAmt.size().width, y: y))
            y += 20
        } else {
            y += 16
        }
        
        drawLine(y: y, context: context)
        
        y += 20
        
        if y > pageHeight - 100 {
            context.beginPage()
            y = margin
        }
        
        // Total row
        let totalLabel = NSAttributedString(string: "Total Paid:", attributes: [.font: totalFont])
        let totalValue = NSAttributedString(string: formatCurrency(invoice.totalAmount), attributes: [.font: totalFont, .foregroundColor: primaryColor])
        
        let totalValSize = totalValue.size()
        let totalLabelSize = totalLabel.size()
        
        let valX = rightMargin - totalValSize.width
        let labelX = valX - totalLabelSize.width - 20
        
        totalLabel.draw(at: CGPoint(x: labelX, y: y))
        totalValue.draw(at: CGPoint(x: valX, y: y))
        
        return y + 60
    }
    
    private func drawFooter(context: UIGraphicsPDFRendererContext) {
        let footerFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let text = NSAttributedString(string: "This is a computer generated receipt and does not require a physical signature.", attributes: [
            .font: footerFont,
            .foregroundColor: UIColor.lightGray
        ])
        
        let textSize = text.size()
        let xPosition = (pageWidth - textSize.width) / 2.0
        let yPosition = pageHeight - margin - textSize.height
        
        text.draw(at: CGPoint(x: xPosition, y: yPosition))
    }
    
    private func drawLine(y: CGFloat, context: UIGraphicsPDFRendererContext) {
        context.cgContext.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.5).cgColor)
        context.cgContext.setLineWidth(1)
        context.cgContext.move(to: CGPoint(x: margin, y: y))
        context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        context.cgContext.strokePath()
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "₹%.2f", value)
    }
}
