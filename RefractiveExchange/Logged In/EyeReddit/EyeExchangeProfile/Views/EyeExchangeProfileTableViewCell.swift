//
//  EyeExchangeProfileTableViewCell.swift
//  IOL CON
//
//  Created by Haoran Song on 11/8/23.
//

import UIKit

class EyeExchangeProfileTableViewCell: UITableViewCell {
    
    let subredditLabel = UILabel()
    let postTimeLabel = UILabel()
    let moreActionButton = UIButton()
    let postTitleLabel = UILabel()
    let upvoteButton = UIButton()
    let commentButton = UIButton()
    let voteCountLabel = UILabel()
     
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addSubviews()
        configureUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubviews()
        configureUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let padding: CGFloat = 10
        let labelHeight: CGFloat = 20
        let buttonSize: CGFloat = 30
        let imageSize: CGFloat = 20
        

        let usableWidthForLabels = contentView.bounds.width - padding * 3 - buttonSize
        
        let subredditLabelWidth = usableWidthForLabels * 2 / 3
        let postTimeLabelWidth = usableWidthForLabels / 3
        
        // Layout subreddit label
        subredditLabel.frame = CGRect(
            x: padding,
            y: padding,
            width: subredditLabelWidth,
            height: labelHeight
        )
            
        // Layout post time label
        postTimeLabel.frame = CGRect(
            x: subredditLabel.frame.maxX + padding,
            y: padding,
            width: postTimeLabelWidth,
            height: labelHeight
        )
        
        // Layout more action button
        moreActionButton.frame = CGRect(
            x: contentView.bounds.width - padding - buttonSize,
            y: padding,
            width: buttonSize,
            height: buttonSize
        )
        
        // Layout post title label
        postTitleLabel.frame = CGRect(
            x: padding,
            y: postTimeLabel.frame.maxY + padding / 2,  
            width: contentView.bounds.width - 2 * padding,
            height: 20
        )
        
        // Layout upvote button
        upvoteButton.frame = CGRect(
            x: padding,
            y: postTitleLabel.frame.maxY + padding,
            width: imageSize,
            height: imageSize
        )
        
        // Layout vote count label
        voteCountLabel.frame = CGRect(
            x: upvoteButton.frame.maxX + 5,
            y: upvoteButton.frame.minY,
            width: imageSize,
            height: imageSize
        )
        
        
        // Layout comment button
        commentButton.frame = CGRect(
            x: voteCountLabel.frame.maxX + 5,
            y: voteCountLabel.frame.minY,
            width: imageSize,
            height: imageSize
        )
    }
    
    private func addSubviews() {
        contentView.addSubview(subredditLabel)
        contentView.addSubview(postTimeLabel)
        contentView.addSubview(moreActionButton)
        contentView.addSubview(postTitleLabel)
        contentView.addSubview(upvoteButton)
        contentView.addSubview(commentButton)
        contentView.addSubview(voteCountLabel)
    }
    
    private func configureUI() {
        // Subreddit label setup
        subredditLabel.font = UIFont.systemFont(ofSize: 14)
        subredditLabel.textColor = .darkGray
        
        // Post time label setup
        postTimeLabel.font = UIFont.systemFont(ofSize: 14)
        postTimeLabel.textColor = .lightGray
        
        // More action button setup
        moreActionButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        
        // Post title label setup
        postTitleLabel.font = UIFont.systemFont(ofSize: 16)
        postTitleLabel.numberOfLines = 0
        
        // Upvote button setup
        upvoteButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        
        // Comment button setup
        commentButton.setImage(UIImage(systemName: "message"), for: .normal)
        
        // Vote count label setup
        voteCountLabel.font = UIFont.systemFont(ofSize: 14)
        voteCountLabel.textColor = .black
    }
}
