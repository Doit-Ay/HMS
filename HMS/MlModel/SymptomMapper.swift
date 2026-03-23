//
//  SymptomMapper.swift
//  HMS
//
//  Created by satakshi on 17/03/26.
//

import Foundation

// MARK: - Department Match Result
struct DepartmentMatch {
    let department: String
    let confidence: Int         // total keyword score
    let matchedKeywords: [String]

    var isConfident: Bool {
        confidence >= 2         // at least one strong keyword matched
    } 
}

// MARK: - Symptom Mapper
// Keyword-based fallback for when Core ML confidence is low.
// Add or edit keywords here any time — no retraining needed.

final class SymptomMapper {

    static let shared = SymptomMapper()
    private init() {}

    // weight 2 = strong/specific keyword
    // weight 1 = general keyword (shared across departments)
    private let departmentKeywords: [String: [String: Int]] = [

        "Dermatology": [
            "acne": 2, "pimple": 2, "blackhead": 2, "whitehead": 2,
            "rosacea": 2, "eczema": 2, "psoriasis": 2, "vitiligo": 2,
            "dermatitis": 2, "hives": 2, "rash": 2, "skin": 2,
            "itching": 2, "scalp": 2, "dandruff": 2, "hair loss": 2,
            "nail": 2, "ringworm": 2, "fungal": 2, "wart": 2,
            "mole": 2, "pigmentation": 2, "sunburn": 2, "blister": 2,
            "boil": 2, "scabies": 2, "birthmark": 2, "dry skin": 2,
            "oily skin": 2, "peeling": 1, "flaky": 1, "bump": 1,
            "cyst": 1, "scar": 1, "wound": 1
        ],

        "Cardiology": [
            "chest pain": 2, "palpitation": 2, "heartbeat": 2,
            "heart rate": 2, "blood pressure": 2, "hypertension": 2,
            "cholesterol": 2, "cardiac": 2, "ecg": 2, "echocardiogram": 2,
            "stent": 2, "bypass": 2, "pacemaker": 2, "afib": 2,
            "atrial fibrillation": 2, "tachycardia": 2, "bradycardia": 2,
            "heart failure": 2, "angina": 2, "dvt": 2, "pulse": 2,
            "swollen ankle": 2, "swollen leg": 2, "arrhythmia": 2,
            "breathless": 1, "fainting": 1, "blackout": 1,
            "dizziness": 1, "clot": 1
        ],

        "General Medicine": [
            "fever": 2, "cold": 2, "cough": 2, "flu": 2,
            "fatigue": 2, "weakness": 2, "diabetes": 2, "blood sugar": 2,
            "thyroid": 2, "anaemia": 2, "anemia": 2, "malaria": 2,
            "dengue": 2, "typhoid": 2, "checkup": 2, "blood test": 2,
            "weight loss": 2, "jaundice": 2, "lymph node": 2,
            "vitamin": 2, "b12": 2, "body ache": 2, "sore throat": 2,
            "runny nose": 2, "loose stool": 2, "appetite": 1,
            "vomiting": 1, "nausea": 1, "tiredness": 1
        ],

        "Orthopedics": [
            "back pain": 2, "knee pain": 2, "joint pain": 2,
            "fracture": 2, "sprain": 2, "ligament": 2, "tendon": 2,
            "shoulder pain": 2, "neck pain": 2, "hip pain": 2,
            "ankle pain": 2, "sciatica": 2, "disc": 2, "spine": 2,
            "arthritis": 2, "osteoporosis": 2, "gout": 2,
            "carpal tunnel": 2, "scoliosis": 2, "frozen shoulder": 2,
            "acl": 2, "meniscus": 2, "plantar": 2, "bone": 2,
            "muscle": 1, "stiffness": 1, "swelling": 1, "injury": 1
        ],

        "Neurology": [
            "headache": 2, "migraine": 2, "seizure": 2, "epilepsy": 2,
            "stroke": 2, "numbness": 2, "tingling": 2, "tremor": 2,
            "parkinson": 2, "alzheimer": 2, "dementia": 2, "memory loss": 2,
            "multiple sclerosis": 2, "vertigo": 2, "neuropathy": 2,
            "nerve pain": 2, "tia": 2, "bell palsy": 2, "meningitis": 2,
            "brain": 2, "paralysis": 2, "slurred speech": 2, "fits": 2,
            "cluster headache": 2, "restless legs": 2,
            "confusion": 1, "balance": 1, "blackout": 1,
            "unconscious": 1, "ms": 1
        ],

        "Ophthalmology": [
            "eye": 2, "vision": 2, "blurry": 2, "cataract": 2,
            "glaucoma": 2, "retina": 2, "lasik": 2, "glasses": 2,
            "conjunctivitis": 2, "pink eye": 2, "stye": 2, "floater": 2,
            "double vision": 2, "dry eye": 2, "watery eye": 2,
            "squint": 2, "macular": 2, "optic": 2, "cornea": 2,
            "eyelid": 2, "eye pain": 2, "night blind": 2,
            "light sensitive": 2, "blind": 2, "lens": 1
        ],

        "ENT": [
            "ear": 2, "hearing": 2, "tinnitus": 2, "tonsil": 2,
            "sinus": 2, "nose": 2, "throat": 2, "hoarse": 2,
            "voice": 2, "snoring": 2, "sleep apnea": 2, "nosebleed": 2,
            "nasal": 2, "adenoid": 2, "earache": 2, "ear infection": 2,
            "blocked ear": 2, "polyp": 2, "septum": 2, "vocal cord": 2,
            "larynx": 2, "postnasal": 2, "anosmia": 2, "quinsy": 2,
            "wax": 1, "smell": 1, "taste": 1, "mucus": 1,
            "phlegm": 1, "vertigo": 1
        ],

        "Psychiatry": [
            "anxiety": 2, "depression": 2, "panic": 2, "stress": 2,
            "insomnia": 2, "ocd": 2, "obsessive": 2, "phobia": 2,
            "adhd": 2, "bipolar": 2, "schizophrenia": 2, "psychosis": 2,
            "hallucination": 2, "ptsd": 2, "trauma": 2, "addiction": 2,
            "self harm": 2, "suicidal": 2, "eating disorder": 2,
            "anorexia": 2, "mental health": 2, "counselling": 2,
            "burnout": 2, "paranoia": 2, "delusion": 2, "bulimia": 2,
            "mood": 1, "sleep": 1, "withdrawn": 1, "therapy": 1
        ],

        "Gynaecology": [
            "period": 2, "menstrual": 2, "menopause": 2, "pcos": 2,
            "ovary": 2, "uterus": 2, "cervical": 2, "vaginal": 2,
            "pregnancy": 2, "pregnant": 2, "prenatal": 2, "fertility": 2,
            "contraception": 2, "breast lump": 2, "fibroids": 2,
            "endometriosis": 2, "discharge": 2, "pelvic pain": 2,
            "hot flash": 2, "ivf": 2, "miscarriage": 2, "ectopic": 2,
            "prolapse": 2, "smear": 2, "gynaecology": 2, "gynecology": 2,
            "cramp": 1, "irregular": 1
        ],

        "Paediatrics": [
            "child": 2, "baby": 2, "infant": 2, "toddler": 2,
            "newborn": 2, "kid": 2, "vaccination": 2, "immunisation": 2,
            "milestone": 2, "colic": 2, "paediatric": 2, "pediatric": 2,
            "chickenpox": 2, "measles": 2, "bedwetting": 2, "cradle cap": 2,
            "son": 1, "daughter": 1, "development": 1, "feeding": 1,
            "growth": 1, "school": 1, "teenager": 1, "autism": 1
        ],

        "Urology": [
            "urination": 2, "urine": 2, "bladder": 2, "kidney": 2,
            "prostate": 2, "kidney stone": 2, "blood in urine": 2,
            "uti": 2, "erectile": 2, "testicle": 2, "testicular": 2,
            "incontinence": 2, "frequent urination": 2, "renal": 2,
            "dialysis": 2, "vasectomy": 2, "hydrocele": 2, "varicocele": 2,
            "psa": 2, "catheter": 2, "overactive bladder": 2, "sperm": 2,
            "flank pain": 2, "burning urination": 2, "foamy urine": 2,
            "groin pain": 1
        ]
    ]

