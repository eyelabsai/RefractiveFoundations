//
//  EyeExchangeProfileViewController.swift
//  IOL CON
//
//  Created by Haoran Song on 11/3/23.
//
import UIKit
import FirebaseAuth
import FirebaseFirestore
import Firebase
import FirebaseStorage
import SDWebImage
import SwiftUI

class EyeExchangeProfileViewController: UIViewController {
    var eyeExchangeProfileView: EyeExchangeProfileView!
    var posts:[FetchedPost] = []
    var user: User?
    let service = PostService()
    var data = GetData()
    var selectedPostIndex: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupProfileView()
        fetchUser()
        fetchPosts()
    }
    
    func fetchDefaultAvatarUrl(completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference()
        let avatarRef = storageRef.child("default_images/blank-avatar.png")

        avatarRef.downloadURL { url, error in
            if let error = error {
                print("Error getting download URL: \(error.localizedDescription)")
                completion(nil)
            } else if let url = url {
                completion(url.absoluteString)
            }
        }
    }


    func fetchUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        service.fetchEyeExchangeProfileDetails(uid: uid) { [weak self] result in
            guard let self = self else { return }

            if var user = result {
                if user.avatarUrl == nil || user.avatarUrl?.isEmpty == true {
                    self.fetchDefaultAvatarUrl { defaultAvatarUrl in
                        guard let defaultAvatarUrl = defaultAvatarUrl else {
                            print("Failed to get default avatar URL")
                            return
                        }

                        user.avatarUrl = defaultAvatarUrl

                        Firestore.firestore().collection("users").document(uid).updateData(["avatarUrl": defaultAvatarUrl]) { error in
                            if let error = error {
                                print("Error updating user: \(error.localizedDescription)")
                            } else {
                                print("User updated successfully")
                                self.user = user
                                self.updateProfileViewInfo()
                            }
                        }
                    }
                } else {
                    self.user = user
                    self.updateProfileViewInfo()
                }
            }
        }
    }


    
    func updateProfileViewInfo(refreshCache: Bool = false) {
        guard let user = user else {
            print("User data is not available")
            return
        }
        let fullName = [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ")
            
        if let exchangeUsername = user.exchangeUsername, !exchangeUsername.isEmpty {
            eyeExchangeProfileView.usernameLabel.attributedText = createAttributedText(primaryText: exchangeUsername, secondaryText: fullName)
        } else {
            eyeExchangeProfileView.usernameLabel.text = fullName
            eyeExchangeProfileView.usernameLabel.textColor = .black
            eyeExchangeProfileView.usernameLabel.font = UIFont.boldSystemFont(ofSize: 30)
        }

        if let avatarUrlString = user.avatarUrl, let url = URL(string: avatarUrlString) {
            let options: SDWebImageOptions = refreshCache ? [.refreshCached] : []
            self.eyeExchangeProfileView.profileImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "defaultAvatarImage"), options: options, completed: nil)
        } else {
            self.eyeExchangeProfileView.profileImageView.image = UIImage(named: "defaultAvatarImage")
        }
    }
    
    func createAttributedText(primaryText: String, secondaryText: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 30),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let secondaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let primaryString = NSMutableAttributedString(string: primaryText + "\n", attributes: primaryAttributes)
        let secondaryString = NSAttributedString(string: secondaryText, attributes: secondaryAttributes)
        
        primaryString.append(secondaryString)
        
        return primaryString
    }
    
    func loadProfileImage(from url: URL) {
        self.eyeExchangeProfileView.profileImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "defaultAvatarImage"), options: [], completed: { [weak self] (image, error, cacheType, imageURL) in
            if error != nil {
                print("Error loading image: \(error!.localizedDescription)")
                return
            }
        })
    }

    func setupProfileView() {
        eyeExchangeProfileView = EyeExchangeProfileView(frame: self.view.bounds)
        self.view.addSubview(eyeExchangeProfileView)
        eyeExchangeProfileView.tableView.delegate = self
        eyeExchangeProfileView.tableView.dataSource = self
        eyeExchangeProfileView.tableView.register(EyeExchangeProfileTableViewCell.self, forCellReuseIdentifier: "EyeExchangeProfileTableViewCell")
        eyeExchangeProfileView.tableView.rowHeight = UITableView.automaticDimension
        eyeExchangeProfileView.tableView.estimatedRowHeight = UITableView.automaticDimension
        eyeExchangeProfileView.editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        
    }
    
    @objc func editButtonTapped() {
        let profileEditVC = EyeExchangeProfileEditViewController()
        profileEditVC.user = user
        profileEditVC.onUsernameUpdated = { [weak self] updatedUsername in
            self?.user?.exchangeUsername = updatedUsername
            self!.updateProfileViewInfo()
        }
        profileEditVC.onUseravatarUpdated = { [weak self] updatedUrl in
            self!.fetchUser()
        }
        let navigationController = UINavigationController(rootViewController: profileEditVC)
        self.present(navigationController, animated: true, completion: nil)
    }


    
    func fetchPosts(){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        service.fetchPosts(uid: uid) { [weak self] result in
            guard let self = self else { return }
            self.posts = result
            DispatchQueue.main.async {
                self.eyeExchangeProfileView.tableView.reloadData()
            }
        }
    }
}

