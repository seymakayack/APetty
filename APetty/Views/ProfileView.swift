import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct ProfileView: View {
    @AppStorage("uid") var userID: String = "" // Kullanıcı ID'si @AppStorage'dan alınıyor
    @State private var profileImage: UIImage? = nil
    @State private var fullName: String = ""
    @State private var blockNumber: String = ""
    @State private var floorNumber: String = ""
    @State private var chosenAnimals: [String] = []
    
    @State private var isImagePickerPresented: Bool = false // State to control image picker presentation
    @State private var isLoading: Bool = false // State to control loading indicator

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    var body: some View {
        VStack {
            Spacer()
            
            // Profil Fotoğrafı
            Button(action: {
                isImagePickerPresented = true // Show the image picker
            }) {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.green, lineWidth: 4))
                        .frame(width: 150, height: 150)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .overlay(Text("Add Photo").foregroundColor(.white))
                }
            }
            .padding()
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $profileImage)
                    .onDisappear {
                        if let image = profileImage {
                            uploadProfileImage(image)
                        }
                    }
            } // Present the image picker

            // Profil Bilgileri
            VStack(alignment: .leading, spacing: 10) {
                ProfileInfoRow(title: "Ad Soyad", value: getAnimalIconsString() + " " + fullName)
                ProfileInfoRow(title: "Blok Numarası", value: blockNumber)
                ProfileInfoRow(title: "Kat Numarası", value: floorNumber)
                ProfileInfoRow(title: "Sahip Oldukları", value: chosenAnimals.joined(separator: ", "))
            }
            .padding()

            Spacer()
            
            // Çıkış Yap Butonu
            Button(action: {
                let firebaseAuth = Auth.auth()
                do {
                    try firebaseAuth.signOut()
                    withAnimation {
                        userID = ""
                    }
                } catch let signOutError as NSError {
                    print("Error signing out: %@", signOutError)
                }
            }) {
                Text("Çıkış Yap")
                    .frame(maxWidth: 200, maxHeight: 50)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            Spacer()
        }
        .onAppear {
            fetchUserData()
        }
    }

    private func fetchUserData() {
        guard !userID.isEmpty else {
            print("User ID is empty")
            return
        }

        // Firebase'den kullanıcı verilerini çekme
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
            } else if let document = document, document.exists {
                let data = document.data()
                fullName = data?["fullName"] as? String ?? ""
                blockNumber = data?["blockNumber"] as? String ?? ""
                floorNumber = data?["floorNumber"] as? String ?? ""
                chosenAnimals = data?["chosenAnimals"] as? [String] ?? []

                if let imageURLString = data?["profileImageURL"] as? String, let imageURL = URL(string: imageURLString) {
                    downloadProfileImage(from: imageURL)
                }
            } else {
                print("Document does not exist")
            }
        }
    }

    private func downloadProfileImage(from url: URL) {
        let dataTask = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Resmi indirirken hata: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("Resim verisi geçersiz")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.profileImage = image
                self.isLoading = false
            }
        }
        dataTask.resume()
    }

    private func uploadProfileImage(_ image: UIImage) {
        guard !userID.isEmpty else {
            print("Kullanıcı ID'si boş")
            return
        }

        // Resmi JPEG verisine dönüştür
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Resmi veriye dönüştürürken hata")
            return
        }

        // Firebase Storage referansını oluştur
        let storageRef = storage.reference().child("profile_images/\(userID).jpg")

        // Resmi yükle
        let uploadTask = storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Resmi yüklerken hata: \(error.localizedDescription)")
                return
            }

            // Yükleme tamamlandığında Firestore'u güncelle
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("İndirme URL'si alınırken hata: \(error.localizedDescription)")
                    return
                }

                guard let imageURL = url?.absoluteString else {
                    print("Resim URL'si alınırken hata")
                    return
                }

                // Firestore'da resmi güncelle
                db.collection("users").document(userID).updateData(["profileImageURL": imageURL]) { error in
                    if let error = error {
                        print("Firestore'u güncellerken hata: \(error.localizedDescription)")
                    } else {
                        print("Firestore başarıyla güncellendi")
                    }
                }
            }
        }

        // Yükleme ilerlemesini gözlemle (isteğe bağlı)
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            print("Yükleme ilerlemesi: \(percentComplete)%")
        }

        // Yükleme hatalarını işle (isteğe bağlı)
        uploadTask.observe(.failure) { snapshot in
            if let error = snapshot.error as NSError? {
                print("Yükleme başarısız oldu: \(error.localizedDescription)")
            }
        }
    }

    private func getIconName(for animal: String) -> String {
        switch animal.lowercased() {
        case "köpek":
            return "pawprint"
        case "kedi":
            return "hare"
        case "balık":
            return "fish"
        case "kuş":
            return "bird"
        default:
            return "questionmark"
        }
    }
    
    private func getAnimalIconsString() -> String {
        return chosenAnimals.map { animal in
            switch animal.lowercased() {
            case "köpek":
                return "🐶"
            case "kedi":
                return "😼"
            case "balık":
                return "🐟"
            case "kuş":
                return "🐦"
            default:
                return " "
            }
        }.joined(separator: " ")
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.bold)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
