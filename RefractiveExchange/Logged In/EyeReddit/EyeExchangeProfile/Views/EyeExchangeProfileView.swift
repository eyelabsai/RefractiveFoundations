import UIKit

class EyeExchangeProfileView: UIView {

    var tableView: UITableView!
    var profileContainerView: UIView!
    var profileImageView: UIImageView!
    var usernameLabel: UILabel!
    var editButton: UIButton!
    var gradientLayer: CAGradientLayer!


    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradientBackground()
        setupProfileContainerView()
        setupTableView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradientBackground()
        setupProfileContainerView()
        setupTableView()
    }
    
    private func setupGradientBackground() {
        let veryLightGray = UIColor(white: 0.9, alpha: 1.0)
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.white.cgColor, veryLightGray.cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = bounds
        layer.insertSublayer(gradientLayer, at: 0) 
    }

    private func setupProfileContainerView() {
        profileContainerView = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.3))
        self.addSubview(profileContainerView)
        
        profileImageView = UIImageView()
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = 50
        profileImageView.clipsToBounds = true
        profileContainerView.addSubview(profileImageView)
        
        usernameLabel = UILabel()
        usernameLabel.font = UIFont.systemFont(ofSize: 24)
        usernameLabel.textColor = .white
        profileContainerView.addSubview(usernameLabel)
        
        editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)

        
        profileContainerView.addSubview(editButton)
        let profileSize: CGFloat = 100
        profileImageView.frame = CGRect(x: 18, y: 18, width: profileSize, height: profileSize)
        profileImageView.contentMode = .scaleAspectFill
        usernameLabel.frame = CGRect(x: profileSize + 32, y: 16, width: profileContainerView.bounds.width - profileSize - 48, height: 35)
        editButton.frame = CGRect(x: profileContainerView.bounds.width - 80, y: 16, width: 80, height: 30)
    }

    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
    
        tableView.frame = CGRect(
            x: 0,
            y: bounds.height * 0.2,
            width: bounds.width,
            height: bounds.height * 0.58
        )
        self.addSubview(tableView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        profileContainerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.2)
        gradientLayer.frame = profileContainerView.frame

        tableView.frame = CGRect(
            x: 0,
            y: bounds.height * 0.2,
            width: bounds.width,
            height: bounds.height * 0.58
        )
    }
}

