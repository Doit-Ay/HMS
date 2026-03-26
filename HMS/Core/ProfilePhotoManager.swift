import SwiftUI
import Combine
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

// MARK: - Profile Photo Manager
// Handles uploading profile photos to Firebase Storage and updating the user's Firestore document.
class ProfilePhotoManager: ObservableObject {
    static let shared = ProfilePhotoManager()
    
    @Published var isUploading = false
    @Published var uploadedImageURL: String? = nil
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    /// Upload a photo from PhotosPickerItem, store in Firebase Storage, and save URL to Firestore.
    /// Returns the download URL string on success.
    func uploadProfilePhoto(pickerItem: PhotosPickerItem, userId: String) async throws -> String {
        // 1. Load the image data
        guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
            throw NSError(domain: "ProfilePhoto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load image data"])
        }
        
        // 2. Compress the image
        guard let uiImage = UIImage(data: data),
              let compressed = uiImage.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "ProfilePhoto", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not process image"])
        }
        
        // 3. Upload to Firebase Storage
        let storageRef = storage.reference().child("profile_photos/\(userId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await storageRef.putDataAsync(compressed, metadata: metadata)
        
        // 4. Get download URL
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString
        
        // 5. Update Firestore user document
        try await db.collection("users").document(userId).updateData([
            "profileImageURL": urlString
        ])
        
        // 6. Update UserSession
        await MainActor.run {
            UserSession.shared.currentUser?.profileImageURL = urlString
        }
        
        print("✅ Profile photo uploaded: \(urlString)")
        return urlString
    }
}

// MARK: - Profile Photo View
// A reusable view that shows the profile photo circle with camera button overlay.
struct ProfilePhotoView: View {
    let initial: String
    let imageURL: String?
    let isEditing: Bool
    let isUploading: Bool
    @Binding var selectedItem: PhotosPickerItem?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(AppTheme.cardSurface)
                .frame(width: 110, height: 110)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
                .overlay(
                    Group {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(1.2)
                        } else if let url = imageURL, let imageUrl = URL(string: url) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Text(initial)
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primaryDark)
                                default:
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        } else {
                            Text(initial)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primaryDark)
                        }
                    }
                )
                .clipShape(Circle())
            
            if isEditing {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(AppTheme.cardSurface, lineWidth: 2))
                }
                .offset(x: -4, y: -4)
                .transition(.scale)
            }
        }
        .offset(y: 40)
    }
}
