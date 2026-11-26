import SwiftUI

extension View {
    /// 顶栏、底栏、快捷条统一实色面板，对比度高于系统毛玻璃。
    func iosPanelChrome(edge: Edge = .top) -> some View {
        background(IOSPaper.panel)
            .overlay(alignment: edge == .top ? .top : .bottom) {
                Rectangle()
                    .fill(IOSPaper.panelBorder)
                    .frame(height: 1)
            }
    }
}