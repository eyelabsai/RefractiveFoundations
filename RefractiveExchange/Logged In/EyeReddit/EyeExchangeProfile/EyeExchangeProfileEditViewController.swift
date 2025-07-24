//
//  EyeExchangeProfileEditViewController.swift
//  IOL CON
//
//  Created by Haoran Song on 12/18/23.
//

import UIKit
import Photos
import FirebaseStorage
import FirebaseFirestore


class EyeExchangeProfileEditViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()
    var user: User?
    var onUsernameUpdated: ((String) -> Void)?
    var onUseravatarUpdated: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Update Profile"

        let backButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(backButtonTapped))
        navigationItem.leftBarButtonItem = backButton

        view.addSubview(tableView)
        tableView.frame = view.bounds

        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(UsernameTableViewCell.self, forCellReuseIdentifier: "UsernameCell")
        tableView.register(AvatarTableViewCell.self, forCellReuseIdentifier: "AvatarCell")
    }
    
    @objc func backButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UsernameCell", for: indexPath) as! UsernameTableViewCell
            cell.configure(with: user!.exchangeUsername?.isEmpty == false ? user!.exchangeUsername! : "Click to create one")

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AvatarCell", for: indexPath) as! AvatarTableViewCell
            if let avatarUrlString = user?.avatarUrl, let url = URL(string: avatarUrlString) {
                cell.configure(with: url)
            } else {
                cell.configure(with: nil)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            editUsername()
        } else {
            changeAvatar()
        }
    }

    func editUsername() {
        let alertController = UIAlertController(title: "Edit Username", message: "Enter your new username", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "New username"
        }

        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { [weak alertController] _ in
            guard let textField = alertController?.textFields?.first,
                  let newUsername = textField.text,
                  !newUsername.isEmpty,
                  self.isValidUsername(newUsername) else {
                self.showAlert(title: "Invalid Username", message: "Please enter a valid username.")
                return
            }

            self.updateUsernameInFirestore(newUsername)
        }
        alertController.addAction(confirmAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }


    func changeAvatar() {
        self.showImagePicker()
    }


    func showImagePicker() {
        DispatchQueue.main.async {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            self.present(picker, animated: true, completion: nil)
        }
    }
    
    func isValidUsername(_ username: String) -> Bool {
        let characterset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return username.rangeOfCharacter(from: characterset.inverted) == nil
    }

    func updateUsernameInFirestore(_ username: String) {
        let uid = (user?.uid)!
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData(["exchangeUsername": username], merge: true) { error in
            if let error = error {
                print("Error updating username: \(error)")
            } else {
                print("Username successfully updated.")
                self.user?.exchangeUsername = username
                self.tableView.reloadData()
                self.onUsernameUpdated?(username)
            }
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    func uploadImageToFirebaseStorage(_ image: UIImage) {
        guard let uid = user?.uid else { return }
        if let resizedImage = resizeImage(image: image, targetSize: CGSize(width: 800, height: 800)),
           let imageData = resizedImage.jpegData(compressionQuality: 0.3) {
                let storageRef = Storage.storage().reference()
                let avatarRef = storageRef.child("avatar_images/\(uid).jpg")

                avatarRef.putData(imageData, metadata: nil) { metadata, error in
                    guard metadata != nil else {
                        print("Error uploading image: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    avatarRef.downloadURL { url, error in
                        guard let downloadURL = url else {
                            print("Error getting download URL: \(error?.localizedDescription ?? "Unknown error")")
                            return
                        }

                        self.updateAvatarUrlInFirestore(downloadURL.absoluteString)
                    }
                }
        }


        
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    
    func updateAvatarUrlInFirestore(_ url: String) {
        let db = Firestore.firestore()
        guard let uid = user?.uid else { return }

        db.collection("users").document(uid).updateData(["avatarUrl": url]) { error in
            if let error = error {
                print("Error updating avatar URL: \(error.localizedDescription)")
            } else {
                print("Avatar URL successfully updated.")
                self.user?.avatarUrl = url
                self.tableView.reloadData()
                self.onUseravatarUpdated?(url)
            }
        }
    }


}

extension EyeExchangeProfileEditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)

        guard let image = info[.originalImage] as? UIImage else { return }
        uploadImageToFirebaseStorage(image)
    }
}

class UsernameTableViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let usernameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .black
        titleLabel.text = "Username"

        usernameLabel.font = UIFont.systemFont(ofSize: 16)
        usernameLabel.textColor = .darkGray

 
        contentView.addSubview(titleLabel)
        contentView.addSubview(usernameLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            usernameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    func configure(with username: String?) {
        usernameLabel.text = username
    }
}



class AvatarTableViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let avatarImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(avatarImageView)

        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.text = "Avatar"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        avatarImageView.layer.cornerRadius = 22
        avatarImageView.clipsToBounds = true
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func configure(with imageUrl: URL?) {
        if let url = imageUrl {
            avatarImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "defaultAvatar"))
        } else {
            avatarImageView.image = UIImage(named: "defaultAvatar")
        }
    }
}
