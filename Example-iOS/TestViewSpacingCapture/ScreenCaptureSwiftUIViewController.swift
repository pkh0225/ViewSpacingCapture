//
//  ScreenCaptureSwiftUIViewController.swift
//  TestViewSpacingCapture
//
//  Created by 박길호 on 8/4/26.
//

import SwiftUI
import UIKit

/// UIKit `ScreenCaptureViewController`와 유사한 테스트용 SwiftUI 화면 호스팅 컨트롤러
@available(iOS 16.0, *)
class ScreenCaptureSwiftUIViewController: UIHostingController<ScreenCaptureSwiftUIView> {
    init() {
        super.init(rootView: ScreenCaptureSwiftUIView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: ScreenCaptureSwiftUIView())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

/// 측정 대상 등록 없이, 평범하게 작성한 SwiftUI 화면입니다.
@available(iOS 16.0, *)
struct ScreenCaptureSwiftUIView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // 갈색 루트 컨테이너 (스토리보드 I1u-0l-H7s)
            Color(.systemBrown)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        topSection
                        bottomSection
                    }
                    .padding(.top, 11)
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 10)
                .padding(.top, 5)
        }
    }

    /// 상단 회색 영역 — 초록/노랑 박스들
    private var topSection: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGray2)

            Color.yellow
                .frame(width: 55, height: 53)
                .offset(x: 8, y: 8)

            ForEach(topGreenBoxes, id: \.id) { box in
                Color.green
                    .frame(width: box.size.width, height: box.size.height)
                    .offset(x: box.origin.x, y: box.origin.y)
            }

            Color(white: 0.333)
                .frame(width: 37, height: 37)
                .offset(x: 25, y: 81)

            // 중첩 초록 박스 + 인디고/버튼/이미지
            Color.green
                .frame(width: 143, height: 124)
                .overlay(alignment: .topLeading) {
                    Color.indigo
                        .frame(width: 96, height: 80)
                        .overlay(alignment: .topLeading) {
                            Button("Bu") {}
                                .offset(x: 11, y: 14)
                            Color.yellow
                                .frame(width: 71, height: 30)
                                .offset(x: 13, y: 42)
                        }
                        .offset(x: 23, y: 22)
                }
                .offset(x: 55, y: 140)

            // 작은 초록 + 오렌지
            Color.green
                .frame(width: 77, height: 76)
                .overlay(alignment: .topLeading) {
                    Color.orange
                        .frame(width: 37, height: 37)
                        .offset(x: 9, y: 11)
                }
                .offset(x: 228, y: 164)
        }
        .frame(height: 272)
        .frame(maxWidth: .infinity)
    }

    /// 하단 노랑 영역 — 라벨/컬렉션 셀 유사 레이아웃
    private var bottomSection: some View {
        ZStack(alignment: .topLeading) {
            Color.yellow

            Color(.systemGray6)
                .frame(width: 315, height: 237)
                .overlay(alignment: .topLeading) {
                    bottomContentOverlay
                }
                .offset(x: 15, y: 8)

            // CollectionView 셀에 해당하는 영역
            Color(.systemGray2)
                .frame(width: 335, height: 112)
                .overlay(alignment: .topLeading) {
                    screenCaptureCell
                        .offset(x: 10, y: 5)
                }
                .offset(x: 5, y: 255)
        }
        .frame(height: 372)
        .frame(maxWidth: .infinity)
    }

    private var bottomContentOverlay: some View {
        ZStack(alignment: .topLeading) {
            Text("     ")
                .offset(x: 223, y: 23)
            Text("Label")
                .offset(x: 24, y: 52)
            Text("Label")
                .offset(x: 76, y: 51)
            Text("Label")
                .offset(x: 253, y: 22)
            Text("Label")
                .offset(x: 261, y: 59)

            Color(.systemBackground)
                .frame(width: 75, height: 71)
                .offset(x: 8, y: 22)

            Color.mint
                .frame(width: 96, height: 80)
                .overlay(alignment: .topLeading) {
                    Text("Label")
                        .offset(x: 35, y: 8)
                    Text("Label")
                        .offset(x: 12, y: 37)
                }
                .offset(x: 104, y: 22)

            Color.teal
                .frame(width: 153, height: 91)
                .offset(x: 47, y: 126)

            Button("B") {}
                .frame(width: 66, height: 47)
                .background(Color.indigo.opacity(0.5))
                .offset(x: 241, y: 54)
        }
    }

    /// UIKit `ScreenCaptureCell`과 유사한 셀
    private var screenCaptureCell: some View {
        Color.green
            .frame(width: 314, height: 102)
            .overlay(alignment: .topLeading) {
                Color.yellow
                    .frame(width: 77, height: 44)
                    .offset(x: 8, y: 8)
                Color.yellow
                    .frame(width: 77, height: 34)
                    .offset(x: 8, y: 60)

                Color.teal
                    .frame(width: 96, height: 80)
                    .overlay(alignment: .topLeading) {
                        Text("Label")
                            .offset(x: 27, y: 8)
                        Text("Label")
                            .offset(x: 27, y: 45)
                    }
                    .offset(x: 102, y: 8)

                Button("B") {}
                    .offset(x: 206, y: 26)
                Button("B") {}
                    .offset(x: 258, y: 18)
            }
    }

    private var topGreenBoxes: [(id: Int, origin: CGPoint, size: CGSize)] {
        [
            (0, CGPoint(x: 75, y: 16), CGSize(width: 37, height: 37)),
            (1, CGPoint(x: 140, y: 16), CGSize(width: 37, height: 37)),
            (2, CGPoint(x: 209, y: 16), CGSize(width: 37, height: 37)),
            (3, CGPoint(x: 268, y: 16), CGSize(width: 37, height: 37)),
            (4, CGPoint(x: 80, y: 75), CGSize(width: 37, height: 37)),
            (5, CGPoint(x: 209, y: 81), CGSize(width: 37, height: 37)),
            (6, CGPoint(x: 127, y: 81), CGSize(width: 37, height: 37)),
            (7, CGPoint(x: 279, y: 92), CGSize(width: 37, height: 37)),
        ]
    }
}

@available(iOS 16.0, *)
#Preview {
    ScreenCaptureSwiftUIView()
}
