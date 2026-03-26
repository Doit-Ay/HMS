//
//  LabTestsSeeder.swift
//  HMS
//
//  Created by admin73 on 17/03/26.
//

import Foundation
import FirebaseFirestore

struct LabTest: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let price: Int
    let description: String
    let category: String
    let preparation: String
    let reportTime: String
    
    init(name: String, price: Int, description: String, category: String, preparation: String, reportTime: String) {
        self.name = name
        self.price = price
        self.description = description
        self.category = category
        self.preparation = preparation
        self.reportTime = reportTime
    }
}

// Seed Data - 30 essential lab tests
let sampleLabTests = [
    // Blood Tests (4)
    LabTest(
        name: "Complete Blood Count",
        price: 499,
        description: "Measures overall health and detects disorders like anemia, infection, and leukemia.",
        category: "Blood Test",
        preparation: "No special preparation required",
        reportTime: "6 hours"
    ),
    LabTest(
        name: "Hemoglobin Test",
        price: 199,
        description: "Measures hemoglobin levels to check for anemia and overall blood health.",
        category: "Blood Test",
        preparation: "No special preparation required",
        reportTime: "4 hours"
    ),
    LabTest(
        name: "ESR Test",
        price: 299,
        description: "Measures inflammation levels in the body and helps detect inflammatory conditions.",
        category: "Blood Test",
        preparation: "No special preparation required",
        reportTime: "6 hours"
    ),
    LabTest(
        name: "Peripheral Smear",
        price: 399,
        description: "Examines blood cells under microscope to detect abnormalities.",
        category: "Blood Test",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    
    // Diabetes Tests (3)
    LabTest(
        name: "Blood Sugar Test (Fasting)",
        price: 199,
        description: "Measures glucose levels in blood after fasting to screen for diabetes.",
        category: "Diabetes Test",
        preparation: "Fasting for 8-10 hours required",
        reportTime: "6 hours"
    ),
    LabTest(
        name: "Blood Sugar Test (Random)",
        price: 199,
        description: "Measures glucose levels at any time of day for diabetes screening.",
        category: "Diabetes Test",
        preparation: "No fasting required",
        reportTime: "4 hours"
    ),
    LabTest(
        name: "HbA1c Test",
        price: 599,
        description: "Measures average blood sugar levels over the past 2-3 months.",
        category: "Diabetes Test",
        preparation: "No special preparation required",
        reportTime: "24 hours"
    ),
    
    // Thyroid Tests (3)
    LabTest(
        name: "Thyroid Profile (T3, T4, TSH)",
        price: 699,
        description: "Comprehensive thyroid function test measuring T3, T4, and TSH levels.",
        category: "Thyroid Test",
        preparation: "Fasting for 8-10 hours recommended",
        reportTime: "24 hours"
    ),
    LabTest(
        name: "TSH Test",
        price: 399,
        description: "Measures Thyroid Stimulating Hormone levels for thyroid disorder screening.",
        category: "Thyroid Test",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "T3 & T4 Test",
        price: 599,
        description: "Measures Triiodothyronine and Thyroxine levels to evaluate thyroid function.",
        category: "Thyroid Test",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    
    // Lipid/Heart Health (4)
    LabTest(
        name: "Lipid Profile",
        price: 899,
        description: "Evaluates cholesterol levels including HDL, LDL, and triglycerides.",
        category: "Heart Health",
        preparation: "Fasting for 9-12 hours required",
        reportTime: "24 hours"
    ),
    LabTest(
        name: "HDL Cholesterol",
        price: 399,
        description: "Measures 'good' cholesterol levels for heart health assessment.",
        category: "Heart Health",
        preparation: "Fasting for 8-10 hours recommended",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "LDL Cholesterol",
        price: 399,
        description: "Measures 'bad' cholesterol levels to assess heart disease risk.",
        category: "Heart Health",
        preparation: "Fasting for 8-10 hours recommended",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "Triglycerides Test",
        price: 399,
        description: "Measures fat levels in blood to assess heart health risk.",
        category: "Heart Health",
        preparation: "Fasting for 8-10 hours required",
        reportTime: "12 hours"
    ),
    
    // Liver Function (4)
    LabTest(
        name: "Liver Function Test",
        price: 799,
        description: "Comprehensive analysis of liver health including enzymes and proteins.",
        category: "Liver Function",
        preparation: "Fasting for 8-10 hours recommended",
        reportTime: "24 hours"
    ),
    LabTest(
        name: "SGPT Test",
        price: 399,
        description: "Measures ALT enzyme levels to detect liver damage or inflammation.",
        category: "Liver Function",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "SGOT Test",
        price: 399,
        description: "Measures AST enzyme levels to assess liver and heart health.",
        category: "Liver Function",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "Bilirubin Test",
        price: 299,
        description: "Measures bilirubin levels to detect liver problems and jaundice.",
        category: "Liver Function",
        preparation: "Fasting for 4 hours recommended",
        reportTime: "12 hours"
    ),
    
    // Kidney Function (4)
    LabTest(
        name: "Kidney Function Test",
        price: 749,
        description: "Comprehensive analysis of kidney health including creatinine and urea.",
        category: "Kidney Function",
        preparation: "Fasting for 8-10 hours recommended",
        reportTime: "24 hours"
    ),
    LabTest(
        name: "Creatinine Test",
        price: 299,
        description: "Measures creatinine levels to assess kidney function.",
        category: "Kidney Function",
        preparation: "No special preparation required",
        reportTime: "8 hours"
    ),
    LabTest(
        name: "Blood Urea Nitrogen",
        price: 299,
        description: "Measures urea levels to evaluate kidney function.",
        category: "Kidney Function",
        preparation: "No special preparation required",
        reportTime: "8 hours"
    ),
    LabTest(
        name: "Uric Acid Test",
        price: 349,
        description: "Measures uric acid levels to detect gout and kidney issues.",
        category: "Kidney Function",
        preparation: "Fasting for 4-6 hours recommended",
        reportTime: "12 hours"
    ),
    
    // Vitamin Tests (3)
    LabTest(
        name: "Vitamin D (25-OH)",
        price: 1299,
        description: "Measures vitamin D levels to assess bone health and deficiency.",
        category: "Vitamin Test",
        preparation: "No special preparation required",
        reportTime: "48 hours"
    ),
    LabTest(
        name: "Vitamin B12",
        price: 899,
        description: "Checks vitamin B12 levels for anemia and neurological symptoms.",
        category: "Vitamin Test",
        preparation: "Fasting for 8 hours recommended",
        reportTime: "24 hours"
    ),
    LabTest(
        name: "Iron Studies",
        price: 599,
        description: "Evaluates iron levels, TIBC, and ferritin for anemia diagnosis.",
        category: "Iron Test",
        preparation: "Fasting for 8-10 hours required",
        reportTime: "24 hours"
    ),
    
    // Urine Tests (2)
    LabTest(
        name: "Urine Routine",
        price: 299,
        description: "Complete urine analysis for infections, kidney issues, and metabolic conditions.",
        category: "Urine Test",
        preparation: "First morning sample preferred",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "Urine Culture",
        price: 499,
        description: "Identifies bacterial infections in urinary tract with sensitivity analysis.",
        category: "Urine Test",
        preparation: "Clean catch mid-stream sample",
        reportTime: "48 hours"
    ),
    
    // Infection Tests (3)
    LabTest(
        name: "Dengue NS1 Antigen",
        price: 899,
        description: "Early detection of dengue virus infection.",
        category: "Infection Test",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    ),
    LabTest(
        name: "Malaria Antigen Test",
        price: 599,
        description: "Rapid detection of malaria parasite.",
        category: "Infection Test",
        preparation: "No special preparation required",
        reportTime: "6 hours"
    ),
    LabTest(
        name: "Typhoid Test (Widal)",
        price: 399,
        description: "Detects antibodies for typhoid fever diagnosis.",
        category: "Infection Test",
        preparation: "No special preparation required",
        reportTime: "12 hours"
    )
]

// Seeder Function
func seedLabTestsToFirebase(completion: @escaping (Bool, String) -> Void) {
    let db = Firestore.firestore()
    
    // Check if data already exists
    db.collection("labTests").limit(to: 1).getDocuments { snapshot, error in
        if let error = error {
            completion(false, "Error checking database: \(error.localizedDescription)")
            return
        }
        
        if let snapshot = snapshot, !snapshot.documents.isEmpty {
            completion(false, "Lab tests already exist in database")
            return
        }
        
        // Add sample data
        for test in sampleLabTests {
            do {
                try db.collection("labTests").addDocument(from: test) { error in
                    if let error = error {
                        #if DEBUG
                        print("Error adding \(test.name): \(error)")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("Error encoding \(test.name): \(error)")
                #endif
            }
        }
        
        completion(true, "\(sampleLabTests.count) lab tests seeded successfully!")
    }
}