    var allSymptoms: [String] {
        var uniqueSymptoms = Set<String>()
        for (_, keywords) in departmentKeywords {
            for (word, _) in keywords {
                uniqueSymptoms.insert(word.capitalized)
            }
        }
        return Array(uniqueSymptoms).sorted()
    }

    // MARK: - Public API

    /// Returns all matching departments sorted by confidence, highest first
    func findDepartments(for input: String) -> [DepartmentMatch] {
        let lowercased = input.lowercased()
        var scores: [String: (score: Int, keywords: [String])] = [:]

        for (department, keywords) in departmentKeywords {
            var totalScore = 0
            var matched: [String] = []
            for (keyword, weight) in keywords {
                if lowercased.contains(keyword) {
                    totalScore += weight
                    matched.append(keyword)
                }
            }
            if totalScore > 0 {
                scores[department] = (totalScore, matched)
            }
        }

        return scores
            .map { DepartmentMatch(department: $0.key, confidence: $0.value.score, matchedKeywords: $0.value.keywords) }
            .sorted { $0.confidence > $1.confidence }
    }

    /// Returns the single best matching department.
    /// Falls back to General Medicine if nothing matches.
    func topDepartment(for input: String) -> DepartmentMatch {
        findDepartments(for: input).first ?? DepartmentMatch(
            department: "General Medicine",
            confidence: 0,
            matchedKeywords: []
        )
    }
}
