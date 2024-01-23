//
//  PostCardImage.swift
//  Mammoth
//
//  Created by Benoit Nolens on 28/09/2023.
//  Copyright © 2023 The BLVD. All rights reserved.
//

import UIKit
import SDWebImage
import UnifiedBlurHash

final class PostCardImage: UIView {
    
    enum PostCardImageVariant {
        case fullSize
        case thumbnail
    }
    
    static var transformer: SDImageTransformer {
        return ScaleDownTransformer()
    }
    
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .custom.OVRLYSoftContrast
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    public var image: UIImage? {
        return self.imageView.image
    }
    
    private lazy var sensitiveContentOverlay: UIButton = {
        let button = UIButton(type: .custom)
        
        let iconView = BlurredBackground(dimmed: false)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.cornerRadius = 18
        iconView.clipsToBounds = true
        
        button.insertSubview(iconView, aboveSubview: button.imageView!)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        let icon = UIImageView(image: FontAwesome.image(fromChar: "\u{f070}", color: .custom.linkText, size: 16, weight: .bold).withRenderingMode(.alwaysTemplate))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .center
        iconView.addSubview(icon)
        icon.pinCenter()

        let bg = BlurredBackground(dimmed: true, underlayAlpha: 0.11)
        button.insertSubview(bg, belowSubview: button.imageView!)
        bg.pinEdges()
        
        return button
    }()
    
    private var hideSensitiveOverlayGesture: UITapGestureRecognizer?
    private var dismissedSensitiveOverlay: Bool = false
        
    private var dynamicHeightConstraint: NSLayoutConstraint?
    
    private lazy var squareConstraints: [NSLayoutConstraint] = {
        let c1 = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor)
        c1.priority = .required

