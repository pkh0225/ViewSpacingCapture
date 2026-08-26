//
//  ImagePreviewViewController.swift
//  ViewSpacingCapture
//
//  Created by 박길호 on 7/18/25.
//

import UIKit
import Photos

class ImagePreviewViewController: UIViewController, UIScrollViewDelegate {
    var image: UIImage?
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var isDraggingDownToDismiss = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .lightGray

        // 스크롤뷰 설정
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 7.0
        view.addSubview(scrollView)

        // 이미지뷰 설정
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        scrollView.addSubview(imageView)

        // UI 버튼들 추가
        addCloseButton()
        addSaveButton()

        // 아래로 당겨서 닫기 제스처 추가
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        view.addGestureRecognizer(panGesture)

        // 더블탭 제스처 추가
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FloatingCaptureButton.shared.hideFloatingButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        FloatingCaptureButton.shared.showFloatingButton()
    }

    // MARK: - UI 요소 추가

    /// 오른쪽 상단에 '닫기' 버튼을 추가하는 함수
    private func addCloseButton() {
        let closeButton = UIButton(type: .system)

        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 22
        closeButton.layer.masksToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let xmarkImage = UIImage(systemName: "xmark", withConfiguration: config)
        closeButton.setImage(xmarkImage, for: .normal)
        closeButton.tintColor = .white

        closeButton.addTarget(self, action: #selector(dismissPreview), for: .touchUpInside)
        view.addSubview(closeButton)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    /// 왼쪽 상단에 '앨범에 저장' 버튼을 추가하는 함수
    private func addSaveButton() {
        let saveButton = UIButton(type: .system)

        saveButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        saveButton.layer.cornerRadius = 22
        saveButton.layer.masksToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let saveImage = UIImage(systemName: "square.and.arrow.down", withConfiguration: config)
        saveButton.setImage(saveImage, for: .normal)
        saveButton.tintColor = .white

        saveButton.addTarget(self, action: #selector(saveImageToAlbum), for: .touchUpInside)
        view.addSubview(saveButton)

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            saveButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            saveButton.widthAnchor.constraint(equalToConstant: 44),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - 이미지 저장 로직

    /// 저장 버튼을 눌렀을 때 호출되는 함수
    @objc private func saveImageToAlbum() {
        // 사용자에게 저장을 확인할 알림창을 먼저 띄웁니다.
        let alertController = UIAlertController(title: "사진 저장", message: "이 사진을 앨범에 저장하시겠습니까?", preferredStyle: .alert)

        // '저장' 버튼 액션
        let saveAction = UIAlertAction(title: "저장", style: .default) { [weak self] _ in
            // 사용자가 '저장'을 누르면 권한 확인 및 저장 절차를 진행합니다.
            self?.checkPermissionAndSave()
        }

        // '취소' 버튼 액션
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)

        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    /// 사진 앨범 접근 권한을 확인하고 이미지를 저장하는 함수
    private func checkPermissionAndSave() {
        guard let imageToSave = self.imageView.image else {
            showAlert(title: "오류", message: "저장할 이미지가 없습니다.")
            return
        }

        // MARK: - iOS 14 이상과 이전 버전을 분기 처리
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

            switch status {
            case .authorized, .limited:
                // .authorized: 모든 사진에 접근 가능
                // .limited: 사용자가 선택한 사진에만 접근 가능. 하지만 '추가'만 하는 경우에는 이 권한으로도 충분합니다.
                performSave(image: imageToSave)

            case .notDetermined:
                // 아직 권한을 요청하지 않은 상태. 'addOnly' 레벨로 권한을 요청합니다.
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                    guard let self else { return }

                    // 사용자가 '전체 허용' 또는 '일부 허용'을 선택하면 저장 실행
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(image: imageToSave)
                    }
                    else {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.showAlert(title: "권한 거부됨", message: "사진을 저장하려면 '설정'에서 사진 접근 권한을 허용해주세요.")
                        }
                    }
                }

            case .denied, .restricted:
                // 권한이 명시적으로 거부되었거나, 시스템에 의해 제한된 상태
                showAlert(title: "권한 필요", message: "사진을 저장하려면 '설정' 앱에서 사진 접근 권한을 허용해주세요.")

            @unknown default:
                showAlert(title: "오류", message: "알 수 없는 오류가 발생했습니다.")
            }
        }
        else {
            // iOS 13 로직
            let status = PHPhotoLibrary.authorizationStatus()

            switch status {
            case .authorized, .limited:
                performSave(image: imageToSave)

            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                    guard let self else { return }
                    if newStatus == .authorized {
                        self.performSave(image: imageToSave)
                    }
                    else {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                           self.showAlert(title: "권한 거부됨", message: "사진을 저장하려면 '설정'에서 사진 접근 권한을 허용해주세요.")
                        }
                    }
                }

            case .denied, .restricted:
                showAlert(title: "권한 필요", message: "사진을 저장하려면 '설정' 앱에서 사진 접근 권한을 허용해주세요.")

            @unknown default:
                showAlert(title: "오류", message: "알 수 없는 오류가 발생했습니다.")
            }
        }
    }

    /// 실제 이미지를 사진 앨범에 저장하는 함수
    private func performSave(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            // PHAssetChangeRequest를 통해 앨범에 이미지를 생성합니다.
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { [weak self] success, error in
            guard let self else { return }

            // UI 업데이트는 항상 메인 스레드에서 처리해야 합니다.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.showAlert(title: "저장 완료", message: "사진이 앨범에 성공적으로 저장되었습니다.")
                }
                else if let error {
                    self.showAlert(title: "저장 실패", message: "사진 저장 중 오류가 발생했습니다: \(error.localizedDescription)")
                }
                else {
                    self.showAlert(title: "저장 실패", message: "알 수 없는 오류로 사진 저장에 실패했습니다.")
                }
            }
        }
    }

    // MARK: - 제스처 핸들러 및 기타 함수

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
        else {
            let zoomRect = zoomRectForScale(scale: 4, center: gesture.location(in: imageView))
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.size.width  = imageView.frame.size.width / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            isDraggingDownToDismiss = scrollView.contentOffset.y <= 0

        case .changed:
            guard isDraggingDownToDismiss, translation.y >= 0 else {
                return
            }

            view.transform = CGAffineTransform(translationX: 0, y: translation.y)
            view.alpha = 1.0 - (translation.y / view.frame.height)

        case .ended, .cancelled:
            guard isDraggingDownToDismiss else {
                return
            }

            let velocity = gesture.velocity(in: view)
            if translation.y > view.bounds.height / 3 || velocity.y > 500 {
                dismiss(animated: true, completion: nil)
            }
            else {
                UIView.animate(withDuration: 0.3) {
                    self.view.transform = .identity
                    self.view.alpha = 1.0
                }
            }
            isDraggingDownToDismiss = false

        default:
            isDraggingDownToDismiss = false
            UIView.animate(withDuration: 0.3) {
                self.view.transform = .identity
                self.view.alpha = 1.0
            }
        }
    }

    /// 사용자에게 알림을 표시하는 헬퍼 함수
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }

    @objc private func dismissPreview() {
        dismiss(animated: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