extension EyeExchangeProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EyeExchangeProfileTableViewCell", for: indexPath) as! EyeExchangeProfileTableViewCell
        
        let post = posts[indexPath.row]
        cell.subredditLabel.text = post.subreddit
        
        let timestampDate = post.timestamp.dateValue()
        cell.postTimeLabel.text = timeAgoSinceDate(timestampDate)
        cell.postTitleLabel.text = post.title
        cell.voteCountLabel.text = "\(post.upvotes.count)"
        
        cell.moreActionButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        cell.upvoteButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        cell.commentButton.setImage(UIImage(systemName: "message"), for: .normal)
        
        cell.moreActionButton.addTarget(self, action: #selector(moreButtonTapped(_:)), for: .touchUpInside)
        
        cell.moreActionButton.tag = indexPath.row
        cell.upvoteButton.tag = indexPath.row
        cell.commentButton.tag = indexPath.row
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let post = posts[indexPath.row]
//        let commentView = CommentView(post: post, data: data)
//        let hostingController = UIHostingController(rootView: commentView)
//        self.navigationController?.pushViewController(hostingController, animated: true)
        self.eyeExchangeProfileView.tableView.deselectRow(at: indexPath, animated: true)
    }

    
    // MARK: - Button Actions
    @objc func moreButtonTapped(_ sender: UIButton) {
        selectedPostIndex = sender.tag
        showMoreActionAlert()
    }
    
    func showMoreActionAlert() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self, let index = self.selectedPostIndex, index >= 0, index < self.posts.count else { return }
            let postToDelete = self.posts[index]
            Firestore.firestore().collection("posts").document(postToDelete.id!).delete { error in
                if let error = error {
                    print("Error removing document: \(error)")
                } else {
                    self.posts.remove(at: index)
                    self.selectedPostIndex = nil
                    DispatchQueue.main.async {
                        self.eyeExchangeProfileView.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            }
        }
        alertController.addAction(deleteAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    // MARK: - Utils
    func timeAgoSinceDate(_ date: Date, numericDates: Bool = true) -> String {
        let calendar = Calendar.current
        let now = Date()
        let unitFlags: Set<Calendar.Component> = [.minute, .hour, .day, .weekOfYear, .month, .year, .second]
        let components = calendar.dateComponents(unitFlags, from: date, to: now)

        if let year = components.year, year >= 2 {
            return "\(year) years ago"
        }

        if let year = components.year, year >= 1 {
            return numericDates ? "1 year ago" : "Last year"
        }

        if let month = components.month, month >= 2 {
            return "\(month) months ago"
        }

        if let month = components.month, month >= 1 {
            return numericDates ? "1 month ago" : "Last month"
        }

        if let week = components.weekOfYear, week >= 2 {
            return "\(week) weeks ago"
        }

        if let week = components.weekOfYear, week >= 1 {
            return numericDates ? "1 week ago" : "Last week"
        }

        if let day = components.day, day >= 2 {
            return "\(day) days ago"
        }

        if let day = components.day, day >= 1 {
            return numericDates ? "1 day ago" : "Yesterday"
        }

        if let hour = components.hour, hour >= 2 {
            return "\(hour) hours ago"
        }

        if let hour = components.hour, hour >= 1 {
            return numericDates ? "1 hour ago" : "An hour ago"
        }

        if let minute = components.minute, minute >= 2 {
            return "\(minute) minutes ago"
        }

        if let minute = components.minute, minute >= 1 {
            return numericDates ? "1 minute ago" : "A minute ago"
        }

        return "Just now"
    }

}