        let c2 = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        c2.priority = .required
        return [c1, c2]
    }()
    
    private lazy var portraitConstraints: [NSLayoutConstraint] = {
        let c1 = imageView.widthAnchor.constraint(equalTo: self.widthAnchor)
        c1.priority = .defaultHigh

        let c2 = imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        c2.priority = .required
        
        return [c1, c2]
    }()
    
    private lazy var tallPortraitConstraints: [NSLayoutConstraint] = {
        // extremely tall (more than the iPhone 14 Pro Max ratio)
        let c1 = imageView.widthAnchor.constraint(equalTo: self.widthAnchor)
        c1.priority = .defaultHigh

        let c2 = imageView.heightAnchor.constraint(equalToConstant: 420)
        c2.priority = .defaultHigh
        
        return [c1, c2]
    }()
    
    private lazy var landscapeConstraints: [NSLayoutConstraint] = {
        // most portrait images
        let c1 = imageView.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor)
        c1.priority = .required

        let c2 = imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 420)
        c2.priority = .required
        
        return [c1, c2]
    }()
    
    private var altButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("ALT", for: .normal)
        button.setTitleColor(.custom.active, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 7
        button.clipsToBounds = true
        button.isHidden = true
        button.accessibilityElementsHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentEdgeInsets = .init(top: 3, left: 5, bottom: 2, right: 5)
        
        let bg = BlurredBackground(dimmed: false)
        button.insertSubview(bg, belowSubview: button.titleLabel!)
        bg.pinEdges()
        
        return button
    }()
    
    private var postCard: PostCardModel?
    private var media: Attachment?
    private let variant: PostCardImageVariant
    
    init(variant: PostCardImageVariant = .fullSize) {
        self.variant = variant
        super.init(frame: .zero)
        self.setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepareForReuse() {
        self.postCard = nil
        self.media = nil
        self.dismissedSensitiveOverlay = false
        self.imageView.sd_cancelCurrentImageLoad()
    }
    
    private func setupUI() {
        self.isOpaque = true
        self.backgroundColor = .custom.background
        self.layoutMargins = .init(top: 3, left: 0, bottom: 0, right: 0)

        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.layer.cornerCurve = .continuous
        self.addSubview(imageView)
        self.addSubview(altButton)
        self.imageView.addSubview(sensitiveContentOverlay)
        
        switch self.variant {
        case .fullSize:
            self.altButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            self.altButton.contentEdgeInsets = .init(top: 3, left: 5, bottom: 2, right: 5)
        case .thumbnail:
            self.altButton.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            self.altButton.contentEdgeInsets = .init(top: 3, left: 5, bottom: 2, right: 5)
        }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            altButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: self.variant == .fullSize ? -10 : -2),
            altButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: self.variant == .fullSize ? -10 : -2),
        ])
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(self.onPress))
        self.addGestureRecognizer(gesture)
                
        let altPress = UITapGestureRecognizer(target: self, action: #selector(self.altPress))
        self.altButton.addGestureRecognizer(altPress)
        
        self.sensitiveContentOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sensitiveContentOverlay.alpha = 1
        
    }
    
    public func configure(image: Attachment?, postCard: PostCardModel) {
        let shouldUpdate = self.media == nil || image != self.media!
        self.postCard = postCard
        
        if let media = image {
            self.media = media
            if let previewURL = media.previewURL, let imageURL = URL(string: previewURL) {
                var placeholder: UIImage?
                if let blurhash = media.blurhash {
                    placeholder = UnifiedImage(blurHash: blurhash, size: .init(width: 32, height: 32))
                }
                let decodedImage = (media.previewURL != nil) ? postCard.decodedImages[media.previewURL!] as? UIImage : nil
                self.imageView.ma_setImage(with: imageURL,
                                           cachedImage: decodedImage,
                                           placeholder: placeholder,
                                                  imageTransformer: PostCardImage.transformer) { [weak self] image in
                    if self?.media == media, let image = image {
                        if let key = media.previewURL {
                            postCard.decodedImages[key] = image
                        }
                    }
                }
            }
            
            if GlobalStruct.blurSensitiveContent && postCard.isSensitive && !self.dismissedSensitiveOverlay {
                self.sensitiveContentOverlay.frame = self.imageView.bounds
                
                if self.hideSensitiveOverlayGesture == nil {
                    self.hideSensitiveOverlayGesture = UITapGestureRecognizer(target: self, action: #selector(self.hideSensitiveOverlay))
                    self.sensitiveContentOverlay.addGestureRecognizer(self.hideSensitiveOverlayGesture!)
                }
                
                self.sensitiveContentOverlay.isHidden = false
            } else {
                self.sensitiveContentOverlay.isHidden = true
            }
            
            if let description = media.description, !description.isEmpty {
                self.altButton.isHidden = false
                self.bringSubviewToFront(self.altButton)
            } else {
                self.altButton.isHidden = true
            }
        }
        
        if shouldUpdate {
            // the aspect value might be nil
            if self.media?.meta?.original?.aspect == nil {
                self.media?.meta?.original?.aspect = Double(self.media?.meta?.original?.width ?? 10) / Double(self.media?.meta?.original?.height ?? 10)
            }
    
            if let ratio = self.media?.meta?.original?.aspect {
                // square
                if self.variant == .thumbnail || fabs(ratio - 1.0) < 0.01 {
                    self.deactivateAllImageConstraints()
                    NSLayoutConstraint.activate(self.squareConstraints)
                }

                // landscape
                else if ratio > 1 {
                    self.deactivateAllImageConstraints()
                    
                    self.dynamicHeightConstraint = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1.0 / ratio)
                    dynamicHeightConstraint!.priority = .required
                    
                    NSLayoutConstraint.activate(self.landscapeConstraints + [self.dynamicHeightConstraint!])
                }

                // portrait
                else if ratio < 1 {
                    if ratio < 0.44 {
                        self.deactivateAllImageConstraints()
                        NSLayoutConstraint.activate(self.tallPortraitConstraints)
                    } else {
                        self.deactivateAllImageConstraints()
                        
                        self.dynamicHeightConstraint = imageView.heightAnchor.constraint(equalTo: self.widthAnchor, multiplier: 1.0 / ratio)
                        dynamicHeightConstraint!.priority = .defaultHigh
                        
                        NSLayoutConstraint.activate(self.portraitConstraints + [self.dynamicHeightConstraint!])
                    }
                }
            }
        }
    }
    
    public func configure(postCard: PostCardModel) {
        if let firstImage = postCard.mediaAttachments.first {
            self.configure(image: firstImage, postCard: postCard)
        }
    }
    
    private func deactivateAllImageConstraints() {
        NSLayoutConstraint.deactivate(self.squareConstraints
                                      + self.portraitConstraints
                                      + self.tallPortraitConstraints
                                      + self.landscapeConstraints
                                      + [self.dynamicHeightConstraint].compactMap({$0})
        )
    }
    
    @objc func onPress() {
        if let originImage = imageView.image {

            // Open fullscreen image preview
            let images = self.postCard?.mediaAttachments.compactMap { attachment in
                guard attachment.type == .image else { return SKPhoto() }
                let photo = SKPhoto.photoWithImageURL(attachment.url)
                photo.shouldCachePhotoURLImage = false
                
                var blurImage: UIImage? = nil
                if let blurhash = attachment.blurhash, let currentMedia = self.media, attachment.url != currentMedia.url {
                    blurImage = UnifiedImage(blurHash: blurhash, size: .init(width: 32, height: 32))
                }
                photo.underlyingImage = SDImageCache.shared.imageFromCache(forKey: attachment.url) ?? blurImage
                return photo
            } ?? [SKPhoto()]
            
            let descriptions = self.postCard?.mediaAttachments.map { $0.description ?? "" } ?? []
            let currentIndex = self.postCard?.mediaAttachments.firstIndex(where: {$0.id == self.media?.id}) ?? 0
            
            let browser = SKPhotoBrowser(originImage: originImage,
                                         photos: images,
                                         animatedFromView: self.imageView,
                                         descriptions: descriptions,
                                         currentIndex: currentIndex)
            SKPhotoBrowserOptions.enableSingleTapDismiss = false
            SKPhotoBrowserOptions.displayCounterLabel = false
            SKPhotoBrowserOptions.displayBackAndForwardButton = false
            SKPhotoBrowserOptions.displayAction = false
            SKPhotoBrowserOptions.displayHorizontalScrollIndicator = false
            SKPhotoBrowserOptions.displayVerticalScrollIndicator = false
            SKPhotoBrowserOptions.displayCloseButton = false
            SKPhotoBrowserOptions.displayStatusbar = false
            browser.initializePageIndex(currentIndex)
            getTopMostViewController()?.present(browser, animated: true, completion: {})
            
            // Preload other images
            PostCardModel.imageDecodeQueue.async { [weak self] in
                guard let self else { return }
                let prefetcher = SDWebImagePrefetcher.shared
                let urls = self.postCard?.mediaAttachments.compactMap { URL(string: $0.url) }
                prefetcher.prefetchURLs(urls, progress: nil) { _, _ in
                    let images = self.postCard?.mediaAttachments.compactMap { attachment in
                        guard attachment.type == .image else { return nil }
                        let photo = SKPhoto.photoWithImageURL(attachment.url)
                        photo.shouldCachePhotoURLImage = false
                        photo.underlyingImage = SDImageCache.shared.imageFromCache(forKey: attachment.url)
                        return photo
                    } ?? [SKPhoto()]
                    
                    DispatchQueue.main.async {
                        browser.photos = images
                        browser.reloadData()
                    }
                }
            }
        }
    }
    
    @objc func altPress() {
        if let altTextPopup = self.media?.description {
            triggerHapticImpact(style: .light)
            let alert = UIAlertController(title: nil, message: altTextPopup, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy", style: .default , handler:{ (UIAlertAction) in
                let pasteboard = UIPasteboard.general
                pasteboard.string = altTextPopup
            }))
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel , handler:{ (UIAlertAction) in

            }))
            if let presenter = alert.popoverPresentationController {
                presenter.sourceView = self
                presenter.sourceRect = self.bounds
            }
            getTopMostViewController()?.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func hideSensitiveOverlay() {
        self.dismissedSensitiveOverlay = true
        triggerHapticImpact(style: .light)
        UIView.animate(withDuration: 0.18) {
            self.sensitiveContentOverlay.alpha = 0
        } completion: { _ in
            self.sensitiveContentOverlay.removeFromSuperview()
        }
    }
}
