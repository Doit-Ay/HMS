import Foundation
import UIKit
import PDFKit

class RevenuePDFGenerator {
    
    // Page dimensions (A4 size)
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 40.0
    
    func generatePDF(transaction: RevenueTransaction) -> URL? {
        let safeName = transaction.patientName.replacingOccurrences(of: " ", with: "_")
        let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt_\(safeName)_\(transaction.id.prefix(6)).pdf")
        
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextTitle: "Payment Receipt - \(transaction.patientName)",
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
                
                // 3. Transaction Details
                currentY = drawDetails(currentY: currentY, transaction: transaction, context: context)
                
                // 4. Amount Breakdown
                currentY = drawAmountSection(currentY: currentY, transaction: transaction, context: context)
                
                // 5. Footer
                drawFooter(context: context)
            }
            return outputFileURL
        } catch {
            print("Failed to generate Revenue PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Drawing Helpers
    
    private func drawHeader(currentY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let hospitalName = "CureIt"
        let hospitalAddress = "Infosys, Mysore\nEmail: contact@cureit.com | Tel: +91 800 123 4567"
        
        let headerFont = UIFont.systemFont(ofSize: 28, weight: .heavy)
        let addressFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let primaryColor = UIColor(red: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)
        
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
        }
        return currentY
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
    
    private func drawDetails(currentY: CGFloat, transaction: RevenueTransaction, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let valueFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let labelColor = UIColor.darkGray
        let valueColor = UIColor.black
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        let details = [
            ("Receipt No:", transaction.id.uppercased()),
            ("Date:", dateFormatter.string(from: transaction.date)),
            ("Patient Name:", transaction.patientName),
            ("Payment Type:", transaction.type.label)
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
    
    private func drawAmountSection(currentY: CGFloat, transaction: RevenueTransaction, context: UIGraphicsPDFRendererContext) -> CGFloat {
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
        
        // The item row
        let descStr = NSAttributedString(string: transaction.description, attributes: [.font: rowFont])
        let amtStr = NSAttributedString(string: String(format: "₹%.2f", transaction.amount), attributes: [.font: rowFont])
        
        descStr.draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2 - 80, height: 40))
        
        let amtStrSize = amtStr.size()
        amtStr.draw(at: CGPoint(x: rightMargin - amtStrSize.width, y: y))
        
        y += 40
        drawLine(y: y, context: context)
        
        y += 20
        
        // Total row
        let totalLabel = NSAttributedString(string: "Total Paid:", attributes: [.font: totalFont])
        let totalValue = NSAttributedString(string: String(format: "₹%.2f", transaction.amount), attributes: [.font: totalFont, .foregroundColor: UIColor(red: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)])
        
        let totalLabelSize = totalLabel.size()
        totalLabel.draw(at: CGPoint(x: rightMargin - 150, y: y))
        
        let totalValSize = totalValue.size()
        totalValue.draw(at: CGPoint(x: rightMargin - totalValSize.width, y: y))
        
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
}
